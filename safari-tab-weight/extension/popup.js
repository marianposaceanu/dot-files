"use strict";

const api = globalThis.browser ?? globalThis.chrome;

const loading = document.querySelector("#loading");
const errorPanel = document.querySelector("#error");
const errorMessage = document.querySelector("#error-message");
const resultsPanel = document.querySelector("#results");
const refreshButton = document.querySelector("#refresh");

function setText(selector, value) {
  document.querySelector(selector).textContent = value;
}

function formatBytes(bytes) {
  if (!Number.isFinite(bytes)) return "Unavailable";
  if (bytes === 0) return "0 B";

  const units = ["B", "KB", "MB", "GB"];
  const unitIndex = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / (1024 ** unitIndex);
  const digits = value >= 100 || unitIndex === 0 ? 0 : value >= 10 ? 1 : 2;
  return `${value.toFixed(digits)} ${units[unitIndex]}`;
}

function formatDuration(milliseconds) {
  if (!Number.isFinite(milliseconds)) return "Not finished";
  if (milliseconds < 1000) return `${Math.round(milliseconds)} ms`;
  return `${(milliseconds / 1000).toFixed(milliseconds < 10000 ? 2 : 1)} s`;
}

const WEIGHT_LEVELS = ["low", "medium", "heavy", "ultra"];
const KIBIBYTE = 1024;
const MEBIBYTE = KIBIBYTE ** 2;

function weightBand(value, limits) {
  const band = limits.findIndex((limit) => value <= limit);
  return band === -1 ? WEIGHT_LEVELS.length - 1 : band;
}

function classifyWeight(data) {
  const scriptResources = data.resources.breakdown.find((row) => row.type === "script")
    ?? { count: 0, transfer: 0, encoded: 0 };
  const resourcePayload = data.resources.encodedSize || data.resources.transferSize;
  const scriptPayload = scriptResources.encoded || scriptResources.transfer;
  const metrics = [
    {
      key: "dom",
      value: data.document.nodes,
      limits: [342, 800, 1400],
      weight: 1,
      description: `${data.document.nodes.toLocaleString()} DOM elements`,
    },
    {
      key: "requests",
      value: data.resources.count,
      limits: [45, 77, 185],
      weight: 1,
      description: `${data.resources.count.toLocaleString()} requests`,
    },
    {
      key: "scripts",
      value: scriptResources.count,
      limits: [11, 23, 67],
      weight: 3,
      description: `${scriptResources.count.toLocaleString()} script requests`,
    },
  ];

  if (resourcePayload > 0) {
    metrics.push({
      key: "payload",
      value: resourcePayload,
      limits: [1.25 * MEBIBYTE, 2.5 * MEBIBYTE, 5 * MEBIBYTE],
      weight: 1,
      description: `${formatBytes(resourcePayload)} resource payload`,
    });
  }

  if (scriptPayload > 0) {
    metrics.push({
      key: "javascript",
      value: scriptPayload,
      limits: [300 * KIBIBYTE, 700 * KIBIBYTE, 2 * MEBIBYTE],
      weight: 4,
      description: `${formatBytes(scriptPayload)} JavaScript payload`,
    });
  }

  const measured = metrics.map((metric) => {
    const band = weightBand(metric.value, metric.limits);
    return { ...metric, band, points: band * metric.weight };
  });

  const points = measured.reduce((sum, metric) => sum + metric.points, 0);
  const javascriptBand = measured.find((metric) => metric.key === "javascript")?.band ?? 0;
  const scriptBand = measured.find((metric) => metric.key === "scripts").band;
  const domBand = measured.find((metric) => metric.key === "dom").band;
  const staticUltraCount = measured.filter((metric) =>
    ["dom", "requests", "payload"].includes(metric.key) && metric.band === 3
  ).length;
  let band = weightBand(points, [1, 7, 17]);

  band = Math.max(band, javascriptBand);
  if (scriptBand === 3 || domBand === 3) band = Math.max(band, 2);
  if (staticUltraCount === 3) band = 3;

  const contributors = measured
    .filter((metric) => metric.points > 0)
    .sort((left, right) =>
      right.points - left.points
      || right.value / right.limits[Math.min(right.band, right.limits.length - 1)]
        - left.value / left.limits[Math.min(left.band, left.limits.length - 1)]
    )
    .slice(0, 2)
    .map((metric) => metric.description);

  return {
    key: WEIGHT_LEVELS[band],
    label: WEIGHT_LEVELS[band][0].toUpperCase() + WEIGHT_LEVELS[band].slice(1),
    contributors,
    points,
  };
}

