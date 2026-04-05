# VisualizingKura

Studio Kura residency artists visualized on a world map, animated from each artist's origin country toward Itoshima.

## Files

- `index.html`
  Main standalone page.
- `embed.html`
  WordPress-friendly embed page for iframe use.
- `sketch.js`
  Canvas-based visualization and animation logic.
- `style.css`
  Shared styling.
- `data/artists-data.js`
  Generated artist dataset.
- `data/artist-profiles.js`
  Generated static profile links for artist detail cards.
- `data/artist-images.js`
  Optional image lookup table, loaded only on larger screens.
- `data/manual-artists.csv`
  Manual artist additions merged on top of the source CSV.
- `data/country-overrides.csv`
  Country fixes keyed by `label,artist`.
- `data/world-land.js`
  Local world land topology for accurate coastlines.
- `data/world-countries.js`
  Local country topology for borders.
- `scripts/build-data.ps1`
  Rebuilds artist data from the source CSV in `Downloads`.
- `scripts/build-artist-profiles.ps1`
  Rebuilds static artist profile metadata from Studio Kura's public artist list.
- `scripts/build-map-data.ps1`
  Rebuilds JS wrappers from the local map JSON files.

## Local Use

Open `index.html` directly in a browser.

For WordPress embed preview, open `embed.html`.

## Update Artist Data

The project expects the latest residency CSV to exist in `C:\Users\Mining-Base\Downloads`.
Optional hand-maintained inputs live in the repo:

- `data/manual-artists.csv`
  Add brand new artists in `label,artist,country` format.
- `data/country-overrides.csv`
  Fix country values for existing rows in `label,artist,country` format.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-data.ps1
```

This regenerates:

```text
data/artists-data.js
```

Example manual addition:

```csv
label,artist,country
2026/04,New Artist,Canada
```

Example country override:

```csv
label,artist,country
2025/12,Katarina Čelebić,Serbia
```

Rules:

- `label` must use `YYYY/MM`
- duplicate `label + artist` rows in `manual-artists.csv` are skipped
- `Scotland` is normalized to `United Kingdom`

## Update Artist Profiles

To rebuild static profile links for GitHub Pages:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-artist-profiles.ps1
```

To also fetch recent artist images from detail pages:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-artist-profiles.ps1 -FetchImages -MinImageYear 2024 -ImageLimit 180
```

This regenerates:

```text
data/artist-profiles.js
data/artist-images.js
```

## Update Map Data

If `land-110m.json` or `countries-110m.json` change, rebuild the browser-friendly wrappers:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-map-data.ps1
```

This regenerates:

```text
data/world-land.js
data/world-countries.js
```

## WordPress Embed

After publishing this repo with GitHub Pages or hosting the files on Studio Kura's server, embed:

```html
<iframe
  src="https://hirofumimatsuzaki.github.io/VisualizingKura/embed.html"
  width="100%"
  height="820"
  style="border:0;display:block;"
  loading="lazy"
></iframe>
```

If hosting on Studio Kura directly, replace the `src` URL with the production path.

## WordPress Artist Photos

To enrich the visualization with artist profile images sourced from Studio Kura's residency pages, use:

- [artist-photo-feed.php](/C:/Users/Mining-Base/Documents/VisualizingKura/wordpress/artist-photo-feed.php)
- [README-wordpress.md](/C:/Users/Mining-Base/Documents/VisualizingKura/wordpress/README-wordpress.md)

This adds a WordPress REST endpoint that scrapes the artist list and detail pages, then returns structured JSON with image URLs.

## Notes

- The map uses local topology data, so it works without external map API requests.
- The artist list is animated in chronological order starting in 2007.
- Some CSV rows have missing country values; those entries remain in the dataset as `Unknown`.
