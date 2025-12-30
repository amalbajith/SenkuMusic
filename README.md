# SenkuPlayer - Local Music Player

A pixel-perfect Apple Music clone that plays local MP3 files with full background playback support and Dynamic Island integration.

## Features

### ✨ Core Features
- **Local MP3 Playback**: Play MP3 files from your device
- **Background Audio**: Continue playing music when app is in background or device is locked
- **ID3 Metadata Reading**: Automatic extraction of song title, artist, album, artwork, and more
- **Library Management**: Organize music by songs, albums, artists, and playlists
- **Search**: Search across all your music
- **Playlist Management**: Create, edit, and delete custom playlists

### 🎨 UI/UX
- **Apple Music-Inspired Design**: Pixel-perfect recreation of Apple Music's interface
- **Now Playing Screen**: Full-screen player with album artwork and controls
- **Mini Player**: Bottom-anchored mini player for quick access
- **Library Views**: Segmented control for Playlists, Artists, Albums, and Songs
- **Album Art Visualization**: Beautiful artwork display with dominant color extraction
- **Smooth Animations**: Spring-based animations throughout

### 🎵 Playback Features
- **Playback Controls**: Play, pause, next, previous
- **Shuffle & Repeat**: Full shuffle and repeat modes (off, all, one)
- **Progress Slider**: Seek to any position in the track
- **Queue Management**: View and manage playback queue
- **Remote Controls**: Control playback from lock screen and Control Center
- **Now Playing Info**: Display current track info on lock screen

## Project Structure

```
SenkuPlayer/
├── Models/
│   ├── Song.swift              # Song model with ID3 metadata extraction
│   ├── Album.swift             # Album grouping model
│   ├── Artist.swift            # Artist grouping model
│   └── Playlist.swift          # User-created playlist model
├── Managers/
│   ├── AudioPlayerManager.swift    # AVFoundation-based audio engine
│   └── MusicLibraryManager.swift   # Library scanning and organization
├── Views/
│   ├── ContentView.swift          # Main app container
│   ├── LibraryView.swift          # Library with segmented control
│   ├── SongsListView.swift        # Songs list with selection mode
│   ├── AlbumsListView.swift       # Albums grid and detail views
│   ├── ArtistsListView.swift      # Artists list and detail views
│   ├── PlaylistsListView.swift    # Playlists management
│   ├── NowPlayingView.swift       # Full-screen player
│   ├── MiniPlayerView.swift       # Bottom mini player
│   ├── SettingsView.swift         # App settings
│   ├── DocumentPicker.swift       # Folder selection
│   └── PlaylistPickerView.swift   # Add to playlist sheet
└── SenkuPlayerApp.swift           # App entry point
```

## Setup Instructions

### 1. Project Configuration in Xcode

#### Enable Background Audio
1. Open the project in Xcode
2. Select the **SenkuPlayer** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Background Modes**
6. Check **Audio, AirPlay, and Picture in Picture**

#### Configure File Access Permissions
1. Select the **SenkuPlayer** target
2. Go to **Info** tab
3. Add the following keys:
   - **Privacy - Media Library Usage Description**: "We need access to your music library to play your songs"
   - **Supports opening documents in place**: YES
   - **Application supports iTunes file sharing**: YES

#### Configure Info.plist
Add these entries to your Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
<key>NSAppleMusicUsageDescription</key>
<string>We need access to your music library to play your songs</string>
<key>UISupportsDocumentBrowser</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UIFileSharingEnabled</key>
<true/>
```

### 2. Build and Run

1. Select your target device (iOS 17.0+)
2. Build and run the project (⌘R)

### 3. Adding Music

#### Method 1: Document Picker
1. Tap the folder icon in the navigation bar
2. Select a folder containing MP3 files
3. The app will scan and import all MP3 files

#### Method 2: iTunes File Sharing
1. Connect your device to your Mac
2. Open Finder
3. Select your device
4. Go to Files tab
5. Drag MP3 files into the SenkuPlayer folder
6. Use the folder picker in the app to scan

## Usage Guide

### Playing Music
1. **Browse Library**: Use the segmented control to switch between Playlists, Artists, Albums, and Songs
2. **Tap to Play**: Tap any song to start playback
3. **Mini Player**: Control playback from the bottom mini player
4. **Full Player**: Tap the mini player to open the full Now Playing screen

### Creating Playlists
1. Go to **Playlists** tab
2. Tap the **+** button
3. Enter a playlist name
4. Go to **Songs** tab
5. Tap **Select**
6. Select songs
7. Tap **Add to Playlist**
8. Choose your playlist

### Playback Controls
- **Play/Pause**: Tap the play/pause button
- **Next/Previous**: Use the skip buttons
- **Shuffle**: Tap the shuffle button (blue when active)
- **Repeat**: Tap the repeat button (cycles through off → all → one)
- **Seek**: Drag the progress slider

### Background Playback
- Music continues playing when:
  - App is in background
  - Device is locked
  - Switching to other apps
- Control playback from:
  - Lock screen
  - Control Center
  - AirPods/headphones

## Technical Details

### Audio Engine
- **Framework**: AVFoundation
- **Audio Session**: `.playback` category for background support
- **Remote Commands**: Full integration with MPRemoteCommandCenter
- **Now Playing Info**: MPNowPlayingInfoCenter integration

### Metadata Extraction
- **ID3 Tags**: Automatic extraction using AVAsset metadata
- **Supported Fields**:
  - Title, Artist, Album, Album Artist
  - Genre, Year, Track Number, Disc Number
  - Artwork (embedded images)

### Data Persistence
- **Storage**: UserDefaults for library and playlists
- **Format**: JSON encoding/decoding
- **File Verification**: Checks file existence on load

### Performance
- **Async Scanning**: Background thread for file scanning
- **Progress Tracking**: Real-time scan progress updates
- **Lazy Loading**: Efficient list rendering with LazyVGrid/List

## Requirements

- **iOS**: 17.0 or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Supported Audio**: MP3 files with ID3 tags

## Known Limitations

1. **Dynamic Island**: Requires iOS 16.1+ and iPhone 14 Pro or later
   - Implementation requires ActivityKit and Live Activities
   - Falls back to standard Now Playing on older devices

2. **File Access**: 
   - Requires user to grant folder access
   - Security-scoped resources need proper handling

3. **Supported Formats**: 
   - Currently only MP3 files
   - Can be extended to support AAC, FLAC, etc.

## Future Enhancements

- [ ] Dynamic Island Live Activity integration
- [ ] Equalizer controls
- [ ] Lyrics display
- [ ] iCloud sync for playlists
- [ ] CarPlay support
- [ ] Widget support
- [ ] Additional audio format support (AAC, FLAC, WAV)
- [ ] Smart playlists
- [ ] Sleep timer
- [ ] Crossfade between tracks

## Troubleshooting

### Music Not Playing in Background
1. Verify Background Modes capability is enabled
2. Check audio session configuration in SenkuPlayerApp.swift
3. Ensure device is not in Low Power Mode (may restrict background audio)

### Files Not Importing
1. Check file permissions
2. Ensure files are MP3 format
3. Verify folder access was granted
4. Check console for error messages

### Metadata Not Showing
1. Verify MP3 files have ID3 tags
2. Use a tool like Mp3tag to add/edit metadata
3. Re-scan the library after updating tags

## License

This project is for educational purposes demonstrating iOS audio playback and UI design.

## Credits

Developed by Amal
Inspired by Apple Music's beautiful design