async function inspectPage() {
  function finite(value) {
    return Number.isFinite(value) && value >= 0 ? value : 0;
  }

  function resourceType(entry) {
    if (entry.entryType === "navigation") return "document";

    const type = (entry.initiatorType || "other").toLowerCase();
    if (type === "img" || type === "image") return "image";
    if (type === "css" || type === "link") return "stylesheet";
    if (type === "xmlhttprequest") return "xhr";
    if (type === "frame") return "iframe";
    return type;
  }

  const navigation = performance.getEntriesByType("navigation")[0] ?? null;
  const resources = performance.getEntriesByType("resource");
  const measuredEntries = navigation ? [navigation, ...resources] : resources;
  const breakdown = new Map();
  let transferSize = 0;
  let encodedSize = 0;
  let decodedSize = 0;
  let entriesWithSizes = 0;

  for (const entry of measuredEntries) {
    const transfer = finite(entry.transferSize);
    const encoded = finite(entry.encodedBodySize);
    const decoded = finite(entry.decodedBodySize);
    const type = resourceType(entry);
    const current = breakdown.get(type)
      ?? { type, count: 0, transfer: 0, encoded: 0, decoded: 0 };

    current.count += 1;
    current.transfer += transfer;
    current.encoded += encoded;
    current.decoded += decoded;
    breakdown.set(type, current);

    transferSize += transfer;
    encodedSize += encoded;
    decodedSize += decoded;
    if (transfer > 0 || encoded > 0 || decoded > 0) entriesWithSizes += 1;
  }

  const serviceWorkers = {
    supported: "serviceWorker" in navigator,
    controller: null,
    registrations: [],
    error: null,
  };

  if (serviceWorkers.supported) {
    const controller = navigator.serviceWorker.controller;
    if (controller) {
      serviceWorkers.controller = {
        scriptURL: controller.scriptURL,
        state: controller.state,
      };
    }

    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      serviceWorkers.registrations = registrations.map((registration) => {
        const worker = registration.active ?? registration.waiting ?? registration.installing;
        return {
          scope: registration.scope,
          scriptURL: worker?.scriptURL ?? "",
          state: worker?.state ?? "inactive",
        };
      });
    } catch (error) {
      serviceWorkers.error = error instanceof Error ? error.message : String(error);
    }
  }

  return {
    page: {
      title: document.title || "Untitled page",
      host: location.hostname || location.protocol,
    },
    resources: {
      count: measuredEntries.length,
      entriesWithSizes,
      transferSize,
      encodedSize,
      decodedSize,
      breakdown: [...breakdown.values()].sort((left, right) =>
        right.transfer - left.transfer || right.decoded - left.decoded || right.count - left.count
      ),
    },
    document: {
      nodes: document.getElementsByTagName("*").length,
      scripts: document.scripts.length,
      images: document.images.length,
      stylesheets: document.styleSheets.length,
      frames: document.getElementsByTagName("iframe").length
        + document.getElementsByTagName("frame").length,
    },
    timing: {
      domContentLoaded: navigation?.domContentLoadedEventEnd > 0
        ? navigation.domContentLoadedEventEnd - navigation.startTime
        : null,
      load: navigation?.loadEventEnd > 0
        ? navigation.loadEventEnd - navigation.startTime
        : null,
    },
    serviceWorkers,
  };
}

function renderWorkers(serviceWorkers) {
  const workerList = document.querySelector("#worker-list");
  workerList.replaceChildren();

  if (!serviceWorkers.supported || serviceWorkers.error) {
    setText("#worker-controller", "Unavailable");
    setText("#worker-count", "Unavailable");
    return;
  }

  setText("#worker-controller", serviceWorkers.controller ? "Yes" : "No");
  setText("#worker-count", String(serviceWorkers.registrations.length));

  for (const registration of serviceWorkers.registrations) {
    const item = document.createElement("li");
    const scope = document.createElement("strong");
    const script = document.createElement("span");

    scope.textContent = registration.scope;
    scope.title = registration.scope;
    script.textContent = registration.scriptURL
      ? `${registration.state} · ${registration.scriptURL}`
      : registration.state;
    script.title = registration.scriptURL;
    item.append(scope, script);
    workerList.append(item);
  }
}

