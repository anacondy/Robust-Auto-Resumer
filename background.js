// background.js — PHASE 2 PATCHED
// Fix: null-guard on downloadDelta.id + debounce against rapid re-fires

const pendingResumes = new Set();  // dedup guard

chrome.downloads.onChanged.addListener((downloadDelta) => {

  // GUARD: bail if id is missing (would cause search to return ALL downloads)
  if (downloadDelta.id == null) return;

  // GUARD: only act on state changes
  if (!downloadDelta.state) return;

  if (downloadDelta.state.current === 'interrupted') {

    // DEBOUNCE: skip if we're already processing this download
    if (pendingResumes.has(downloadDelta.id)) {
      console.log(`Already processing resume for download ${downloadDelta.id} — skipping duplicate.`);
      return;
    }
    pendingResumes.add(downloadDelta.id);

    console.log(`Network drop detected! Download ${downloadDelta.id} was interrupted.`);

    chrome.downloads.search({ id: downloadDelta.id }, (results) => {

      // Check for API errors
      if (chrome.runtime.lastError) {
        console.error(`search failed for download ${downloadDelta.id}: ${chrome.runtime.lastError.message}`);
        pendingResumes.delete(downloadDelta.id);
        return;
      }

      if (results && results.length > 0) {
        const downloadItem = results[0];

        if (downloadItem.canResume) {
          console.log(`Server supports byte-ranges. Attempting to resume download ${downloadItem.id}...`);

          chrome.downloads.resume(downloadItem.id, () => {
            if (chrome.runtime.lastError) {
              console.error(`Failed to resume automatically: ${chrome.runtime.lastError.message}`);
            } else {
              console.log(`Success! Resume command sent for download ${downloadItem.id}.`);
            }
            pendingResumes.delete(downloadItem.id);
          });
        } else {
          console.log(`Download ${downloadItem.id} cannot be resumed from where it stopped. Server limitations prevent it.`);
          pendingResumes.delete(downloadItem.id);
        }
      } else {
        pendingResumes.delete(downloadDelta.id);
      }
    });
  }
});
