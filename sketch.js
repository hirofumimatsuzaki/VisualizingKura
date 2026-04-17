const ITOSHIMA = { name: "Itoshima, Japan", lat: 33.557, lon: 130.195 };
const MAP_BOUNDS = { minLon: -180, maxLon: 180, minLat: -60, maxLat: 85 };
const MAP_LABELS = [
  { text: "NORTH AMERICA", lon: -108, lat: 48 },
  { text: "SOUTH AMERICA", lon: -60, lat: -18 },
  { text: "EUROPE", lon: 14, lat: 55 },
  { text: "AFRICA", lon: 18, lat: 5 },
  { text: "ASIA", lon: 90, lat: 42 },
  { text: "OCEANIA", lon: 140, lat: -25 },
  { text: "JAPAN", lon: 138, lat: 37 }
];

const COUNTRY_COORDS = {
  Argentina: { lat: -34.61, lon: -58.38 }, Armenia: { lat: 40.18, lon: 44.51 }, Australia: { lat: -25.27, lon: 133.78 },
  Austria: { lat: 48.21, lon: 16.37 }, Bangladesh: { lat: 23.81, lon: 90.41 }, Belgium: { lat: 50.85, lon: 4.35 },
  Brazil: { lat: -15.79, lon: -47.88 }, Canada: { lat: 45.42, lon: -75.69 }, Chile: { lat: -33.45, lon: -70.67 },
  China: { lat: 39.9, lon: 116.4 }, Colombia: { lat: 4.71, lon: -74.07 }, Cyprus: { lat: 35.18, lon: 33.36 },
  "Czech Republic": { lat: 50.08, lon: 14.43 }, Denmark: { lat: 55.68, lon: 12.57 }, Estonia: { lat: 59.44, lon: 24.75 },
  Finland: { lat: 60.17, lon: 24.94 }, France: { lat: 48.86, lon: 2.35 }, Georgia: { lat: 41.72, lon: 44.79 },
  Germany: { lat: 52.52, lon: 13.4 }, Greece: { lat: 37.98, lon: 23.72 }, Guatemala: { lat: 14.63, lon: -90.55 },
  "Hong Kong": { lat: 22.32, lon: 114.17 }, Iceland: { lat: 64.15, lon: -21.94 }, India: { lat: 28.61, lon: 77.21 },
  Indonesia: { lat: -6.21, lon: 106.85 }, Ireland: { lat: 53.35, lon: -6.26 }, Israel: { lat: 31.77, lon: 35.21 },
  Italy: { lat: 41.9, lon: 12.5 }, Japan: { lat: 35.68, lon: 139.76 }, Kenya: { lat: -1.29, lon: 36.82 },
  Latvia: { lat: 56.95, lon: 24.11 }, Lithuania: { lat: 54.69, lon: 25.28 }, Macau: { lat: 22.2, lon: 113.55 },
  Malaysia: { lat: 3.14, lon: 101.69 }, Mexico: { lat: 19.43, lon: -99.13 }, Netherlands: { lat: 52.37, lon: 4.89 },
  "New Zealand": { lat: -41.29, lon: 174.78 }, Norway: { lat: 59.91, lon: 10.75 }, Pakistan: { lat: 33.69, lon: 73.06 },
  Paraguay: { lat: -25.29, lon: -57.64 }, Peru: { lat: -12.05, lon: -77.04 }, Philippines: { lat: 14.6, lon: 120.98 },
  Poland: { lat: 52.23, lon: 21.01 }, Portugal: { lat: 38.72, lon: -9.14 }, "Russian Federation": { lat: 55.76, lon: 37.62 },
  Serbia: { lat: 44.81, lon: 20.46 }, Singapore: { lat: 1.35, lon: 103.82 }, "Slovak Republic": { lat: 48.15, lon: 17.11 }, "South Africa": { lat: -25.75, lon: 28.19 },
  "South Korea": { lat: 37.57, lon: 126.98 }, Spain: { lat: 40.42, lon: -3.7 }, Sweden: { lat: 59.33, lon: 18.07 },
  Switzerland: { lat: 46.95, lon: 7.45 }, Taiwan: { lat: 25.03, lon: 121.57 }, Thailand: { lat: 13.75, lon: 100.5 },
  "Trinidad and Tobago": { lat: 10.66, lon: -61.52 }, Turkey: { lat: 39.93, lon: 32.86 }, Ukraine: { lat: 50.45, lon: 30.52 },
  "United Arab Emirates": { lat: 24.45, lon: 54.38 }, "United Kingdom": { lat: 51.51, lon: -0.13 }, "United States": { lat: 38.9, lon: -77.04 },
  "Virgin Islands (USA)": { lat: 18.34, lon: -64.93 }
};

