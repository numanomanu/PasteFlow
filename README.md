<div align="center">

# PasteFlow ⚡️

### The Blazing-Fast, Folder-Free Clipboard Manager for macOS.

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Native](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-007AFF?style=for-the-badge)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

**Invoked instantly with `⌘ + ⇧ + V`. Designed for developers, designers, and power users.**

<br />

```
┌────────────────────────────────────────────────────────────────────────┐
│  🔍  Search clipboard...                                               │
│  [ All ]  [ ★ ]  [ ≡ ]  [ 🔗 ]  [ 🖼 ]  [ 🎨 ]                         │
├───────────────────────────────────┬────────────────────────────────────┤
│ ⌘1  git commit -m "feat:..."      │  git commit -m "feat:..."          │
│     Terminal • Just now           │  ────────────────────────────────  │
│ ⌘2  #007AFF                       │  [ COLOR PREVIEW ]                 │
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

If you've used legacy macOS clipboard managers like **Clipy**, you know the pain:
- ❌ **Deep nested folder menus** (`1-30`, `31-60`...) that require tedious mouse hovering.
- ❌ **No real-time search** — you have to browse through hierarchical submenus manually.
- ❌ **Pinned items hijacking the top** — pushing your most recent copy out of sight.

**PasteFlow redesigns the clipboard from scratch:**
- ✅ **Zero Folders**: A pure, chronological flat list. What you just copied is always item #1.
- ✅ **Spotlight-Style 2-Pane UI**: Native frosted glass with rich live preview (Color palette, Image resolution, Code syntax).
- ✅ **Keyboard-First Everything**: Search incrementally, cycle categories with `Tab`, select with `↑`/`↓`, and paste with `Enter` or `⌘1`–`⌘9`.
- ✅ **Favorites on Demand**: Switch to your favorites tab instantly with `Tab`. No hijacking your recent history.
- ✅ **Privacy & Memory Guards**: 1Password/Keychain concealed items are automatically ignored. Huge texts (>200k chars) are guarded against freezing your Mac.

---

## ✨ Features

- **🚀 Instant Global Hotkey**: Summon PasteFlow anywhere with `⌘ + ⇧ + V` (zero lag via Carbon event taps).
- **⌨️ Keyboard Driven**:
  - `↑` / `↓` Navigate items.
  - `Enter (↵)` Paste directly into your frontmost application.
  - `⌘ + 1` ... `⌘ + 9` Instant 1-stroke quick paste for top items.
  - `Tab` / `⇧ + Tab` Cycle filter categories seamlessly.
  - `⌘ + F` / `⌘ + P` Star / unstar as Favorite.
  - `⌘ + C` Copy to clipboard without auto-pasting.
  - `⌘ + Delete` Remove item.
  - `Esc` Close popup instantly.
- **🎨 Smart Content Recognition**:
  - **HEX / RGB / HSL Colors**: Automatically detects color codes (`#007AFF`, `rgb(255, 0, 128)`) and displays an interactive color palette card.
  - **Web URLs**: Highlights domains and provides a 1-click "Open in Browser" action.
  - **Images & Screenshots**: Displays aspect-ratio-accurate thumbnails with resolution and size metadata.
  - **Code Snippets**: Formatted with monospace typography.
- **🛡 Privacy First**:
  - Automatically filters out concealed passwords from 1Password, LastPass, macOS Keychain, and transient clipboard items.
- **🔋 Extreme Energy & Memory Efficiency**:
  - Written in **100% native Swift & SwiftUI** (no Electron, no Chromium).
  - Idle CPU usage: **0.0%**.
  - Memory footprint: **~89 MB** with automatic `NSCache` eviction under system memory pressure.
  - Runs silently as a menu bar accessory app (`LSUIElement`).

---

## ⌨️ Keyboard Shortcuts Reference

| Shortcut | Action |
| :--- | :--- |
| **`⌘ + ⇧ + V`** | Toggle PasteFlow popup |
| **`↑` / `↓`** | Select history item |
| **`Enter (↵)`** | Paste selected item into active application |
| **`⌘ + 1` 〜 `⌘ + 9`** | Quick paste items 1–9 with a single keystroke |
| **`Tab` / `⇧ + Tab`** | Cycle filter categories (`All` ➜ `Favorites` ➜ `Text` ➜ `Links` ➜ `Images` ➜ `Colors`) |
| **`⌘ + F` / `⌘ + P`** | Toggle item Favorite status |
| **`⌘ + C`** | Copy to clipboard (without pasting) |
| **`⌘ + ⌫`** | Delete item from history |
| **`Esc`** | Dismiss popup |
| **Type characters** | Real-time incremental search |

---

## 📦 Installation

### Option 1: Download Prebuilt `.app`
Clone or download the repository, then build and run locally:

```bash
git clone https://github.com/your-username/PasteFlow.git
cd PasteFlow
./build_app.sh
cp -R PasteFlow.app /Applications/
open /Applications/PasteFlow.app
```

### Option 2: Build from Source
Requirements: macOS 14.0+, Xcode 15+ (Swift 6.0 toolchain).

```bash
swift build -c release
```

---

## ⚙️ Accessibility Setup (for Auto-Paste)

PasteFlow automatically simulates `⌘ + V` when you press `Enter` so you don't have to paste manually.

To enable this:
1. Open PasteFlow with `⌘ + ⇧ + V`.
2. Click the **Gear icon (⚙️)** in the bottom right corner (or choose **Preferences...** from the menu bar icon).
3. Under **System Integration**, click **Enable...** next to Accessibility Permission.
4. Toggle **PasteFlow** to ON in macOS **System Settings > Privacy & Security > Accessibility**.

*(If permission is not granted, PasteFlow will still copy the item to your clipboard so you can paste manually.)*

---

## 🏗 Architecture

- **`App`**: Native AppKit entry point (`main.swift`), `AppDelegate`, and `MenuBarController`.
- **`Services`**:
  - `ClipboardMonitor`: Low-overhead `changeCount` polling with timer coalescing for zero idle battery drain.
  - `HotKeyManager`: Native Carbon API global hotkey tap without requiring accessibility permissions.
  - `HistoryStore`: Disk-persisted atomic JSON storage with LRU trimming and in-memory `NSCache` image caching.
  - `PasteService`: `CGEventSource` synthetic keystroke simulation.
  - `LaunchAtLoginManager`: Native macOS 13+ `SMAppService` registration.
- **`Views`**: Pure SwiftUI with AppKit `NSPanel` floating window, vibrant `NSVisualEffectView`, and responsive keyboard navigation.

---

## 📄 License

MIT License. Crafted with ❤️ for macOS power users.
