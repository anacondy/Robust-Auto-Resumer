# Robust Auto-Resumer

> A lightweight, background-running Chromium extension that intelligently detects network drops and automatically resumes interrupted downloads.

Built as a Computer Application project, featuring a highly stylized, zero-bloat **brutalist user interface**.

---

## 📁 Project Structure

```
Robust-Auto-Resumer/
├── icons/
│   ├── icon16.png       # Toolbar icon
│   ├── icon48.png       # Extensions page icon
│   └── icon128.png      # Chrome Web Store icon
├── background.js        # Service worker: detects network drops & auto-resumes
├── manifest.json        # Extension blueprint and permissions (Manifest V3)
├── popup.css            # Styling: brutalist monospaced typography
├── popup.html           # Structure: skeleton of the popup UI
├── popup.js             # Logic: real-time speed (MB/s) and progress tracking
└── README.md            # This file
```

---

## ✨ Features

- **Background Monitoring** — Uses Chrome's `service_worker` to silently monitor download states without any user interaction.
- **Smart Resuming** — Checks if the server supports `Accept-Ranges: bytes` before attempting a resume, preventing infinite error loops.
- **Brutalist UI** — A striking, minimalist interface inspired by A24's *The Whale* typography. Sharp blue text (`#1A1AFA`) on a cream background (`#F9F9EE`).
- **Real-Time Tracking** — Calculates active download speeds in MB/s, total size, and percentage natively — no external libraries.

---

## 🚀 How to Install & Test (Developer Mode)

Since this extension is not yet on the Chrome Web Store, you can run it locally:

1. Clone or download this repository to your local machine.
2. Open any Chromium-based browser (Chrome, Edge, Brave).
3. Navigate to the extensions page: `chrome://extensions/` (or `edge://extensions/`).
4. Toggle **Developer mode** ON (top right corner).
5. Click **Load unpacked**.
6. Select the `Robust-Auto-Resumer` folder.
7. The extension is now active! Pin it to your toolbar to view the real-time UI.

---

## 🛠️ Built With

- HTML5 / CSS3
- Vanilla JavaScript
- Chrome Extension API — Manifest V3

---

## ©️ License

© 2026 Anuj Meena. All rights reserved.
