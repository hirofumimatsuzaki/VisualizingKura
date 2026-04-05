const state = {
  manualRows: [],
  overrideRows: [],
  sourceRows: [],
  fileHandles: {
    manual: null,
    overrides: null
  }
};

const MANUAL_HEADERS = ["label", "artist", "country", "detailUrl"];
const OVERRIDE_HEADERS = ["label", "artist", "country"];
const DRAFT_STORAGE_KEY = "kura-artist-editor-drafts-v1";

document.addEventListener("DOMContentLoaded", () => {
  bindEditorEvents();
  loadEditorData();
});

function bindEditorEvents() {
  document.getElementById("reload-data").addEventListener("click", loadEditorData);
  document.getElementById("add-manual-row").addEventListener("click", () => {
    state.manualRows.unshift({ label: "", artist: "", country: "", detailUrl: "" });
    renderManualTable();
    persistDrafts();
    setStatus("Manual row added.");
  });
  document.getElementById("add-override-row").addEventListener("click", () => {
    state.overrideRows.unshift({ label: "", artist: "", country: "" });
    renderOverrideTable();
    persistDrafts();
    setStatus("Override row added.");
  });
  document.getElementById("download-manual").addEventListener("click", () => downloadCsv("manual-artists.csv", MANUAL_HEADERS, state.manualRows));
  document.getElementById("download-overrides").addEventListener("click", () => downloadCsv("country-overrides.csv", OVERRIDE_HEADERS, state.overrideRows));
  document.getElementById("export-all").addEventListener("click", () => {
    downloadCsv("manual-artists.csv", MANUAL_HEADERS, state.manualRows);
    downloadCsv("country-overrides.csv", OVERRIDE_HEADERS, state.overrideRows);
    setStatus("Both CSV files downloaded.");
  });
  document.getElementById("open-manual-file").addEventListener("click", () => openCsvFile("manual"));
  document.getElementById("open-override-file").addEventListener("click", () => openCsvFile("overrides"));
  document.getElementById("save-manual-file").addEventListener("click", () => saveCsvFile("manual"));
  document.getElementById("save-override-file").addEventListener("click", () => saveCsvFile("overrides"));
  document.getElementById("source-search").addEventListener("input", renderSourceTable);
}

async function loadEditorData() {
  setStatus("Loading CSV files...");
  const [manualText, overrideText] = await Promise.all([
    fetchText("./data/manual-artists.csv"),
    fetchText("./data/country-overrides.csv")
  ]);

  state.manualRows = parseCsv(manualText, MANUAL_HEADERS);
  state.overrideRows = parseCsv(overrideText, OVERRIDE_HEADERS);
  restoreDrafts();
  state.sourceRows = Array.isArray(window.ARTIST_DATA?.records) ? window.ARTIST_DATA.records : [];

  renderManualTable();
  renderOverrideTable();
  renderSourceTable();
  refreshSaveButtons();
  setStatus("Files loaded.");
}

