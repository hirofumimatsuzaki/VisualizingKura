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
- `data/world-land.js`
  Local world land topology for accurate coastlines.
- `data/world-countries.js`
  Local country topology for borders.
- `scripts/build-data.ps1`
  Rebuilds artist data from the source CSV in `Downloads`.
- `scripts/build-map-data.ps1`
  Rebuilds JS wrappers from the local map JSON files.

## Local Use

Open `index.html` directly in a browser.

For WordPress embed preview, open `embed.html`.

## Update Artist Data

The project expects the latest residency CSV to exist in `C:\Users\Mining-Base\Downloads`.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-data.ps1
```

This regenerates:

```text
data/artists-data.js
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

## Notes

- The map uses local topology data, so it works without external map API requests.
- The artist list is animated in chronological order starting in 2007.
- Some CSV rows have missing country values; those entries remain in the dataset as `Unknown`.
