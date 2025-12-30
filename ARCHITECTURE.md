# SenkuPlayer Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         SenkuPlayerApp                          │
│                    (App Entry Point)                            │
│                                                                 │
│  • Configures AVAudioSession for background playback           │
│  • Sets up audio category: .playback                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                         ContentView                             │
│                    (Main Container)                             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    LibraryView                          │   │
│  │  • Segmented Control (Playlists/Artists/Albums/Songs)   │   │
│  │  • Search Bar                                           │   │
│  │  • Settings & Folder Picker                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  MiniPlayerView                         │   │
│  │  • Bottom overlay with playback controls                │   │
│  │  • Tap to expand to NowPlayingView                      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Data Layer (Managers)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────┐  ┌──────────────────────────┐    │
│  │  AudioPlayerManager      │  │  MusicLibraryManager     │    │
│  │  (Singleton)             │  │  (Singleton)             │    │
│  ├──────────────────────────┤  ├──────────────────────────┤    │
│  │ • AVPlayer instance      │  │ • Songs array            │    │
│  │ • Current song           │  │ • Albums array           │    │
│  │ • Playback state         │  │ • Artists array          │    │
│  │ • Queue management       │  │ • Playlists array        │    │
│  │ • Shuffle/Repeat modes   │  │ • File scanning          │    │
│  │ • Remote commands        │  │ • Metadata extraction    │    │
│  │ • Now Playing info       │  │ • Search functionality   │    │
│  │ • Interruption handling  │  │ • Persistence            │    │
│  └──────────────────────────┘  └──────────────────────────┘    │
│           │                              │                      │
│           │                              │                      │
│           ▼                              ▼                      │
│  ┌──────────────────────────┐  ┌──────────────────────────┐    │
│  │  AVFoundation            │  │  UserDefaults            │    │
│  │  • AVPlayer              │  │  • Songs persistence     │    │
│  │  • AVAudioSession        │  │  • Playlists persistence │    │
│  │  • MPRemoteCommandCenter │  │                          │    │
│  │  • MPNowPlayingInfoCenter│  │                          │    │
│  └──────────────────────────┘  └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Models (Data Structures)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   Song   │  │  Album   │  │  Artist  │  │ Playlist │       │
│  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤       │
│  │ • id     │  │ • id     │  │ • id     │  │ • id     │       │
│  │ • url    │  │ • name   │  │ • name   │  │ • name   │       │
│  │ • title  │  │ • artist │  │ • albums │  │ • songIDs│       │
│  │ • artist │  │ • songs  │  │ • songs  │  │ • dates  │       │
│  │ • album  │  │ • artwork│  │          │  │          │       │
│  │ • artwork│  │          │  │          │  │          │       │
│  │ • metadata│ │          │  │          │  │          │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Views (UI Components)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Library Views              Detail Views         Utility Views  │
│  ┌──────────────────┐      ┌──────────────┐    ┌─────────────┐ │
│  │ SongsListView    │      │ AlbumDetail  │    │ Settings    │ │
│  │ AlbumsListView   │      │ ArtistDetail │    │ DocPicker   │ │
│  │ ArtistsListView  │      │ PlaylistDet. │    │ PlaylistPick│ │
│  │ PlaylistsListView│      │              │    │             │ │
│  └──────────────────┘      └──────────────┘    └─────────────┘ │
│                                                                 │
│  Player Views                                                   │
│  ┌──────────────────┐      ┌──────────────┐                    │
│  │ NowPlayingView   │      │ MiniPlayer   │                    │
│  │ • Full screen    │      │ • Bottom bar │                    │
│  │ • Album art      │      │ • Quick ctrl │                    │
│  │ • Controls       │      │ • Progress   │                    │
│  │ • Progress       │      │              │                    │
│  └──────────────────┘      └──────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
User Interaction Flow:
─────────────────────

1. ADD MUSIC
   User taps folder icon
         │
         ▼
   DocumentPicker shows
         │
         ▼
   User selects folder
         │
         ▼
   MusicLibraryManager.scanDirectory()
         │
         ├─→ Finds MP3 files
         ├─→ Extracts metadata (Song.fromURL)
         ├─→ Creates Song objects
         ├─→ Organizes into Albums/Artists
         └─→ Saves to UserDefaults
         │
         ▼
   UI updates with new songs

2. PLAY MUSIC
   User taps song in list
         │
         ▼
   AudioPlayerManager.playSong()
         │
         ├─→ Creates AVPlayer with song URL
         ├─→ Sets up time observer
         ├─→ Updates Now Playing info
         ├─→ Configures remote commands
         └─→ Starts playback
         │
         ▼
   UI updates (mini player shows, playing indicator)

3. BACKGROUND PLAYBACK
   User locks device or switches apps
         │
         ▼
   AVAudioSession keeps audio active
         │
         ├─→ Lock screen shows Now Playing
         ├─→ Control Center shows controls
         └─→ Remote commands remain active
         │
         ▼
   Music continues playing

4. CREATE PLAYLIST
   User creates playlist
         │
         ▼
   MusicLibraryManager.createPlaylist()
         │
         ├─→ Creates Playlist object
         ├─→ Adds to playlists array
         └─→ Saves to UserDefaults
         │
         ▼
   User selects songs
         │
         ▼
   MusicLibraryManager.addSongsToPlaylist()
         │
         ├─→ Updates playlist.songIDs
         └─→ Saves to UserDefaults
         │
         ▼
   UI updates with new playlist
