<?php
/**
 * Studio Kura artist feed with profile images.
 *
 * Usage:
 * 1. Drop this into a small mu-plugin / theme functions include / Code Snippets.
 * 2. Visit: /wp-json/studiokura/v1/artists
 * 3. Optional shortcode: [guest_artists_json]
 *
 * This scraper:
 * - fetches the residency artist list
 * - extracts artist entries from each list item
 * - opens each detail page
 * - finds the first plausible profile image
 * - returns structured JSON
 */

if (!defined('ABSPATH')) {
    exit;
}

const STUDIO_KURA_ARTIST_LIST_URL = 'https://online.studiokura.com/cake/residences/artistlist/en';
const STUDIO_KURA_ARTIST_CACHE_KEY = 'studio_kura_artist_feed_v1';
const STUDIO_KURA_ARTIST_CACHE_TTL = 12 * HOUR_IN_SECONDS;

add_action('rest_api_init', function () {
    register_rest_route('studiokura/v1', '/artists', array(
        'methods' => 'GET',
        'callback' => 'studio_kura_rest_artist_feed',
        'permission_callback' => '__return_true',
    ));
});

add_shortcode('guest_artists_json', function () {
    $payload = studio_kura_get_artist_feed();
    if (is_wp_error($payload)) {
        return '<pre>' . esc_html($payload->get_error_message()) . '</pre>';
    }

    return '<pre>' . esc_html(wp_json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)) . '</pre>';
});

function studio_kura_rest_artist_feed(WP_REST_Request $request) {
    $refresh = (bool) $request->get_param('refresh');
    $payload = studio_kura_get_artist_feed($refresh);

    if (is_wp_error($payload)) {
        return new WP_REST_Response(array(
            'success' => false,
            'message' => $payload->get_error_message(),
        ), 500);
    }

    return new WP_REST_Response(array(
        'success' => true,
        'generatedAt' => gmdate('c'),
        'count' => count($payload),
        'artists' => $payload,
    ));
}

function studio_kura_get_artist_feed($refresh = false) {
    if (!$refresh) {
        $cached = get_transient(STUDIO_KURA_ARTIST_CACHE_KEY);
        if (is_array($cached)) {
            return $cached;
        }
    }

    $list_html = studio_kura_fetch_html(STUDIO_KURA_ARTIST_LIST_URL);
    if (is_wp_error($list_html)) {
        return $list_html;
    }

    $entries = studio_kura_extract_artist_links($list_html, STUDIO_KURA_ARTIST_LIST_URL);
    if (is_wp_error($entries)) {
        return $entries;
    }

    $artists = array();
    foreach ($entries as $entry) {
        if (!empty($entry['imageUrl'])) {
            $entry['imageSource'] = 'list_page';
            $artists[] = $entry;
            continue;
        }

        if (empty($entry['detailUrl'])) {
            $entry['imageUrl'] = '';
            $entry['imageSource'] = 'no_detail_url';
            $artists[] = $entry;
            continue;
        }

        $detail_html = studio_kura_fetch_html($entry['detailUrl']);
        if (is_wp_error($detail_html)) {
            $entry['imageUrl'] = '';
            $entry['imageSource'] = 'detail_fetch_failed';
            $artists[] = $entry;
            continue;
        }

        $image_url = studio_kura_extract_profile_image($detail_html, $entry['detailUrl']);
        $entry['imageUrl'] = $image_url ?: '';
        $entry['imageSource'] = $image_url ? 'detail_page' : 'not_found';
        $artists[] = $entry;
    }

    set_transient(STUDIO_KURA_ARTIST_CACHE_KEY, $artists, STUDIO_KURA_ARTIST_CACHE_TTL);
    return $artists;
}

function studio_kura_fetch_html($url) {
    $response = wp_remote_get($url, array(
        'timeout' => 20,
        'redirection' => 5,
        'user-agent' => 'StudioKuraArtistMap/1.0; ' . home_url('/'),
    ));

    if (is_wp_error($response)) {
        return $response;
    }

    $code = wp_remote_retrieve_response_code($response);
    if ($code < 200 || $code >= 300) {
        return new WP_Error('studio_kura_http_error', 'Failed to fetch ' . $url . ' (' . $code . ')');
    }

    return wp_remote_retrieve_body($response);
}

function studio_kura_extract_artist_links($html, $base_url) {
    $dom = studio_kura_create_dom($html);
    if (is_wp_error($dom)) {
        return $dom;
    }

    $xpath = new DOMXPath($dom);
    $nodes = $xpath->query('//li');
    if (!$nodes || !$nodes->length) {
        return new WP_Error('studio_kura_no_entries', 'No artist entries found on list page.');
    }

    $results = array();
    $seen = array();

    foreach ($nodes as $node) {
        $entry = studio_kura_parse_artist_list_item($node, $base_url);
        if (!$entry) {
            continue;
        }

        $key = md5(
            $entry['dateLabel'] . '|' .
            $entry['artist'] . '|' .
            $entry['country'] . '|' .
            $entry['detailUrl']
        );
        if (isset($seen[$key])) {
            continue;
        }
        $seen[$key] = true;
        $results[] = $entry;
    }

    if (!$results) {
        return new WP_Error('studio_kura_no_artist_entries', 'Artist detail links were not detected.');
    }

    return $results;
}