const state = {
  frame: 0,
  points: [],
  launched: 0,
  arrived: 0,
  speed: 1.25,
  playing: true,
  mapPadding: 48,
  width: 0,
  height: 0,
  pixelRatio: 1,
  landShapes: [],
  countryShapes: [],
  selectedCountry: null,
  countryPoints: [],
  profileLookup: new Map(),
  metadataLookup: new Map(),
  allRecords: [],
  filterStart: "",
  filterEnd: "",
  filterCountry: "",
  filterGenre: "",
  mapCacheCanvas: null,
  mapCacheCtx: null,
  mapCacheDirty: true
};

const dom = {};
let canvas;
let ctx;
let resizeObserver;

document.addEventListener("DOMContentLoaded", () => {
  canvas = document.createElement("canvas");
  ctx = canvas.getContext("2d");
  state.mapCacheCanvas = document.createElement("canvas");
  state.mapCacheCtx = state.mapCacheCanvas.getContext("2d");
  document.getElementById("sketch-root").appendChild(canvas);
  canvas.addEventListener("click", handleCanvasClick);
  bindDom();
  initializeMapData();
  initializeData();
  setupControls();
  resizeCanvas();
  resizeObserver = new ResizeObserver(() => resizeCanvas());
  resizeObserver.observe(document.getElementById("sketch-root"));
  requestAnimationFrame(tick);
});

function bindDom() {
  dom.currentDate = document.getElementById("current-date");
  dom.currentArtist = document.getElementById("current-artist");
  dom.totalArtists = document.getElementById("total-artists");
  dom.countryCount = document.getElementById("country-count");
  dom.genreCount = document.getElementById("genre-count");
  dom.arrivedCount = document.getElementById("arrived-count");
  dom.topCountry = document.getElementById("top-country");
  dom.globalSummary = document.getElementById("global-summary");
  dom.countryList = document.getElementById("country-list");
  dom.directoryList = document.getElementById("directory-list");
  dom.detailEmpty = document.getElementById("detail-empty");
  dom.detailContent = document.getElementById("detail-content");
  dom.detailCountry = document.getElementById("detail-country");
  dom.detailCount = document.getElementById("detail-count");
  dom.detailFirst = document.getElementById("detail-first");
  dom.detailLatest = document.getElementById("detail-latest");
  dom.detailArtists = document.getElementById("detail-artists");
  dom.speedControl = document.getElementById("speed-control");
  dom.filterStart = document.getElementById("filter-start");
  dom.filterEnd = document.getElementById("filter-end");
  dom.filterCountry = document.getElementById("filter-country");
  dom.filterGenre = document.getElementById("filter-genre");
  dom.togglePlay = document.getElementById("toggle-play");
  dom.restartPlay = document.getElementById("restart-play");
  dom.sidebarTabs = [...document.querySelectorAll("[data-sidebar-tab]")];
  dom.sidebarPanels = [...document.querySelectorAll("[data-sidebar-panel]")];
  dom.countryList.addEventListener("click", handleCountryListClick);
  initializeSidebarTabs();
}

function initializeMapData() {
  if (window.WORLD_LAND_TOPOLOGY) {
    state.landShapes = decodeTopologyObject(window.WORLD_LAND_TOPOLOGY, "land");
  }
  if (window.WORLD_COUNTRIES_TOPOLOGY) {
    state.countryShapes = decodeTopologyObject(window.WORLD_COUNTRIES_TOPOLOGY, "countries");
  }
}

function initializeData() {
  const payload = getVisualizationPayload();
  if (!payload || !Array.isArray(payload.records)) {
    document.getElementById("sketch-root").textContent = "Artist data could not be loaded.";
    return;
  }

  state.allRecords = payload.records.map((record, index) => {
    const origin = COUNTRY_COORDS[record.country];
    return {
      ...record,
      index,
      origin,
      profile: record.detailUrl ? { detailUrl: record.detailUrl } : null,
      genre: record.genre || "Unspecified",
      status: "queued",
      progress: 0,
      seed: (index * 9301 + 49297) % 233280
    };
  });

  initializeFilterControls();
  applyDateFilter();
}

function setupControls() {
  dom.filterStart?.addEventListener("change", () => {
    state.filterStart = dom.filterStart.value;
    applyDateFilter();
  });
  dom.filterEnd?.addEventListener("change", () => {
    state.filterEnd = dom.filterEnd.value;
    applyDateFilter();
  });
  dom.filterCountry?.addEventListener("change", () => {
    state.filterCountry = dom.filterCountry.value;
    applyDateFilter();
  });
  dom.filterGenre?.addEventListener("change", () => {
    state.filterGenre = dom.filterGenre.value;
    applyDateFilter();
  });
  dom.speedControl.addEventListener("input", (event) => {
    state.speed = Number(event.target.value);
  });
  dom.togglePlay.addEventListener("click", () => {
    state.playing = !state.playing;
    dom.togglePlay.textContent = state.playing ? "Pause" : "Play";
  });
  dom.restartPlay.addEventListener("click", resetTimeline);
}

