# SenkuPlayer - Premium Local Music Player

A pixel-perfect Apple Music clone designed for high-performance local music playback, seamless cross-device sharing, and advanced organization. Built with Swift and SwiftUI for iOS and macOS.

## ✨ Features

### 🍏 Cross-Platform Compatibility
- **Universal App**: Native support for **iOS** (iPhone/iPad) and **macOS** with a consistent, premium interface.
- **Platform-Aware UI**: Automatically adapts layouts for touch on iOS and precise mouse interaction on macOS.
- **macOS Excellence**: Native window management, menu support, and optimized file navigation.

### 📡 Nearby Share (Peer-to-Peer)
- **Direct Song Sharing**: Send music directly between devices (iPhone ↔ iPhone, Mac ↔ iPhone) using Multipeer Connectivity.
- **Bulk Transfers**: Share multiple tracks or entire custom selections simultaneously.
- **Live Discovery**: Instant device discovery with secure invitation-based connection handling.
- **Auto-Import**: Received tracks are immediately processed and organized into your library.

### ❤️ Smart Library & Playlists
- **Persistent Favorites**: Swift-powered persistence keeps your favorite tracks available across sessions.
- **Custom Playlists**: Create and manage unlimited playlists with easy song addition and removal.
- **Advanced Metadata Engine**: Automated extraction of Song Title, Artist, Album, Year, and high-resolution Artwork using modern async/await patterns.
- **Duplicate Prevention**: intelligent scanning ensures your library stays clean and free of duplicate entries.

### 🎨 Premium UI/UX
- **Apple Music Aesthetic**: High-fidelity recreation of the modern music experience.
- **Adaptive Visuals**: Immersive backgrounds that dynamically extract colors from the current album art.
- **Seamless Mini Player**: Always-accessible playback controls that float elegantly across the app.
- **Dark Mode**: Optimized pure black theme for OLED displays and low-light environments.
- **Interactive Animations**: Premium spring-based transitions and haptic feedback.

### 🎵 Pro Playback Engine
- **Background Audio**: Robust support for lock screen, Dynamic Island, and background playback.
- **Resource Efficient**: Metadata extraction is offloaded to background tasks to prevent UI hangs.
- **Comprehensive Controls**: Full support for Shuffle, Repeat (One/All), and system remote commands (headphones, Control Center).
- **Control Center Integration**: Native integration with system playback sliders and artwork display.

## 🛠 Developer & Debugging (Easter Egg)
SenkuPlayer includes a hidden suite of tools for power users and developers.
1. Go to **Settings > About**.
2. Tap the **Version** text **7 times**.
3. A new **Developer** section will appear with:
    - **Show File Extensions**: View raw filenames in lists for easier file management.
    - **Disable Artwork Animation**: Optimize performance on older devices by disabling UI scaling.
    - **Enable Console Logging**: View real-time metadata scanning logs in the debug console.
    - **Force Vibrant UI**: Enforce colorful gradients even for files without artwork.

## 📁 Installation & Requirements
- **iOS**: 17.0+
- **macOS**: 14.0+ (Sonoma)
- **Xcode**: 15.0+

### macOS Permissions
Ensure **Incoming/Outgoing Connections** are checked in the App Sandbox settings for Nearby Share functionality.

## 🚀 Known Issues & Limitations
- **Network Dependency**: Nearby Share requires devices to be in close proximity with Wi-Fi and Bluetooth enabled.
- **Library Scan Time**: Extremely large folders (1000+ songs) may take a few seconds to fully process metadata on the first import.
- **Metadata Limits**: Metadata extraction depends on the file's ID3 tags. Non-standard or corrupted tags may result in "Unknown Artist" labels.

## 📝 Changelog (v1.4.0)
- **Resolved**: Fixed critical hang risk and priority inversion by migrating to async/await metadata loading.
- **Fixed**: "Clear Library" now physically deletes files from local storage to prevent reappearing after restart.
- **Added**: "Keep Screen Awake" toggle in Settings for stand/car usage.
- **Added**: Hidden Developer Settings menu for advanced debugging.
- **Updated**: Modernized screen dimension detection (deprecated `UIScreen.main` removed).

---
**Developed by Amal**  
*The ultimate local music experience.*
