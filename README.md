<div align="center">

# PasteFlow ⚡️

### The Blazing-Fast, Folder-Free Native macOS Clipboard Manager.
**A modern Spotlight-style clipboard experience. The keyboard-first alternative to Clipy and bloated Electron tools.**

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-007AFF?style=for-the-badge)](https://developer.apple.com)
[![Size](https://img.shields.io/badge/Binary-under%20600%20KB-success?style=for-the-badge)](https://github.com/numanomanu/PasteFlow/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

<br />

[**⬇️ Download Latest Release (.zip)**](https://github.com/numanomanu/PasteFlow/releases/latest) • [**✨ Features**](#-features) • [**⌨️ Shortcuts**](#️-keyboard-shortcuts) • [**📦 Install**](#-installation)

<br />

```
┌────────────────────────────────────────────────────────────────────────┐
│  🔍  Search clipboard history...                                       │
│  [ All ]  [ ★ ]  [ ≡ ]  [ 🔗 ]  [ 🖼 ]  [ 🎨 ]                         │
├───────────────────────────────────┬────────────────────────────────────┤
│ ⌘1  git commit -m "feat:..."      │  git commit -m "feat:..."          │
│     Terminal • Just now           │  ────────────────────────────────  │
│ ⌘2  #007AFF                       │  [ COLOR PREVIEW CARD ]            │
│     Xcode • 2m ago                │  HEX: #007AFF                      │
│ ⌘3  https://github.com            │  RGB: rgb(0, 122, 255)             │
│     Chrome • 5m ago               │  ────────────────────────────────  │
│ ⌘4  Image (1920 × 1080)           │  42 chars • 1 lines                │
│     CleanShot X • 10m ago         │  [ 🗑 Del ] [ 📄 Copy ] [ ↵ Paste] │
├───────────────────────────────────┴────────────────────────────────────┤
│  ↵ Paste   Tab Filter   ⌘1-9 Quick   ⌘F Fav   ⌘C Copy   ⌘⌫ Del   Esc   │
└────────────────────────────────────────────────────────────────────────┘
```

</div>

---

## ⚡️ Why PasteFlow?

If you've used legacy macOS clipboard managers like **Clipy**, you know the friction:
- ❌ **Deep nested menus** (`1-30`, `31-60`...) that force tedious mouse hovering.
- ❌ **No real-time search** — you must navigate submenus manually to find past clips.
- ❌ **Pinned clips pushing recent copies down** — cluttering the top of your list.
- ❌ **Heavy Electron alternatives** — consuming 500MB+ RAM and draining laptop battery.

**PasteFlow redesigns the clipboard workflow from scratch:**

| Feature | PasteFlow ⚡️ | Legacy Clipy 📁 | Electron Apps 🌐 |
| :--- | :---: | :---: | :---: |
| **Interface** | **Spotlight / Raycast 2-Pane** | Deep nested menus | Web browser wrapper |
| **Hierarchy** | **Zero Folders (Flat & Recent)** | Nested folders (1-30...) | Varies |
| **Search** | **Real-Time Incremental** | ❌ None | Slow |
| **Auto-Paste** | **Instant `Enter` / `⌘1-9`** | Mouse-click required | Varies |
| **Memory Footprint** | **~80 MB** (Native SwiftUI) | ~60 MB (Legacy Obj-C) | 400 MB ~ 1 GB |
| **Binary Size** | **< 600 KB** | ~10 MB | 100 MB+ |
| **IME Compatibility** | **Full (CJK / Japanese Safe)** | ⚠️ Key Conflicts | Varies |

---

## ✨ Features

- **🚀 Instant Global Hotkey**: Press `⌘ + ⇧ + V` from any app to toggle PasteFlow without latency.
- **⌨️ Keyboard-First Efficiency**:
  - `↑` / `↓` Navigate items.
  - `Enter (↵)` Auto-paste selected item directly into your active app.
  - `⌘ + 1` 〜 `⌘ + 9` Paste any of the top 9 clips in a single keystroke.
  - `Tab` / `⇧ + Tab` Cycle category filters seamlessly.
  - `⌘ + F` / `⌘ + P` Star / unstar items as Favorites.
  - `⌘ + C` Copy item to pasteboard without auto-pasting.
  - `⌘ + ⌫` Delete selected item.
  - `Esc` Multi-stage dismiss (Preferences ➜ clear search ➜ close).
- **🎨 Smart Content Detection**:
  - **Color Codes**: Automatically parses HEX, RGB, RGBA, and HSL values with live interactive color cards.
  - **URLs & Links**: Highlights domains with a 1-click "Open in Browser" action.
  - **Images & Screenshots**: Displays aspect-ratio thumbnails with exact pixel dimensions and file size.
  - **File URLs**: Prioritizes actual file paths over Finder icon representations.
  - **Code & Text**: Clean monospace preview with line and character counts.
- **🛡 Privacy & Safety**:
  - Automatically ignores concealed password items from **1Password**, **LastPass**, **Bitwarden**, and **macOS Keychain**.
  - Built-in guard against massive text dumps (>200,000 characters) to prevent memory spikes.
- **🔋 Zero Battery Drain**:
  - Pure native Swift & SwiftUI. No Node.js, no Chromium.
  - Idle CPU usage: **0.0%**.
  - Background menu bar accessory (`LSUIElement`).

---

## ⌨️ Keyboard Shortcuts

| Key | Action |
| :--- | :--- |
| **`⌘ + ⇧ + V`** | Toggle PasteFlow popup window |
| **`↑` / `↓`** | Navigate through clipboard history |
| **`Enter (↵)`** | Paste item into frontmost application |
| **`⌘ + 1` 〜 `⌘ + 9`** | 1-keystroke quick paste for top items |
| **`Tab` / `⇧ + Tab`** | Switch filter category (`All` ➜ `★ Favs` ➜ `Text` ➜ `Links` ➜ `Images` ➜ `Colors`) |
| **`⌘ + F` / `⌘ + P`** | Toggle Favorite status |
| **`⌘ + C`** | Copy to clipboard (without auto-pasting) |
| **`⌘ + ⌫`** | Delete item from history |
| **`Esc`** | Close window / clear search |
| **Type anything** | Real-time instant search filter |

---

## 📦 Installation

### Option 1: Direct Download (Quickest)

1. Download the latest `PasteFlow-v1.0.0.zip` from [**Releases**](https://github.com/numanomanu/PasteFlow/releases/latest).
2. Unzip and drag `PasteFlow.app` to your `/Applications` folder.
3. Open `PasteFlow.app`.

> [!NOTE]
> **First Launch Notice (macOS Gatekeeper)**:
> PasteFlow is an independent open-source tool distributed without an Apple Developer subscription (\$99/year). If macOS displays an *"unidentified developer"* or *"cannot verify"* message on first launch:
>
> Run this one-line command in Terminal:
> ```bash
> xattr -cr /Applications/PasteFlow.app
> ```
> *(Alternatively: Right-click `PasteFlow.app` in Finder ➜ hold Option and select **Open** ➜ click **Open**).*

---

### Option 2: Build from Source

Requirements: macOS 14.0+, Xcode 15 or 16 (Swift 6.0 toolchain).

```bash
git clone https://github.com/numanomanu/PasteFlow.git
cd PasteFlow
./build_app.sh
cp -R PasteFlow.app /Applications/
open /Applications/PasteFlow.app
```
*(Locally built apps are automatically trusted by macOS and do not trigger Gatekeeper).*

---

## ⚙️ Accessibility Setup (for Auto-Paste)

PasteFlow automatically simulates `⌘ + V` when you press `Enter` to paste into your target application.

1. Summon PasteFlow with `⌘ + ⇧ + V`.
2. Click the **Gear icon (⚙️)** in the bottom right corner (or select **Preferences...** from the menu bar icon).
3. Under **System Integration**, click **Enable...** next to Accessibility Permission.
4. Enable **PasteFlow** in **System Settings > Privacy & Security > Accessibility**.

*(If permission is not granted, PasteFlow still copies the item to your clipboard so you can paste manually.)*

---

## 💻 System Requirements

- **macOS**: 14.0 (Sonoma) or 15.0+ (Sequoia)
- **Architecture**: Universal (Apple Silicon M1/M2/M3/M4 & Intel x86_64)
- **RAM**: ~80 MB typical usage

---

## 📄 License

MIT License. Designed with ❤️ for macOS power users.