function initializeSidebarTabs() {
  if (!dom.sidebarTabs?.length || !dom.sidebarPanels?.length) {
    return;
  }

  for (const button of dom.sidebarTabs) {
    button.addEventListener("click", () => setActiveSidebarTab(button.dataset.sidebarTab || "overview"));
  }
  setActiveSidebarTab("overview");
}

function setActiveSidebarTab(tabName) {
  for (const button of dom.sidebarTabs) {
    const active = button.dataset.sidebarTab === tabName;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", active ? "true" : "false");
  }

  for (const panel of dom.sidebarPanels) {
    const active = panel.dataset.sidebarPanel === tabName;
    panel.classList.toggle("is-active", active);
    panel.hidden = !active;
  }
}

function initializeFilterControls() {
  if (!dom.filterStart || !dom.filterEnd || !dom.filterCountry || !dom.filterGenre) {
    return;
  }

  const labels = [...new Set(state.allRecords.map((record) => record.label))];
  const countries = [...new Set(state.allRecords.map((record) => record.country))].sort((a, b) => a.localeCompare(b));
  const genres = [...new Set(state.allRecords.map((record) => record.genre))].sort((a, b) => a.localeCompare(b));
  const options = labels.map((label) => `<option value="${escapeHtml(label)}">${escapeHtml(label)}</option>`).join("");
  const countryOptions = countries.map((country) => `<option value="${escapeHtml(country)}">${escapeHtml(country)}</option>`).join("");
  const genreOptions = genres.map((genre) => `<option value="${escapeHtml(genre)}">${escapeHtml(genre)}</option>`).join("");
  dom.filterStart.innerHTML = `<option value="">All</option>${options}`;
  dom.filterEnd.innerHTML = `<option value="">All</option>${options}`;
  dom.filterCountry.innerHTML = `<option value="">All</option>${countryOptions}`;
  dom.filterGenre.innerHTML = `<option value="">All</option>${genreOptions}`;
  state.filterStart = "";
  state.filterEnd = "";
  state.filterCountry = "";
  state.filterGenre = "";
}

function applyDateFilter() {
  const filtered = state.allRecords.filter((record) => {
    if (state.filterStart && record.label < state.filterStart) {
      return false;
    }
    if (state.filterEnd && record.label > state.filterEnd) {
      return false;
    }
    if (state.filterCountry && record.country !== state.filterCountry) {
      return false;
    }
    if (state.filterGenre && record.genre !== state.filterGenre) {
      return false;
    }
    return true;
  });

  rebuildFilteredState(filtered);
  state.selectedCountry = state.countryDetails?.has(state.selectedCountry) ? state.selectedCountry : null;
  renderCountryList();
  renderCountryDetail(state.selectedCountry);
  renderDirectory();
  resetTimeline();
  state.mapCacheDirty = true;
}

function rebuildFilteredState(records) {
  const countryTotals = new Map();
  const countryDetails = new Map();

  state.records = records;
  for (const record of state.records) {
    record.status = "queued";
    record.progress = 0;
    countryTotals.set(record.country, (countryTotals.get(record.country) || 0) + 1);
    if (!countryDetails.has(record.country)) {
      countryDetails.set(record.country, {
        country: record.country,
        count: 0,
        firstYear: record.year,
        latestYear: record.year,
        artists: [],
        genres: new Set()
      });
    }

    const detail = countryDetails.get(record.country);
    detail.count += 1;
    detail.firstYear = Math.min(detail.firstYear, record.year);
    detail.latestYear = Math.max(detail.latestYear, record.year);
    detail.genres.add(record.genre);
    detail.artists.push({
      artist: record.artist,
      label: record.label,
      date: record.date,
      detailUrl: record.profile?.detailUrl || "",
      genre: record.genre,
      country: record.country
    });
  }

  const visibleGenres = new Set(state.records.map((record) => record.genre));
  state.countryTotals = [...countryTotals.entries()]
    .map(([country, count]) => ({ country, count }))
    .sort((a, b) => b.count - a.count || a.country.localeCompare(b.country));
  state.countryDetails = new Map(
    [...countryDetails.entries()].map(([country, detail]) => [
      country,
      {
        ...detail,
        genres: [...detail.genres].sort((a, b) => a.localeCompare(b)),
        artists: detail.artists.sort((a, b) => a.date.localeCompare(b.date) || a.artist.localeCompare(b.artist))
      }
    ])
  );

  dom.totalArtists.textContent = state.records.length;
  dom.countryCount.textContent = state.countryTotals.length;
  dom.genreCount.textContent = visibleGenres.size;
  dom.topCountry.textContent = `${state.countryTotals[0]?.country || "-"} (${state.countryTotals[0]?.count || 0})`;
  dom.globalSummary.textContent = state.records.length
    ? `${state.records.length} artists from ${state.countryTotals.length} countries across ${visibleGenres.size} genre labels`
    : "No artists match the current filters.";
}

