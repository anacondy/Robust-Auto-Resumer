// background.js

// We attach a listener to the chrome.downloads.onChanged event.
// This fires whenever any download changes state (starts, pauses, finishes, or interrupts).
chrome.downloads.onChanged.addListener((downloadDelta) => {
    
    // First, we check if the 'state' property of the download actually changed.
    if (downloadDelta.state) {
        
        // We are specifically looking for downloads where the new state is 'interrupted'.
        // This usually happens when the internet connection drops.
        if (downloadDelta.state.current === 'interrupted') {
            
            // Log the interruption to the background console for debugging.
            console.log(`Network drop detected! Download ${downloadDelta.id} was interrupted.`);

            // At this point, we only have the 'delta' (the change). We need the full details 
            // of the download to see if it can be resumed. We use chrome.downloads.search for this.
            chrome.downloads.search({ id: downloadDelta.id }, (results) => {
                
                // Ensure the search actually returned our interrupted download item.
                if (results && results.length > 0) {
                    const downloadItem = results[0];

                    // This is the crucial check: 'canResume' tells us if the server 
                    // hosting the file supports 'Accept-Ranges: bytes'. 
                    if (downloadItem.canResume) {
                        console.log(`Server supports byte-ranges. Attempting to resume download ${downloadItem.id}...`);

                        // Issue the built-in browser command to resume the specific download.
                        chrome.downloads.resume(downloadItem.id, () => {
                            
                            // Check if the browser threw any errors while trying to execute the resume command.
                            if (chrome.runtime.lastError) {
                                console.error(`Failed to resume automatically: ${chrome.runtime.lastError.message}`);
                            } else {
                                console.log(`Success! Resume command sent for download ${downloadItem.id}.`);
                            }
                        });
                    } else {
                        // If 'canResume' is false, the server requires the download to start from 0%.
                        // Our extension smartly ignores these so it doesn't cause infinite error loops.
                        console.log(`Download ${downloadItem.id} cannot be resumed from where it stopped. Server limitations prevent it.`);
                    }
                }
            });
        }
    }
});
