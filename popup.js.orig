let previousBytes = {};

function formatBytes(bytes) {
    if (bytes === 0) return '0.00 MB';
    const k = 1024;
    return (bytes / (k * k)).toFixed(2) + ' MB';
}

function updateDownloads() {
    chrome.downloads.search({}, (items) => {
        const container = document.getElementById('downloads-container');
        
        // Filter for active or recently interrupted downloads
        const activeItems = items.filter(item => item.state === 'in_progress' || item.state === 'interrupted');

        if (activeItems.length === 0) {
            container.innerHTML = '<div class="empty-state">NO ACTIVE DOWNLOADS DETECTED.</div>';
            return;
        }

        let htmlString = '';

        activeItems.forEach(item => {
            // Calculate Percentage
            const percent = item.totalBytes > 0 ? Math.floor((item.bytesReceived / item.totalBytes) * 100) : 0;
            
            // Calculate Speed in MB/s
            let speedStr = '0.00 MB/S';
            if (item.state === 'in_progress' && !item.paused) {
                if (previousBytes[item.id]) {
                    const diff = item.bytesReceived - previousBytes[item.id];
                    speedStr = formatBytes(diff) + '/S';
                }
                previousBytes[item.id] = item.bytesReceived;
            }

            // Determine Status
            let stateStr = 'DOWNLOADING';
            if (item.state === 'interrupted') stateStr = 'INTERRUPTED (AWAITING RESUME)';
            if (item.state === 'in_progress' && item.paused) stateStr = 'PAUSED';

            // Clean up filename length for the UI
            const shortName = item.filename.split('\\').pop().split('/').pop().substring(0, 25) + '...';

            htmlString += `
                <div class="download-item">
                    <div class="label">FILE</div>
                    <div class="value">${shortName}</div>
                    
                    <div class="label">STATUS</div>
                    <div class="value">${stateStr}</div>

                    <div class="label">PROGRESS</div>
                    <div class="value">${percent}%</div>

                    <div class="label">SIZE</div>
                    <div class="value">${formatBytes(item.bytesReceived)} / ${formatBytes(item.totalBytes)}</div>

                    <div class="label">SPEED</div>
                    <div class="value">${speedStr}</div>
                </div>
            `;
        });

        container.innerHTML = htmlString;
    });
}

// Run immediately, then loop every 1000ms (1 second) to create real-time speed data
updateDownloads();
setInterval(updateDownloads, 1000);