function resizeCanvas() {
  const root = document.getElementById("sketch-root");
  const ratio = Math.min(window.devicePixelRatio || 1, 1.5);
  state.pixelRatio = ratio;
  state.width = root.clientWidth;
  state.height = root.clientHeight;
  canvas.width = Math.floor(state.width * ratio);
  canvas.height = Math.floor(state.height * ratio);
  state.mapCacheCanvas.width = Math.floor(state.width * ratio);
  state.mapCacheCanvas.height = Math.floor(state.height * ratio);
  canvas.style.width = `${state.width}px`;
  canvas.style.height = `${state.height}px`;
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  state.mapCacheCtx.setTransform(ratio, 0, 0, ratio, 0, 0);
  rebuildPointPositions();
  state.mapCacheDirty = true;
}

function rebuildPointPositions() {
  state.itoshimaScreen = projectLonLat(ITOSHIMA.lon, ITOSHIMA.lat);
  state.countryPoints = [];
  if (!state.records) {
    return;
  }

  const seenCountries = new Set();
  for (const record of state.records) {
    if (!record.origin) {
      record.screenOrigin = null;
      continue;
    }
    const point = projectLonLat(record.origin.lon, record.origin.lat);
    const offsetX = pseudoNoise(record.seed * 0.01) * 36 - 18;
    const offsetY = pseudoNoise(record.seed * 0.02) * 32 - 16;
    record.screenOrigin = { x: point.x + offsetX, y: point.y + offsetY };
    if (!seenCountries.has(record.country)) {
      seenCountries.add(record.country);
      state.countryPoints.push({ country: record.country, x: record.screenOrigin.x, y: record.screenOrigin.y, radius: 8 });
    }
  }
}

function tick() {
  state.frame += 1;
  drawScene();
  requestAnimationFrame(tick);
}

function drawScene() {
  drawCachedMapLayer();
  if (state.playing && state.records) {
    runTimeline();
  }
  drawTrails();
  drawDestination();
}

function drawCachedMapLayer() {
  if (state.mapCacheDirty) {
    renderMapCache();
  }
  ctx.clearRect(0, 0, state.width, state.height);
  ctx.drawImage(state.mapCacheCanvas, 0, 0, state.width, state.height);
}

function renderMapCache() {
  const cacheCtx = state.mapCacheCtx;
  if (!cacheCtx) {
    return;
  }

  cacheCtx.clearRect(0, 0, state.width, state.height);
  drawBackdrop(cacheCtx);
  drawMapLayer(cacheCtx);
  state.mapCacheDirty = false;
}

function runTimeline() {
  const launchInterval = Math.max(4, Math.floor(14 / state.speed));
  if (state.frame % launchInterval === 0 && state.launched < state.records.length) {
    const record = state.records[state.launched];
    record.status = record.screenOrigin ? "flying" : "arrived";
    record.progress = 0;
    if (record.status === "arrived") {
      state.arrived += 1;
    } else {
      state.points.push(record);
    }
    state.launched += 1;
    updateDomForCurrent(record);
  }

  for (const point of state.points) {
    if (point.status !== "flying") {
      continue;
    }
    point.progress += 0.0055 * state.speed;
    if (point.progress >= 1) {
      point.progress = 1;
      point.status = "arrived";
      state.arrived += 1;
    }
  }

  state.points = state.points.filter((point) => point.status === "flying");
  if (state.launched >= state.records.length && state.arrived >= state.records.length) {
    state.playing = false;
    dom.togglePlay.textContent = "Play";
  }
  dom.arrivedCount.textContent = state.arrived;
}

function drawBackdrop(targetCtx = ctx) {
  const oceanGradient = targetCtx.createLinearGradient(0, 0, 0, state.height);
  oceanGradient.addColorStop(0, "#03111a");
  oceanGradient.addColorStop(0.45, "#081a27");
  oceanGradient.addColorStop(1, "#041019");
  targetCtx.fillStyle = oceanGradient;
  targetCtx.fillRect(0, 0, state.width, state.height);

  for (let i = 0; i < 4; i += 1) {
    const radius = state.width * (0.22 + i * 0.1);
    const x = state.width * (0.17 + i * 0.16);
    const y = state.height * (0.12 + i * 0.11);
    const gradient = targetCtx.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, i % 2 === 0 ? "rgba(255,149,101,0.08)" : "rgba(122,242,211,0.06)");
    gradient.addColorStop(1, "rgba(0,0,0,0)");
    targetCtx.fillStyle = gradient;
    targetCtx.beginPath();
    targetCtx.arc(x, y, radius, 0, Math.PI * 2);
    targetCtx.fill();
  }

  const vignette = targetCtx.createRadialGradient(state.width * 0.5, state.height * 0.45, state.width * 0.1, state.width * 0.5, state.height * 0.45, state.width * 0.75);
  vignette.addColorStop(0, "rgba(0,0,0,0)");
  vignette.addColorStop(1, "rgba(0,0,0,0.34)");
  targetCtx.fillStyle = vignette;
  targetCtx.fillRect(0, 0, state.width, state.height);
}