async function fetchText(path) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Failed to load ${path}`);
  }
  return response.text();
}

function parseCsv(text, headers) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((line) => line !== headers.join(","))
    .map((line) => {
      const parts = line.split(",");
      const row = {};
      headers.forEach((header, index) => {
        row[header] = (parts[index] || "").trim();
      });
      return row;
    });
}

function restoreDrafts() {
  try {
    const raw = localStorage.getItem(DRAFT_STORAGE_KEY);
    if (!raw) {
      return;
    }

    const drafts = JSON.parse(raw);
    if (Array.isArray(drafts.manualRows)) {
      state.manualRows = drafts.manualRows;
    }
    if (Array.isArray(drafts.overrideRows)) {
      state.overrideRows = drafts.overrideRows;
    }
  } catch {
    setStatus("Saved browser drafts could not be restored.");
  }
}

function persistDrafts() {
  localStorage.setItem(
    DRAFT_STORAGE_KEY,
    JSON.stringify({
      manualRows: state.manualRows,
      overrideRows: state.overrideRows
    })
  );
}

function renderManualTable() {
  renderEditableTable({
    root: document.getElementById("manual-table"),
    headers: MANUAL_HEADERS,
    rows: state.manualRows,
    onDelete: (index) => {
      state.manualRows.splice(index, 1);
      renderManualTable();
      persistDrafts();
    },
    onChange: (index, key, value) => {
      state.manualRows[index][key] = value;
      persistDrafts();
    }
  });
}

function renderOverrideTable() {
  renderEditableTable({
    root: document.getElementById("override-table"),
    headers: OVERRIDE_HEADERS,
    rows: state.overrideRows,
    onDelete: (index) => {
      state.overrideRows.splice(index, 1);
      renderOverrideTable();
      persistDrafts();
    },
    onChange: (index, key, value) => {
      state.overrideRows[index][key] = value;
      persistDrafts();
    }
  });
}

function renderEditableTable({ root, headers, rows, onDelete, onChange }) {
  const headerHtml = headers.map((header) => `<div class="editor-th">${escapeHtml(header)}</div>`).join("");
  const bodyHtml = rows
    .map((row, index) => {
      const cells = headers
        .map(
          (header) => `
            <label class="editor-cell">
              <input data-index="${index}" data-key="${escapeHtml(header)}" value="${escapeHtml(row[header] || "")}" />
            </label>
          `
        )
        .join("");

      return `
        <div class="editor-tr">
          ${cells}
          <div class="editor-cell editor-cell-action">
            <button type="button" class="editor-delete" data-index="${index}">Delete</button>
          </div>
        </div>
      `;
    })
    .join("");

  root.innerHTML = `
    <div class="editor-thead">
      ${headerHtml}
      <div class="editor-th">action</div>
    </div>
    <div class="editor-tbody">
      ${bodyHtml}
    </div>
  `;

  root.querySelectorAll("input").forEach((input) => {
    input.addEventListener("input", (event) => {
      const index = Number(event.target.dataset.index);
      const key = event.target.dataset.key;
      onChange(index, key, event.target.value);
      setStatus("Browser draft updated.");
    });
  });

  root.querySelectorAll(".editor-delete").forEach((button) => {
    button.addEventListener("click", (event) => {
      onDelete(Number(event.target.dataset.index));
      setStatus("Row deleted.");
    });
  });
}

function renderSourceTable() {
  const query = document.getElementById("source-search").value.trim().toLowerCase();
  const rows = state.sourceRows
    .filter((row) => {
      if (!query) {
        return true;
      }
      return [row.label, row.artist, row.country].some((value) => String(value || "").toLowerCase().includes(query));
    })
    .slice(0, 120);

  document.getElementById("source-count").textContent = `${rows.length} rows`;
  document.getElementById("source-table").innerHTML = `
    <div class="editor-thead">
      <div class="editor-th">label</div>
      <div class="editor-th">artist</div>
      <div class="editor-th">country</div>
      <div class="editor-th">quick action</div>
    </div>
    <div class="editor-tbody">
      ${rows
        .map(
          (row) => `
            <div class="editor-tr">
              <div class="editor-cell editor-cell-static">${escapeHtml(row.label)}</div>
              <div class="editor-cell editor-cell-static">${escapeHtml(row.artist)}</div>
              <div class="editor-cell editor-cell-static">${escapeHtml(row.country)}</div>
              <div class="editor-cell editor-cell-action">
                <button
                  type="button"
                  class="editor-copy-row"
                  data-label="${escapeHtml(row.label)}"
                  data-artist="${escapeHtml(row.artist)}"
                  data-country="${escapeHtml(row.country)}"
                >
                  Add Override
                </button>
              </div>
            </div>
          `
        )
        .join("")}
    </div>
  `;

  document.querySelectorAll(".editor-copy-row").forEach((button) => {
    button.addEventListener("click", (event) => {
      const { label, artist, country } = event.target.dataset;
      state.overrideRows.unshift({ label, artist, country });
      renderOverrideTable();
      persistDrafts();
      setStatus(`Override row added for ${artist}.`);
    });
  });
}

async function openCsvFile(kind) {
  if (!window.showOpenFilePicker) {
    setStatus("Your browser does not support direct file open. Use Reload Files or edit the repo files manually.");
    return;
  }

  const [fileHandle] = await window.showOpenFilePicker({
    multiple: false,
    types: [{ description: "CSV Files", accept: { "text/csv": [".csv"] } }]
  });

  const file = await fileHandle.getFile();
  const text = await file.text();
  if (kind === "manual") {
    state.fileHandles.manual = fileHandle;
    state.manualRows = parseCsv(text, MANUAL_HEADERS);
    renderManualTable();
  } else {
    state.fileHandles.overrides = fileHandle;
    state.overrideRows = parseCsv(text, OVERRIDE_HEADERS);
    renderOverrideTable();
  }

  persistDrafts();
  refreshSaveButtons();
  setStatus(`${file.name} loaded into the editor.`);
}

async function saveCsvFile(kind) {
  const headers = kind === "manual" ? MANUAL_HEADERS : OVERRIDE_HEADERS;
  const rows = kind === "manual" ? state.manualRows : state.overrideRows;
  const filename = kind === "manual" ? "manual-artists.csv" : "country-overrides.csv";
  let handle = state.fileHandles[kind];

  if (!window.showSaveFilePicker && !handle) {
    downloadCsv(filename, headers, rows);
    setStatus(`Direct save is not available. ${filename} was downloaded instead.`);
    return;
  }

  if (!handle && window.showSaveFilePicker) {
    handle = await window.showSaveFilePicker({
      suggestedName: filename,
      types: [{ description: "CSV Files", accept: { "text/csv": [".csv"] } }]
    });
    state.fileHandles[kind] = handle;
  }

  const writable = await handle.createWritable();
  await writable.write(buildCsvText(headers, rows));
  await writable.close();
  refreshSaveButtons();
  setStatus(`${filename} saved.`);
}

function refreshSaveButtons() {
  document.getElementById("save-manual-file").textContent = state.fileHandles.manual ? "Save Back" : "Save CSV";
  document.getElementById("save-override-file").textContent = state.fileHandles.overrides ? "Save Back" : "Save CSV";
}

function downloadCsv(filename, headers, rows) {
  const blob = new Blob([buildCsvText(headers, rows)], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function buildCsvText(headers, rows) {
  const lines = [headers.join(",")];
  for (const row of rows) {
    lines.push(headers.map((header) => sanitizeCsvValue(row[header] || "")).join(","));
  }
  return lines.join("\n");
}

function sanitizeCsvValue(value) {
  return String(value).replace(/[\r\n,]+/g, " ").trim();
}

function setStatus(message) {
  document.getElementById("editor-status").textContent = message;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