```

## State Management

```
ObservableObject Pattern:
────────────────────────

┌─────────────────────────────────────────┐
│      AudioPlayerManager                 │
│      @Published properties:             │
│                                         │
│  • currentSong: Song?                   │
│  • isPlaying: Bool                      │
│  • currentTime: TimeInterval            │
│  • duration: TimeInterval               │
│  • queue: [Song]                        │
│  • repeatMode: RepeatMode               │
│  • isShuffled: Bool                     │
└─────────────────────────────────────────┘
              │
              │ @StateObject
              ▼
┌─────────────────────────────────────────┐
│         All Views Subscribe             │
│                                         │
│  • ContentView                          │
│  • MiniPlayerView                       │
│  • NowPlayingView                       │
│  • SongsListView                        │
│  • etc.                                 │
│                                         │
│  → UI automatically updates when        │
│    @Published properties change         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      MusicLibraryManager                │
│      @Published properties:             │
│                                         │
│  • songs: [Song]                        │
│  • albums: [Album]                      │
│  • artists: [Artist]                    │
│  • playlists: [Playlist]                │
│  • isScanning: Bool                     │
│  • scanProgress: Double                 │
└─────────────────────────────────────────┘
              │
              │ @StateObject
              ▼
┌─────────────────────────────────────────┐
│         All Views Subscribe             │
│                                         │
│  • LibraryView                          │
│  • SongsListView                        │
│  • AlbumsListView                       │
│  • ArtistsListView                      │
│  • PlaylistsListView                    │
│  • etc.                                 │
│                                         │
│  → UI automatically updates when        │
│    library changes                      │
└─────────────────────────────────────────┘
```

## Thread Safety

```
Main Thread (UI):
────────────────
• All UI updates
• @Published property changes
• View rendering
• User interactions

Background Thread:
─────────────────
• File scanning (scanDirectory)
• Metadata extraction
• File I/O operations

Synchronization:
───────────────
DispatchQueue.main.async {
    // Update @Published properties
    // Triggers UI updates on main thread
}
```

## Persistence Strategy

```
UserDefaults Storage:
────────────────────

┌──────────────────────────────────────┐
│  Key: "savedSongs"                   │
│  Value: JSON encoded [Song]          │
│                                      │
│  • Saved on: song add/remove         │
│  • Loaded on: app launch             │
│  • Verified: file existence check    │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  Key: "savedPlaylists"               │
│  Value: JSON encoded [Playlist]      │
│                                      │
│  • Saved on: playlist CRUD ops       │
│  • Loaded on: app launch             │
│  • References: Song IDs (UUID)       │
└──────────────────────────────────────┘

Note: Song files remain in original location
      Only metadata is stored in UserDefaults
```

## Background Audio Architecture

```
Audio Session Configuration:
──────────────────────────

AVAudioSession.sharedInstance()
    │
    ├─→ Category: .playback
    ├─→ Mode: .default
    └─→ Active: true
    
    Enables:
    • Background playback
    • Lock screen playback
    • AirPlay support
    • Bluetooth audio

Remote Command Center:
────────────────────

MPRemoteCommandCenter.shared()
    │
    ├─→ playCommand → AudioPlayerManager.play()
    ├─→ pauseCommand → AudioPlayerManager.pause()
    ├─→ nextTrackCommand → AudioPlayerManager.playNext()
    ├─→ previousTrackCommand → AudioPlayerManager.playPrevious()
    └─→ changePlaybackPositionCommand → AudioPlayerManager.seek()

Now Playing Info Center:
───────────────────────

MPNowPlayingInfoCenter.default()
    │
    └─→ nowPlayingInfo = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyArtwork: artwork,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
```

## File Structure

```
SenkuPlayer/
├── SenkuPlayerApp.swift          # App entry, audio session setup
├── ContentView.swift              # Main container
│
├── Models/
│   ├── Song.swift                # Song + metadata extraction
│   ├── Album.swift               # Album grouping
│   ├── Artist.swift              # Artist grouping
│   └── Playlist.swift            # User playlists
│
├── Managers/
│   ├── AudioPlayerManager.swift  # Playback engine
│   └── MusicLibraryManager.swift # Library management
│
├── Views/
│   ├── LibraryView.swift         # Main library UI
│   ├── SongsListView.swift       # Songs list
│   ├── AlbumsListView.swift      # Albums grid + detail
│   ├── ArtistsListView.swift     # Artists list + detail
│   ├── PlaylistsListView.swift   # Playlists + detail
│   ├── NowPlayingView.swift      # Full-screen player
│   ├── MiniPlayerView.swift      # Bottom mini player
│   ├── SettingsView.swift        # Settings
│   ├── DocumentPicker.swift      # Folder picker
│   └── PlaylistPickerView.swift  # Add to playlist
│
└── DynamicIsland/
    └── NowPlayingActivity.swift  # Live Activity (optional)
```

This architecture provides:
✅ Clean separation of concerns
✅ Reactive UI updates
✅ Efficient state management
✅ Thread-safe operations
✅ Robust background playback
✅ Scalable design
