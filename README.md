# SenkuPlayer - Local Music Player

A pixel-perfect Apple Music clone that plays local music files with full background playback support, multi-device sharing, and cross-platform compatibility (iOS & macOS).

## ✨ Features

### 🍏 Cross-Platform Compatibility
- **Universal App**: Run natively on both **iOS** and **macOS** with a single codebase.
- **Platform-Aware UI**: Automatically adjusts layout and controls for iPad, iPhone, and Mac.
- **macOS Optimization**: Supports window resizing, native menus, and Mac-specific file navigation.

### 📡 Nearby Share (AirDrop-style)
- **Device-to-Device Sharing**: Send songs over the local network using Multipeer Connectivity.
- **Cross-Device Support**: Share seamlessly between iPhone to iPhone, Mac to iPhone, or iPhone to Mac.
- **Bulk Sharing**: Select multiple songs and send them all at once.
- **Instant Importing**: Received songs are automatically added to the library and ready to play.

### ❤️ Favorites & Playlists
- **Persistent Favorites**: Mark songs as favorites and access them instantly.
- **Custom Playlists**: Create, rename, and organize your music into collections.
- **Bulk Actions**: Add multiple songs to playlists or favorites simultaneously.

### 🎨 Premium UI/UX
- **Apple Music-Inspired Design**: Pixel-perfect recreation of the premium Apple Music interface.
- **Adaptive Backgrounds**: Dynamic backgrounds that extract and match the dominant color of the album artwork.
- **Interactive Mini Player**: Floating mini player that stays accessible across the entire app.
- **Dark Mode Support**: Pure black theme for OLED screens.
- **Fluid Animations**: High-performance spring animations and transitions.

### 🎵 Core Playback
- **Local File Support**: Import and play MP3 files from any folder.
- **Background Audio**: Keep the music going when the app is in the background or the screen is locked.
- **Metadata Extraction**: High-fidelity extraction of Title, Artist, Album, and embedded Artwork.
- **Shuffle & Repeat**: Smart playback modes (Off, All, One).
- **Control Center Integration**: Full support for lock screen controls, headphones, and system playback commands.

## 📁 Project Structure

```
SenkuPlayer/
├── Models/
│   ├── Song.swift              # Song model with ID3 metadata extraction
│   ├── Album.swift             # Album grouping model
│   ├── Artist.swift            # Artist grouping model
│   └── Playlist.swift          # User-created playlist model
├── Managers/
│   ├── AudioPlayerManager.swift    # AVFoundation-based audio engine
│   ├── MusicLibraryManager.swift   # Library scanning and organization
│   ├── FavoritesManager.swift      # Persistent favoriting system
│   └── MultipeerManager.swift      # Nearby Share connectivity engine
├── Utilities/
│   └── PlatformExtensions.swift    # iOS/macOS compatibility layer
├── Views/
│   ├── LibraryView.swift          # Main library interface
│   ├── SongsListView.swift        # Songs list with bulk selection & swipe actions
│   ├── AlbumsListView.swift       # Albums grid and detail views
│   ├── ArtistsListView.swift      # Artists list and detail views
│   ├── PlaylistsListView.swift    # Playlists management
│   ├── NowPlayingView.swift       # Full-screen immersive player
│   ├── MiniPlayerView.swift       # Floating mini player
│   ├── NearbyShareView.swift      # Device discovery and transfer UI
│   ├── SettingsView.swift         # App settings and themes
│   └── DocumentPicker.swift       # Native file/folder selection (iOS/macOS)
└── SenkuPlayerApp.swift           # App entry point with audio session config
```

## 🛠 Setup & Requirements

### Technical Requirements
- **iOS**: 17.0 or later
- **macOS**: 14.0 or later (Sonoma)
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later

### Configuration (Mac Sandbox)
For **Nearby Share** to work on macOS, you must enable network entitlements in Xcode:
1. Select the **SenkuPlayer** target.
2. Go to **Signing & Capabilities**.
3. Under **App Sandbox**, check:
   - [x] Incoming Connections (Server)
   - [x] Outgoing Connections (Client)

### Local Network Permissions (iOS)
iOS will prompt for **Local Network** access the first time you use Nearby Share. Ensure this is granted to allow device discovery.

## 🚀 How to Use

### Importing Music
1. Tap the **Add Folder** icon in the Library.
2. Select any folder containing MP3 files.
3. SenkuPlayer will recursively scan and organize them into Artists, Albums, and Songs.

### Sharing Songs Nearby
1. **From Library**: Swipe left on any song and tap the blue **Share** icon.
2. **From Selection**: Tap **Select**, pick multiple songs, and tap **Send** in the top right.
3. **From Player**: Tap the Share (Wave) icon in the Now Playing screen.
4. The receiver must also be in the "Nearby" tab for discovery to work.

## 📝 Troubleshooting

- **Mac can't find iPhone**: Ensure both devices have Wi-Fi and Bluetooth ON. Check if the Mac Firewall or a VPN is blocking local connections.
- **Music stops in background**: Verify that "Background Modes" (Audio) is enabled in Xcode Capabilities.
- **Artwork not showing**: SenkuPlayer extracts artwork directly from the file's ID3 tags. If it's missing, try using a metadata editor like Mp3tag.

---
**Developed by Amal**  
*Building a premium community-driven music experience.*
