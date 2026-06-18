// ============================================================================
// popup.js — PHASE 3 PATCHED
// Fixes: filename crash, NaN bug, memory leak, race condition, lastError
// ============================================================================

let previousBytes = {};
let knownDownloadIds = new Set();
let updateTimer = null;

function formatBytes(bytes) {
  if (bytes == null || isNaN(bytes) || bytes < 0) return 'Unknown';
  if (bytes === 0) return '0.00 MB';
  const k = 1024;
  return (bytes / (k * k)).toFixed(2) + ' MB';
}

function safeFilename(item) {
  if (!item || !item.filename) return 'Unknown File';
  const parts = item.filename.replace(/\\/g, '/').split('/');
  const name = parts[parts.length - 1] || 'Unknown';
  if (name.length <= 25) return name;
  return name.substring(0, 25) + '...';
}

function cleanupStaleIds(activeIds) {
  for (const id of Object.keys(previousBytes)) {
    if (!activeIds.has(Number(id))) {
      delete previousBytes[id];
    }
  }
}

function updateDownloads() {
  chrome.downloads.search({}, (items) => {
    if (chrome.runtime.lastError) {
      console.error('downloads.search failed:', chrome.runtime.lastError.message);
      updateTimer = setTimeout(updateDownloads, 1000);
      return;
    }

    const container = document.getElementById('downloads-container');
    if (!container) {
      updateTimer = setTimeout(updateDownloads, 1000);
      return;
    }

    const activeItems = items.filter(
      item => item.state === 'in_progress' || item.state === 'interrupted'
    );

    const activeIds = new Set(activeItems.map(i => i.id));
    cleanupStaleIds(activeIds);

    if (activeItems.length === 0) {
      container.innerHTML = '<div class="empty-state">NO ACTIVE DOWNLOADS DETECTED.</div>';
      updateTimer = setTimeout(updateDownloads, 1000);
      return;
    }

    let htmlString = '';

    activeItems.forEach(item => {
      const percent = (item.totalBytes > 0)
        ? Math.floor((item.bytesReceived / item.totalBytes) * 100)
        : 0;

      let speedStr = '0.00 MB/S';
      if (item.state === 'in_progress' && !item.paused) {
        if (previousBytes[item.id] !== undefined) {
          const diff = item.bytesReceived - previousBytes[item.id];
          speedStr = formatBytes(Math.max(0, diff)) + '/S';
        }
        previousBytes[item.id] = item.bytesReceived;
      }

      let stateStr = 'DOWNLOADING';
      if (item.state === 'interrupted') stateStr = 'INTERRUPTED (AWAITING RESUME)';
      if (item.state === 'in_progress' && item.paused) stateStr = 'PAUSED';

      const shortName = safeFilename(item);

      htmlString += `
        <div class="download-item">
          <div class="label">FILE</div>     <div class="value">${shortName}</div>
          <div class="label">STATUS</div>   <div class="value">${stateStr}</div>
          <div class="label">PROGRESS</div> <div class="value">${percent}%</div>
          <div class="label">SIZE</div>     <div class="value">${formatBytes(item.bytesReceived)} / ${formatBytes(item.totalBytes)}</div>
          <div class="label">SPEED</div>    <div class="value">${speedStr}</div>
        </div>
      `;
    });

    container.innerHTML = htmlString;
    updateTimer = setTimeout(updateDownloads, 1000);
  });
}

updateDownloads();