function drawMapLayer(targetCtx = ctx) {
  drawLongitudeLatitudeGrid(targetCtx);
  drawLatitudeBands(targetCtx);
  drawLand(targetCtx);
  drawCountryBorders(targetCtx);
  drawJapanFocus(targetCtx);
  drawOriginDots(targetCtx);
  drawMapLabels(targetCtx);
}

function drawLongitudeLatitudeGrid(targetCtx = ctx) {
  for (let lon = -150; lon <= 150; lon += 30) {
    drawGeodesicLine(
      Array.from({ length: 30 }, (_, index) => projectLonLat(lon, -60 + index * 5)),
      "rgba(122,242,211,0.08)",
      1,
      targetCtx
    );
  }

  for (let lat = -45; lat <= 75; lat += 15) {
    drawGeodesicLine(
      Array.from({ length: 73 }, (_, index) => projectLonLat(-180 + index * 5, lat)),
      lat === 0 ? "rgba(255,149,101,0.18)" : "rgba(255,255,255,0.05)",
      lat === 0 ? 1.3 : 0.8,
      targetCtx
    );
  }
}

function drawLatitudeBands(targetCtx = ctx) {
  const top = projectLonLat(0, 23.5).y;
  const bottom = projectLonLat(0, -23.5).y;
  targetCtx.fillStyle = "rgba(255,255,255,0.025)";
  targetCtx.fillRect(state.mapPadding, top, state.width - state.mapPadding * 2, bottom - top);
}

function drawLand(targetCtx = ctx) {
  if (!state.landShapes.length) {
    return;
  }

  targetCtx.save();
  targetCtx.shadowColor = "rgba(0,0,0,0.35)";
  targetCtx.shadowBlur = 24;
  targetCtx.shadowOffsetY = 10;

  for (const polygon of state.landShapes) {
    const fill = targetCtx.createLinearGradient(0, state.mapPadding, 0, state.height - state.mapPadding);
    fill.addColorStop(0, "rgba(149,225,248,0.16)");
    fill.addColorStop(0.6, "rgba(73,132,153,0.18)");
    fill.addColorStop(1, "rgba(32,73,92,0.24)");
    tracePolygon(polygon, targetCtx);
    targetCtx.fillStyle = fill;
    targetCtx.strokeStyle = "rgba(122,242,211,0.18)";
    targetCtx.lineWidth = 1;
    targetCtx.fill("evenodd");
    targetCtx.stroke();
  }

  targetCtx.restore();
}

function drawCountryBorders(targetCtx = ctx) {
  if (!state.countryShapes.length) {
    return;
  }

  targetCtx.save();
  targetCtx.strokeStyle = "rgba(208, 240, 255, 0.11)";
  targetCtx.lineWidth = 0.55;

  for (const polygon of state.countryShapes) {
    tracePolygon(polygon, targetCtx);
    targetCtx.stroke();
  }

  targetCtx.restore();
}

function drawJapanFocus(targetCtx = ctx) {
  const jp = projectLonLat(138, 37);
  const glow = targetCtx.createRadialGradient(jp.x, jp.y, 0, jp.x, jp.y, 90);
  glow.addColorStop(0, "rgba(122,242,211,0.18)");
  glow.addColorStop(1, "rgba(122,242,211,0)");
  targetCtx.fillStyle = glow;
  targetCtx.beginPath();
  targetCtx.arc(jp.x, jp.y, 90, 0, Math.PI * 2);
  targetCtx.fill();

  targetCtx.strokeStyle = "rgba(122,242,211,0.2)";
  targetCtx.lineWidth = 1;
  targetCtx.beginPath();
  targetCtx.arc(jp.x, jp.y, 42, 0, Math.PI * 2);
  targetCtx.stroke();
}

function drawOriginDots(targetCtx = ctx) {
  for (const point of state.countryPoints) {
    targetCtx.shadowColor = "rgba(122,242,211,0.45)";
    targetCtx.shadowBlur = 12;
    targetCtx.beginPath();
    targetCtx.arc(point.x, point.y, state.selectedCountry === point.country ? 5.5 : 3, 0, Math.PI * 2);
    targetCtx.fillStyle = state.selectedCountry === point.country ? "rgba(255,209,102,0.95)" : "rgba(122,242,211,0.8)";
    targetCtx.fill();
    targetCtx.shadowBlur = 0;
  }
}