function studio_kura_extract_profile_image($html, $base_url) {
    $dom = studio_kura_create_dom($html);
    if (is_wp_error($dom)) {
        return '';
    }

    $xpath = new DOMXPath($dom);
    $queries = array(
        '//meta[@property="og:image"]/@content',
        '//article//img/@src',
        '//main//img/@src',
        '//img[contains(@class, "wp-image")]/@src',
        '//img/@src',
    );

    foreach ($queries as $query) {
        $nodes = $xpath->query($query);
        if (!$nodes || !$nodes->length) {
            continue;
        }

        foreach ($nodes as $node) {
            $src = trim($node->nodeValue);
            if ($src === '') {
                continue;
            }

            $absolute = studio_kura_absolute_url($src, $base_url);
            if (!$absolute) {
                continue;
            }

            if (studio_kura_looks_like_profile_image($absolute)) {
                return esc_url_raw($absolute);
            }
        }
    }

    return '';
}

function studio_kura_parse_artist_list_item(DOMNode $node, $base_url) {
    $text = trim(preg_replace('/\s+/', ' ', html_entity_decode($node->textContent, ENT_QUOTES | ENT_HTML5, 'UTF-8')));
    if ($text === '') {
        return null;
    }

    if (!preg_match('/^(\d{4}\/\d{2})\s*:\s*/', $text, $date_matches)) {
        return null;
    }

    $date_label = $date_matches[1];
    $country = '';
    if (preg_match('/\(([^()]+)\)\s*$/', $text, $country_matches)) {
        $country = trim(wp_strip_all_tags($country_matches[1]));
    }

    $artist = '';
    $detail_url = '';
    $image_url = '';

    $link = null;
    foreach ($node->childNodes as $child) {
        if ($child instanceof DOMElement && strtolower($child->nodeName) === 'a') {
            $link = $child;
            break;
        }
    }

    if ($link) {
        $artist = trim(preg_replace('/\s+/', ' ', html_entity_decode($link->textContent, ENT_QUOTES | ENT_HTML5, 'UTF-8')));
        $href = trim($link->getAttribute('href'));
        $absolute = studio_kura_absolute_url($href, $base_url);

        if ($absolute && studio_kura_looks_like_profile_image($absolute)) {
            $image_url = esc_url_raw($absolute);
        } elseif ($absolute && studio_kura_is_artist_detail_url($absolute)) {
            $detail_url = esc_url_raw($absolute);
        }
    } else {
        $artist = preg_replace('/^' . preg_quote($date_label, '/') . '\s*:\s*/', '', $text);
        if ($country !== '') {
            $artist = preg_replace('/\s*\(' . preg_quote($country, '/') . '\)\s*$/', '', $artist);
        }
        $artist = trim($artist);
    }

    $artist = trim(wp_strip_all_tags($artist));
    if ($artist === '' || preg_match('/^\d+$/', $artist)) {
        return null;
    }

    return array(
        'artist' => $artist,
        'detailUrl' => $detail_url,
        'country' => $country,
        'imageUrl' => $image_url,
        'dateLabel' => $date_label,
    );
}

function studio_kura_is_artist_detail_url($url) {
    $parts = wp_parse_url($url);
    if (empty($parts['host'])) {
        return false;
    }

    $host = strtolower($parts['host']);
    if (
        strpos($host, 'studiokura.info') === false &&
        strpos($host, 'artsitoya.com') === false
    ) {
        return false;
    }

    $path = $parts['path'] ?? '';
    if (
        strpos($path, '/cake/residences/artistlist') !== false ||
        strpos($path, '/cake/residences/') === 0 ||
        strpos($path, '/wp-content/uploads/') === 0
    ) {
        return false;
    }

    return true;
}

function studio_kura_looks_like_profile_image($url) {
    $path = strtolower((string) wp_parse_url($url, PHP_URL_PATH));

    if ($path === '') {
        return false;
    }

    $blocked = array('logo', 'icon', 'banner', 'header', 'avatar-default', 'placeholder');
    foreach ($blocked as $token) {
        if (strpos($path, $token) !== false) {
            return false;
        }
    }

    return preg_match('/\.(jpg|jpeg|png|webp|gif)$/', $path) === 1;
}

function studio_kura_absolute_url($url, $base_url) {
    if ($url === '') {
        return '';
    }

    if (preg_match('#^https?://#i', $url)) {
        return $url;
    }

    $base = wp_parse_url($base_url);
    if (!$base || empty($base['scheme']) || empty($base['host'])) {
        return '';
    }

    $origin = $base['scheme'] . '://' . $base['host'];

    if (strpos($url, '//') === 0) {
        return $base['scheme'] . ':' . $url;
    }

    if (strpos($url, '/') === 0) {
        return $origin . $url;
    }

    $path = isset($base['path']) ? preg_replace('#/[^/]*$#', '/', $base['path']) : '/';
    return $origin . $path . $url;
}

function studio_kura_create_dom($html) {
    if (!class_exists('DOMDocument')) {
        return new WP_Error('studio_kura_dom_missing', 'DOMDocument is not available on this server.');
    }

    libxml_use_internal_errors(true);
    $dom = new DOMDocument();
    $loaded = $dom->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();

    if (!$loaded) {
        return new WP_Error('studio_kura_invalid_html', 'Could not parse HTML.');
    }

    return $dom;
}
