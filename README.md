# Robust Auto-Resumer 

🌐A lightweight, background-running Chromium extension that intelligently detects network drops and automatically resumes interrupted downloads. Built as a Computer Application project, it features a highly stylized, zero-bloat brutalist user interface.📁 Project TreeWhen pushing to GitHub, your project folder (AutoResumeExtension/) should look exactly like this:AutoResumeExtension/
├── background.js       # Service worker: Listens for network drops and auto-resumes
├── manifest.json       # Extension blueprint and permissions
├── popup.css           # Styling: Brutalist, monospaced typography (Light Mode)
├── popup.html          # Structure: The skeleton of the extension's popup UI
├── popup.js            # Logic: Calculates real-time speed (MB/s) and progress
└── README.md           # This documentation file
✨ FeaturesBackground Monitoring: Uses Chrome's service_worker to silently monitor download states.Smart Resuming: Checks if the server supports Accept-Ranges: bytes before attempting a resume, preventing infinite error loops.Brutalist UI: A striking, minimalist interface inspired by A24's The Whale typography. Features sharp blue text (#1A1AFA) on a cream background (#F9F9EE).Real-Time Tracking: Calculates active download speeds in MB/s, total size, and percentage natively without external libraries.🚀 How to Install & Test (Developer Mode)Since this extension is not currently on the Chrome Web Store, you can run it locally:Clone or download this repository to your local machine.Open any Chromium-based browser (Chrome, Edge, Brave).Navigate to the extensions page: chrome://extensions/ (or edge://extensions/).Toggle Developer mode ON (usually in the top right corner).Click the Load unpacked button.Select the AutoResumeExtension folder.The extension is now active! Pin it to your toolbar to view the real-time UI.🛠️ Built WithHTML5 / CSS3Vanilla JavaScriptChrome Extension API Manifest V3©️ License© 2026 Anuj Meena.