function drawTrails() {
  if (!state.itoshimaScreen) {
    return;
  }

  for (const record of state.points) {
    if (!record.screenOrigin) {
      continue;
    }

    const start = record.screenOrigin;
    const end = state.itoshimaScreen;
    const distance = Math.hypot(end.x - start.x, end.y - start.y);
    const arcLift = 78 + distance * 0.055;
    const arcBend = 52 + Math.min(38, distance * 0.03);
    const mid = {
      x: lerp(start.x, end.x, 0.5) + (start.y < end.y ? -1 : 1) * arcBend,
      y: lerp(start.y, end.y, 0.5) - arcLift - Math.abs(end.x - start.x) * 0.05
    };
    const progress = easeInOutCubic(record.progress);
    const head = quadraticPoint(start, mid, end, progress);

    const trailAlpha = 0.16 + progress * 0.34;
    ctx.strokeStyle = `rgba(255,149,101,${trailAlpha})`;
    ctx.lineWidth = 0.8 + progress * 1.4;
    ctx.beginPath();
    let started = false;
    for (let t = 0; t <= progress; t += 0.04) {
      const pt = quadraticPoint(start, mid, end, t);
      if (!started) {
        ctx.moveTo(pt.x, pt.y);
        started = true;
      } else {
        ctx.lineTo(pt.x, pt.y);
      }
    }
    ctx.stroke();

    ctx.strokeStyle = "rgba(122,242,211,0.12)";
    ctx.lineWidth = 0.6;
    ctx.beginPath();
    ctx.moveTo(start.x, start.y);
    ctx.quadraticCurveTo(mid.x, mid.y, head.x, head.y);
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(head.x, head.y, 8, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(255,209,102,0.28)";
    ctx.fill();
    ctx.shadowColor = "rgba(122,242,211,0.55)";
    ctx.shadowBlur = 18;
    ctx.beginPath();
    ctx.arc(head.x, head.y, 3.2 + Math.sin(state.frame * 0.15 + record.index) * 0.9, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(122,242,211,0.95)";
    ctx.fill();
    ctx.shadowBlur = 0;
  }
}

function drawDestination() {
  if (!state.itoshimaScreen) {
    return;
  }

  const pulse = 16 + Math.sin(state.frame * 0.08) * 6;
  drawCircle(state.itoshimaScreen.x, state.itoshimaScreen.y, 54 + pulse, "rgba(255,149,101,0.16)");
  drawCircle(state.itoshimaScreen.x, state.itoshimaScreen.y, 24 + pulse * 0.3, "rgba(122,242,211,0.22)");
  drawCircle(state.itoshimaScreen.x, state.itoshimaScreen.y, 5, "rgba(255,209,102,1)");
  ctx.strokeStyle = "rgba(255,255,255,0.18)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(state.itoshimaScreen.x, state.itoshimaScreen.y, 78 + Math.sin(state.frame * 0.04) * 4, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = "#edf7ff";
  ctx.font = "700 12px 'Space Grotesk', sans-serif";
  ctx.fillText("Itoshima", state.itoshimaScreen.x + 10, state.itoshimaScreen.y - 12);
}

function drawMapLabels(targetCtx = ctx) {
  targetCtx.save();
  for (const label of MAP_LABELS) {
    const point = projectLonLat(label.lon, label.lat);
    targetCtx.fillStyle = label.text === "JAPAN" ? "rgba(255,209,102,0.78)" : "rgba(237,247,255,0.34)";
    targetCtx.font = label.text === "JAPAN" ? "700 10px 'Space Grotesk', sans-serif" : "600 9px 'Space Grotesk', sans-serif";
    targetCtx.fillText(label.text, point.x, point.y);
  }
  targetCtx.restore();
}

function renderCountryList() {
  const maxCount = state.countryTotals[0]?.count || 1;
  dom.countryList.innerHTML = state.countryTotals
    .slice(0, 18)
    .map(({ country, count }) => {
      const ratio = Math.max(8, (count / maxCount) * 100);
      return `
        <div class="country-row${state.selectedCountry === country ? " is-active" : ""}" data-country="${escapeHtml(country)}">
          <div class="country-name">
            <div class="country-title"><span>${escapeHtml(country)}</span></div>
            <div class="country-bar"><div class="country-bar-fill" style="width:${ratio}%"></div></div>
          </div>
          <div class="country-count">${count}</div>
        </div>
      `;
    })
    .join("");
}

function renderCountryDetail(country) {
  if (!dom.detailEmpty || !dom.detailContent) {
    return;
  }
  if (!country || !state.countryDetails?.has(country)) {
    dom.detailEmpty.hidden = false;
    dom.detailContent.hidden = true;
    return;
  }

  const detail = state.countryDetails.get(country);
  dom.detailEmpty.hidden = true;
  dom.detailContent.hidden = false;
  dom.detailCountry.textContent = detail.country;
  dom.detailCount.textContent = String(detail.count);
  dom.detailFirst.textContent = String(detail.firstYear);
  dom.detailLatest.textContent = String(detail.latestYear);
  dom.detailArtists.innerHTML = detail.artists
    .map(
      (artist) => `
        <div class="detail-artist">
          <div class="detail-artist-copy">
            <strong>${escapeHtml(artist.artist)}</strong>
            <span class="detail-artist-date">${escapeHtml(artist.label)}</span>
            <span class="detail-artist-date">${escapeHtml(artist.genre)}</span>
            ${artist.detailUrl ? `<a class="detail-artist-link" href="${escapeHtml(artist.detailUrl)}" target="_blank" rel="noreferrer">Profile</a>` : ""}
          </div>
        </div>
      `
    )
    .join("");
  renderCountryList();
}

function renderDirectory() {
  if (!dom.directoryList) {
    return;
  }

  if (!state.records?.length) {
    dom.directoryList.innerHTML = `<div class="detail-empty">No artists match the current filters.</div>`;
    return;
  }

  dom.directoryList.innerHTML = state.records
    .slice()
    .sort((a, b) => b.date.localeCompare(a.date) || a.artist.localeCompare(b.artist))
    .slice(0, 60)
    .map(
      (record) => `
        <article class="directory-card">
          <div class="directory-title">
            <strong>${escapeHtml(record.artist)}</strong>
            <span class="directory-period">${escapeHtml(record.label)}</span>
          </div>
          <div class="directory-meta">
            <span class="directory-pill">${escapeHtml(record.country)}</span>
            <span class="directory-pill">${escapeHtml(record.genre)}</span>
          </div>
          ${record.profile?.detailUrl ? `<a class="directory-link" href="${escapeHtml(record.profile.detailUrl)}" target="_blank" rel="noreferrer">Profile</a>` : ""}
        </article>
      `
    )
    .join("");
}

function updateDomForCurrent(record) {
  if (!record) {
    dom.currentDate.textContent = state.records?.[0]?.label || "-";
    dom.currentArtist.textContent = "Waiting for playback";
    dom.arrivedCount.textContent = state.arrived;
    return;
  }

  dom.currentDate.textContent = record.label;
  dom.currentArtist.innerHTML = `
    <strong>${escapeHtml(record.artist)}</strong><br>
    ${escapeHtml(record.country)}
  `;
  dom.arrivedCount.textContent = state.arrived;
}

function resetTimeline() {
  state.playing = true;
  state.launched = 0;
  state.arrived = 0;
  state.points = [];
  dom.togglePlay.textContent = "Pause";
  for (const record of state.records || []) {
    record.status = "queued";
    record.progress = 0;
  }
  updateDomForCurrent(null);
}

function handleCanvasClick(event) {
  const rect = canvas.getBoundingClientRect();
  const x = event.clientX - rect.left;
  const y = event.clientY - rect.top;
  let hit = null;
  let bestDistance = Infinity;

  for (const point of state.countryPoints) {
    const distance = Math.hypot(point.x - x, point.y - y);
    if (distance <= point.radius + 14 && distance < bestDistance) {
      bestDistance = distance;
      hit = point.country;
    }
  }

  state.selectedCountry = hit;
  state.mapCacheDirty = true;
  renderCountryDetail(hit);
}

function handleCountryListClick(event) {
  const row = event.target.closest("[data-country]");
  if (!row) {
    return;
  }
  const country = row.getAttribute("data-country");
  state.selectedCountry = country;
  state.mapCacheDirty = true;
  renderCountryDetail(country);
}

function tracePolygon(polygon, targetCtx = ctx) {
  targetCtx.beginPath();
  for (const ring of polygon) {
    ring.forEach((point, index) => {
      const projected = projectLonLat(point[0], point[1]);
      if (index === 0) {
        targetCtx.moveTo(projected.x, projected.y);
      } else {
        targetCtx.lineTo(projected.x, projected.y);
      }
    });
    targetCtx.closePath();
  }
}

function drawGeodesicLine(points, strokeStyle, lineWidth, targetCtx = ctx) {
  targetCtx.strokeStyle = strokeStyle;
  targetCtx.lineWidth = lineWidth;
  targetCtx.beginPath();
  points.forEach((point, index) => {
    if (index === 0) {
      targetCtx.moveTo(point.x, point.y);
    } else {
      targetCtx.lineTo(point.x, point.y);
    }
  });
  targetCtx.stroke();
}

function projectLonLat(lon, lat) {
  const margin = state.mapPadding;
  const usableWidth = state.width - margin * 2;
  const usableHeight = state.height - margin * 2;
  return {
    x: margin + ((lon - MAP_BOUNDS.minLon) / (MAP_BOUNDS.maxLon - MAP_BOUNDS.minLon)) * usableWidth,
    y: margin + (1 - (lat - MAP_BOUNDS.minLat) / (MAP_BOUNDS.maxLat - MAP_BOUNDS.minLat)) * usableHeight
  };
}

function initializeProfileLookup(payload) {
  state.profileLookup = new Map();
  if (!payload || !Array.isArray(payload.records)) {
    return;
  }

  for (const record of payload.records) {
    const exactKey = buildProfileKey(record.label, record.artist, record.country);
    state.profileLookup.set(exactKey, record);

    const fallbackKey = buildProfileKey(record.label, record.artist, "");
    if (!state.profileLookup.has(fallbackKey)) {
      state.profileLookup.set(fallbackKey, record);
    }
  }
}

function initializeMetadataLookup(payload) {
  state.metadataLookup = new Map();
  if (!payload || !payload.records) {
    return;
  }

  for (const [key, value] of Object.entries(payload.records)) {
    state.metadataLookup.set(key, value);
  }
}

function getVisualizationPayload() {
  if (window.VISUALIZATION_DATA?.records) {
    return window.VISUALIZATION_DATA;
  }

  const payload = window.ARTIST_DATA;
  initializeProfileLookup(window.ARTIST_PROFILES);
  initializeMetadataLookup(window.ARTIST_METADATA);
  if (!payload || !Array.isArray(payload.records)) {
    return null;
  }

  return {
    ...payload,
    records: payload.records.map((record) => {
      const profile = resolveProfile(record);
      const metadata = resolveMetadata(record);
      return {
        ...record,
        detailUrl: record.detailUrl || profile?.detailUrl || "",
        genre: metadata.genre || "Unspecified"
      };
    })
  };
}

function resolveProfile(record) {
  if (!state.profileLookup?.size) {
    return null;
  }

  return (
    state.profileLookup.get(buildProfileKey(record.label, record.artist, record.country)) ||
    state.profileLookup.get(buildProfileKey(record.label, record.artist, "")) ||
    null
  );
}

function resolveMetadata(record) {
  const exactKey = buildMetadataKey(record.label, record.artist);
  return state.metadataLookup.get(exactKey) || { genre: "Unspecified" };
}

function buildProfileKey(label, artist, country) {
  return [label, normalizeProfileText(artist), normalizeProfileText(country)].join("|");
}

function buildMetadataKey(label, artist) {
  return [label, normalizeProfileText(artist)].join("|");
}

function normalizeProfileText(value) {
  return repairMojibakeText(value || "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
}

function repairMojibakeText(value) {
  if (!value || !/[\uFF00-\uFFEF]/.test(value)) {
    return value;
  }

  try {
    return decodeURIComponent(escape(value));
  } catch {
    return value;
  }
}

function quadraticPoint(start, control, end, t) {
  return {
    x: (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x,
    y: (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y
  };
}

function lerp(start, end, t) {
  return start + (end - start) * t;
}

function easeInOutCubic(t) {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

function drawCircle(x, y, radius, fillStyle) {
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fillStyle = fillStyle;
  ctx.fill();
}

function pseudoNoise(value) {
  return ((Math.sin(value * 12.9898) * 43758.5453) % 1 + 1) % 1;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function decodeTopologyObject(topology, objectKey) {
  const object = topology.objects?.[objectKey];
  if (!object?.geometries || !Array.isArray(topology.arcs)) {
    return [];
  }

  const absoluteArcs = topology.arcs.map((arc) => decodeArc(arc, topology.transform));
  const polygons = [];

  for (const geometry of object.geometries) {
    if (geometry.type === "Polygon") {
      polygons.push(convertPolygon(geometry.arcs, absoluteArcs));
    } else if (geometry.type === "MultiPolygon") {
      for (const polygonArcs of geometry.arcs) {
        polygons.push(convertPolygon(polygonArcs, absoluteArcs));
      }
    }
  }

  return polygons;
}

function decodeArc(arc, transform) {
  let x = 0;
  let y = 0;
  return arc.map(([dx, dy]) => {
    x += dx;
    y += dy;
    if (transform) {
      return [
        transform.translate[0] + x * transform.scale[0],
        transform.translate[1] + y * transform.scale[1]
      ];
    }
    return [x, y];
  });
}

function convertPolygon(ringIndexes, arcs) {
  return ringIndexes.map((ring) => stitchRing(ring, arcs));
}

function stitchRing(ringIndexes, arcs) {
  const ring = [];
  ringIndexes.forEach((arcIndex, index) => {
    const sourceArc = arcIndex >= 0 ? arcs[arcIndex] : [...arcs[-arcIndex - 1]].reverse();
    sourceArc.forEach((point, pointIndex) => {
      if (index > 0 && pointIndex === 0) {
        return;
      }
      ring.push(point);
    });
  });
  return ring;
}
