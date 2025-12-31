# 🎵 SenkuPlayer

> A beautiful, premium local music player for iOS with advanced organization and seamless device synchronization.

![Version](https://img.shields.io/badge/version-1.5.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

---

## ✨ Features

### 🎨 Premium Design
- **Apple Music-Inspired UI** - Pixel-perfect, modern interface with smooth animations
- **Dynamic Themes** - Beautiful color schemes that adapt to your music
- **Dark Mode** - Optimized pure black theme for OLED displays
- **Glassmorphism Effects** - Modern, premium visual aesthetics

### 🎵 Powerful Music Player
- **Background Playback** - Continues playing when app is in background or device is locked
- **Lock Screen Controls** - Full integration with iOS lock screen and Control Center
- **Dynamic Island Support** - Native support for iPhone 14 Pro and newer
- **Advanced Playback** - Shuffle, repeat modes, and seamless track transitions

### 📚 Smart Library Management
- **Automatic Metadata** - Extracts song title, artist, album, artwork automatically
- **Custom Playlists** - Create and manage unlimited playlists
- **Favorites System** - Quick access to your most-loved tracks
- **Smart Search** - Fast, intelligent search across your entire library
- **Organized Views** - Browse by Songs, Artists, Albums, or Playlists

### ⚙️ Advanced Features
- **Keep Screen Awake** - Perfect for car mode or music stands
- **Batch Import** - Add multiple songs at once
- **File Management** - Import from Files app or other sources
- **Persistent Storage** - Your library and playlists are saved locally

---

## 🚀 Getting Started

### Requirements
- **iOS:** 17.0 or later
- **Xcode:** 15.0+ (for development)
- **Device:** iPhone or iPad

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/iamalbajith/SenkuMusic.git
   cd SenkuMusic
   ```

2. **Open in Xcode:**
   ```bash
   open SenkuPlayer/SenkuPlayer.xcodeproj
   ```

3. **Build and Run:**
   - Select your target device
   - Press `Cmd + R` to build and run

---

## 📱 Usage

### Importing Music
1. Tap the **+** button in the Library view
2. Select music files from your device
3. SenkuPlayer automatically extracts metadata and artwork

### Creating Playlists
1. Go to the **Playlists** tab
2. Tap **Create Playlist**
3. Add songs from your library

3. Add songs from your library

---

---

## 🏗️ Architecture

### Tech Stack
- **Language:** Swift 5.9
- **Framework:** SwiftUI
- **Audio:** AVFoundation
- **Networking:** MultipeerConnectivity
- **Storage:** FileManager + UserDefaults
- **Metadata:** AVAsset with async/await

### Key Components
- `AudioPlayerManager` - Handles playback, background audio, and system controls
- `MusicLibraryManager` - Manages library, playlists, and metadata extraction
- `MultipeerManager` - Handles device discovery and file transfers
- `ThemeManager` - Dynamic color extraction from album artwork

---

## 🎯 Roadmap

- [ ] iCloud sync for playlists
- [ ] Equalizer and audio effects
- [ ] Lyrics support
- [ ] Apple Watch companion app
- [ ] Widget support
- [ ] CarPlay integration
- [ ] macOS version

---

## 🐛 Known Issues

- **Large Libraries:** Initial metadata extraction for 1000+ songs may take time
- **Network Range:** Device Transfer requires devices to be in close proximity
- **Metadata Quality:** Depends on ID3 tags in source files

---

## 📝 Changelog

### Version 1.5.0 (Current)
- ✅ **Enhanced UI/UX** - Improved user interface and navigation
- ✅ **Performance Improvements** - Optimized playback and library management
- ✅ **Bug Fixes** - Various stability improvements
- ✅ **Code Quality** - Better version control and development workflow
- ✅ **Metadata Handling** - Improved song information extraction

### Version 1.4.0
- Fixed metadata extraction using async/await
- Improved "Clear Library" to physically delete files
- Added "Keep Screen Awake" toggle
- Modernized screen dimension detection

### Version 1.3.0
- Added custom playlists
- Implemented favorites system
- Enhanced search functionality

### Version 1.2.0
- Background playback support
- Lock screen controls
- Dynamic Island integration

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Developer

**Amal B Ajith**  
- GitHub: [@iamalbajith](https://github.com/iamalbajith)
- Project: [SenkuMusic](https://github.com/iamalbajith/SenkuMusic)

---

## ⚠️ Disclaimer

SenkuPlayer is a personal music player for organizing and playing your own music collection. Users are responsible for ensuring they have appropriate rights to any music files they use with this application. This app does not provide, host, or distribute any copyrighted content.

---

## 🙏 Acknowledgments

- Inspired by Apple Music's beautiful design
- Built with SwiftUI and modern iOS frameworks
- Thanks to the Swift community for excellent resources

---

**Made with ❤️ for music lovers**
