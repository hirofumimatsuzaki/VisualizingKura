# WordPress Integration

This project can be enriched with artist profile images by scraping the Studio Kura residency list and each artist's detail page inside WordPress.

## Included file

- `wordpress/artist-photo-feed.php`
- `wordpress/studiokura-artist-feed-plugin.php`

## What it does

- fetches `https://online.studiokura.com/cake/residences/artistlist/en`
- extracts artist detail links
- visits each artist detail page
- tries to find the first plausible profile image
- exposes the result as JSON

## Install

Use one of these methods:

1. Add the contents of `wordpress/artist-photo-feed.php` to a small custom plugin
2. Load it from your theme's `functions.php`
3. Paste it into a WordPress snippets plugin

If `Code Snippets` is blocked or returns `403`, use the plugin file directly:

1. Create this folder on the server:

```text
wp-content/plugins/studiokura-artist-feed/
```

2. Upload:

```text
studiokura-artist-feed.php
```

Use the contents of:

```text
wordpress/studiokura-artist-feed-plugin.php
```

3. In WordPress Admin, open `Plugins`
4. Activate `Studio Kura Artist Feed`

## JSON endpoint

After installation:

```text
/wp-json/studiokura/v1/artists
```

Example:

```text
https://studiokura.com/wp-json/studiokura/v1/artists
```

Force refresh:

```text
https://studiokura.com/wp-json/studiokura/v1/artists?refresh=1
```

## Shortcode

For debugging:

```text
[guest_artists_json]
```

## Expected payload

```json
{
  "success": true,
  "generatedAt": "2026-04-04T00:00:00Z",
  "count": 123,
  "artists": [
    {
      "artist": "Artist Name",
      "detailUrl": "https://...",
      "country": "Canada",
      "imageUrl": "https://...",
      "imageSource": "detail_page"
    }
  ]
}
```

## Notes

- The scraper caches results for 12 hours using WordPress transients.
- The country field is best-effort because it is inferred from nearby text on the list page.
- Depending on the detail page layout, you may want to tighten the XPath selectors in `studio_kura_extract_profile_image()`.
- Once this endpoint is live, the visualization can be extended to show thumbnails in the country detail panel.