function renderBreakdown(rows) {
  const tableBody = document.querySelector("#resource-breakdown");
  tableBody.replaceChildren();

  for (const row of rows) {
    const tableRow = document.createElement("tr");
    for (const value of [row.type, row.count, formatBytes(row.transfer), formatBytes(row.decoded)]) {
      const cell = document.createElement("td");
      cell.textContent = String(value);
      tableRow.append(cell);
    }
    tableBody.append(tableRow);
  }
}

function renderWeight(data, hiddenSizes) {
  const rating = classifyWeight(data);
  const card = document.querySelector("#weight-card");
  card.dataset.rating = rating.key;
  setText("#weight-rating", rating.label);
  setText(
    "#weight-reasons",
    rating.contributors.length === 0
      ? "All observed signals are in the leanest band."
      : `${rating.key === "low" ? "Highest observed signal" : "Main contributors"}: ${rating.contributors.join(" · ")}`
  );
  setText(
    "#weight-method",
    hiddenSizes > 0
      ? "JavaScript-weighted score across payload, DOM, and requests. Hidden sizes can make the estimate read too low."
      : "JavaScript-weighted score across payload, DOM, and requests."
  );
}

function render(data) {
  setText("#page-host", data.page.host);
  setText("#page-title", data.page.title);

  setText("#transfer-size", formatBytes(data.resources.transferSize));
  setText("#decoded-size", formatBytes(data.resources.decodedSize));
  setText("#request-count", data.resources.count.toLocaleString());
  setText("#dom-nodes", data.document.nodes.toLocaleString());
  setText("#script-count", data.document.scripts.toLocaleString());
  setText("#image-count", data.document.images.toLocaleString());
  setText("#stylesheet-count", data.document.stylesheets.toLocaleString());
  setText("#frame-count", data.document.frames.toLocaleString());
  setText("#dom-content-loaded", formatDuration(data.timing.domContentLoaded));
  setText("#load-time", formatDuration(data.timing.load));

  const hiddenSizes = data.resources.count - data.resources.entriesWithSizes;
  renderWeight(data, hiddenSizes);
  setText(
    "#size-coverage",
    hiddenSizes > 0
      ? `Sizes are observable for ${data.resources.entriesWithSizes} of ${data.resources.count} requests; cached or cross-origin resources can report zero.`
      : `Sizes are observable for all ${data.resources.count} requests.`
  );

  renderWorkers(data.serviceWorkers);
  renderBreakdown(data.resources.breakdown);
}

function friendlyError(error) {
  const message = error instanceof Error ? error.message : String(error);
  if (/permission|not allowed|cannot access|unsupported URL|missing host/i.test(message)) {
    return "Safari blocks extension access to internal pages, Reader, PDFs, and other restricted URLs. Website access may also need approval in Safari Settings → Extensions.";
  }
  return message || "Safari returned no measurements for this page.";
}

async function measure() {
  loading.hidden = false;
  errorPanel.hidden = true;
  resultsPanel.hidden = true;
  refreshButton.disabled = true;

  try {
    const [tab] = await api.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id) throw new Error("Safari did not return an active tab.");

    const injectionResults = await api.scripting.executeScript({
      target: { tabId: tab.id },
      world: "MAIN",
      func: inspectPage,
    });
    const topFrame = injectionResults.find((result) => result.frameId === 0) ?? injectionResults[0];
    if (!topFrame || topFrame.error) {
      throw new Error(topFrame?.error?.message || "Safari returned no measurements for this page.");
    }

    render(topFrame.result);
    loading.hidden = true;
    resultsPanel.hidden = false;
  } catch (error) {
    errorMessage.textContent = friendlyError(error);
    loading.hidden = true;
    errorPanel.hidden = false;
  } finally {
    refreshButton.disabled = false;
  }
}

refreshButton.addEventListener("click", measure);
measure();
