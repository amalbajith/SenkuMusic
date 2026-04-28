//
//  MusicLibraryManager.swift
//  SenkuPlayer
//
//

import Foundation
import Combine

class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()
    
    @Published var songs: [Song] = []
    @Published var albums: [Album] = []
    @Published var artists: [Artist] = []
    @Published var playlists: [Playlist] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let songsKey = "savedSongs"
    private let playlistsKey = "savedPlaylists"
    
    private var songsFileURL: URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDirectory.appendingPathComponent("library_v2.json")
    }
    
    private init() {
        loadSavedData()
    }
    
    // MARK: - Import & Scanning
    
    private static let allowedAudioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "aiff"]
    
    func importFiles(_ urls: [URL]) {
        isScanning = true
        scanProgress = 0
        
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            // Collect audio files
            var audioURLs: [URL] = []
            
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if Self.allowedAudioExtensions.contains(ext) {
                    audioURLs.append(url)
                }
            }

            
            // Now import all collected audio files
            var foundSongs: [Song] = []
            let musicDir = self.getMusicDirectory()
            let total = Double(max(audioURLs.count, 1))
            
            for (index, url) in audioURLs.enumerated() {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                
                if Self.allowedAudioExtensions.contains(url.pathExtension.lowercased()) {
                    // Safe Copy with Rename to prevent overwrite
                    var finalURL = musicDir.appendingPathComponent(url.lastPathComponent)
                    if self.fileManager.fileExists(atPath: finalURL.path) {
                        let name = url.deletingPathExtension().lastPathComponent
                        let ext = url.pathExtension
                        var counter = 1
                        while self.fileManager.fileExists(atPath: finalURL.path) {
                             finalURL = musicDir.appendingPathComponent("\(name) \(counter).\(ext)")
                             counter += 1
                        }
                    }
                    
                    try? self.fileManager.copyItem(at: url, to: finalURL)
                    
                    if let (song, artwork) = await Song.fromURL(finalURL) {
                        if let artwork = artwork {
                            ArtworkManager.shared.saveArtwork(artwork, for: song.id)
                        }
                        foundSongs.append(song)
                    }
                }
                
                let progress = Double(index + 1) / total
                await MainActor.run { self.scanProgress = progress }
            }
            
            await MainActor.run {
                for newSong in foundSongs {
                    // Deduplicate by Metadata (Title + Artist + Album)
                    let isDuplicate = self.songs.contains {
                        $0.title == newSong.title &&
                        $0.artist == newSong.artist &&
                        $0.album == newSong.album
                    }
                    
                    if !isDuplicate {
                        self.songs.append(newSong)
                    } else {
                        // Cleanup orphan file
                        try? self.fileManager.removeItem(at: newSong.url)
                    }
                }
                self.organizeLibrary()
                self.saveSongs()
                self.isScanning = false
                self.scanProgress = 0
            }
            
            // Pre-process artwork thumbnails — runs once per song, skips if already on disk.
            // After this, every list scroll is an instant disk/memory read with zero CPU decode.
            Task.detached(priority: .background) {
                await ArtworkCacheManager.shared.preprocessArtwork(for: foundSongs)
            }

            // Automatically fetch metadata for songs without artwork
            await self.autoFetchMetadata(for: foundSongs)
            
            // Automatically analyze audio energy
            await self.autoFetchEnergy(for: foundSongs)
            
            // Automatically fetch lyrics in the background
            Task.detached(priority: .background) {
                await self.autoFetchLyrics(for: foundSongs)
            }
            
            // Automatically sync Spotify playlists after import
            await self.syncSpotifyPlaylists()
        }
    }
    

    // Helper to add song from a known URL (e.g. from Sync or Download)
    func addSongFromURL(_ url: URL) async {
        if let (song, artwork) = await Song.fromURL(url) {
            await MainActor.run {
                if let artwork = artwork {
                    ArtworkManager.shared.saveArtwork(artwork, for: song.id)
                }
                
                // Deduplicate by Metadata
                let isDuplicate = self.songs.contains {
                    $0.title == song.title &&
                    $0.artist == song.artist &&
                    $0.album == song.album
                }
                
                if !isDuplicate {
                    self.songs.append(song)
                    self.organizeLibrary()
                    self.saveSongs()
                } else {
                    // If Sync confused and sent duplicate file (not overwrite), clean it up
                    // But be careful: If Sync Overwrote `file.mp3`, and we have entry for `file.mp3`.
                    // We keep entry. Use file.
                    // If Sync sent `file 1.mp3` (duplicate content), we delete `file 1.mp3`.
                    if !self.songs.contains(where: { $0.url == song.url }) {
                         try? self.fileManager.removeItem(at: song.url)
                    }
                }
            }
            // Auto fetch metadata if needed
            if !song.hasArtwork {
                await self.autoFetchMetadata(for: [song])
            }
            if song.energy == nil {
                await self.autoFetchEnergy(for: [song])
            }
            if song.syncedLyrics == nil && song.plainLyrics == nil {
                Task.detached(priority: .background) {
                    await self.autoFetchLyrics(for: [song])
                }
            }
            
            // Trigger sync
            await self.syncSpotifyPlaylists()
        }
    }

    // Batch variant used by sync to avoid repeated save/organize cycles.
    func addSongsFromURLs(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }

        var parsedSongs: [(song: Song, artwork: Data?)] = []
        parsedSongs.reserveCapacity(urls.count)
        for url in urls {
            // VULN-02: enforce the same audio extension allowlist used by importFiles
            guard Self.allowedAudioExtensions.contains(url.pathExtension.lowercased()) else {
                try? FileManager.default.removeItem(at: url) // clean up non-audio file written by sync
                continue
            }
            if let parsed = await Song.fromURL(url) {
                parsedSongs.append((parsed.0, parsed.1))
            }
        }

        await MainActor.run {
            var importedNeedingMetadata: [Song] = []

            for (song, artwork) in parsedSongs {
                if let artwork = artwork {
                    ArtworkManager.shared.saveArtwork(artwork, for: song.id)
                }

                let isDuplicate = self.songs.contains {
                    $0.title == song.title &&
                    $0.artist == song.artist &&
                    $0.album == song.album
                }

                if !isDuplicate {
                    self.songs.append(song)
                    importedNeedingMetadata.append(song)
                } else if !self.songs.contains(where: { $0.url == song.url }) {
                    try? self.fileManager.removeItem(at: song.url)
                }
            }

            self.organizeLibrary()
            self.saveSongs()

            Task {
                await self.autoFetchMetadata(for: importedNeedingMetadata)
                await self.autoFetchEnergy(for: importedNeedingMetadata)
                Task.detached(priority: .background) {
                    await self.autoFetchLyrics(for: importedNeedingMetadata)
                }
                
                // Trigger sync after batch import
                await self.syncSpotifyPlaylists()
            }
        }
    }
    
    // MARK: - Auto Metadata Fetching
    private func autoFetchMetadata(for songs: [Song]) async {
        // Only fetch for songs missing artwork
        let songsNeedingArtwork = songs.filter { !$0.hasArtwork }
        
        guard !songsNeedingArtwork.isEmpty else { return }
        
        #if DEBUG
        print("🎨 Auto-fetching metadata for \(songsNeedingArtwork.count) songs...")
        #endif
        
        let results = await MetadataFetcher.shared.fetchMetadataForSongs(songsNeedingArtwork)
        
        await MainActor.run {
            var updateCount = 0
            
            for result in results {
                // Save artwork
                if let artwork = result.artwork {
                    ArtworkManager.shared.saveArtwork(artwork, for: result.songId)
                    updateCount += 1
                }
                
                // Update song metadata
                if let index = self.songs.firstIndex(where: { $0.id == result.songId }) {
                    var updatedSong = self.songs[index]
                    
                    if let metadata = result.metadata {
                        updatedSong.title = metadata.title
                        updatedSong.artist = metadata.artist
                        updatedSong.album = metadata.album
                        updatedSong.year = metadata.year
                        updatedSong.genre = metadata.genre
                    }
                    
                    if result.artwork != nil {
                        updatedSong.hasArtwork = true
                    }
                    
                    self.songs[index] = updatedSong
                }
            }
            
            if updateCount > 0 {
                self.saveSongs()
                self.organizeLibrary()
                self.objectWillChange.send()
                #if DEBUG
                print("✅ Auto-fetched metadata for \(updateCount) songs")
                #endif
            }
        }
    }
    
    // MARK: - Auto Energy Fetching
    private func autoFetchEnergy(for songs: [Song]) async {
        let songsNeedingEnergy = songs.filter { $0.energy == nil }
        guard !songsNeedingEnergy.isEmpty else { return }
        
        #if DEBUG
        print("⚡️ Auto-analyzing energy for \(songsNeedingEnergy.count) songs...")
        #endif
        
        var updateCount = 0
        for song in songsNeedingEnergy {
            if let energy = await AudioAnalyzer.shared.analyzeEnergy(for: song.url) {
                await MainActor.run {
                    if let index = self.songs.firstIndex(where: { $0.id == song.id }) {
                        self.songs[index].energy = energy
                        updateCount += 1
                    }
                }
            }
        }
        
        if updateCount > 0 {
            await MainActor.run {
                self.saveSongs()
                self.generateSmartPlaylists()
                #if DEBUG
                print("✅ Analyzed energy for \(updateCount) songs")
                #endif
            }
        }
    }
    
    // MARK: - Smart Playlists
    func generateSmartPlaylists() {
        let highEnergySongs = songs.filter { ($0.energy ?? 0) >= 0.4 }.map { $0.id }
        let chillSongs = songs.filter { ($0.energy ?? 1.0) <= 0.35 }.map { $0.id }
        
        updateOrCreateSmartPlaylist(name: "High Energy Mix ⚡️", songIDs: highEnergySongs)
        updateOrCreateSmartPlaylist(name: "Chill Vibes 🧘‍♂️", songIDs: chillSongs)
    }
    
    private func updateOrCreateSmartPlaylist(name: String, songIDs: [UUID]) {
        guard !songIDs.isEmpty else { return }
        
        if let index = playlists.firstIndex(where: { $0.name == name }) {
            playlists[index].songIDs = songIDs
            playlists[index].modifiedDate = Date()
        } else {
            let playlist = Playlist(name: name, songIDs: songIDs)
            playlists.append(playlist)
        }
        savePlaylists()
    }
    
    // MARK: - Lyrics
    func fetchLyricsIfNeeded(for song: Song) async {
        guard song.syncedLyrics == nil && song.plainLyrics == nil else { return }
        
        do {
            if let response = try await LyricsFetcher.shared.fetchLyrics(for: song) {
                await MainActor.run {
                    if let index = self.songs.firstIndex(where: { $0.id == song.id }) {
                        self.songs[index].plainLyrics = response.plainLyrics
                        self.songs[index].syncedLyrics = response.syncedLyrics
                        self.saveSongs()
                        
                        // Keep current playing song in sync if it's the one we just fetched
                        if AudioPlayerManager.shared.currentSong?.id == song.id {
                            AudioPlayerManager.shared.currentSong?.plainLyrics = response.plainLyrics
                            AudioPlayerManager.shared.currentSong?.syncedLyrics = response.syncedLyrics
                        }
                    }
                }
            }
        } catch {
            print("Failed to fetch lyrics: \(error)")
        }
    }
    
    // MARK: - Batch Lyrics Auto-Fetcher
    /// Fetches lyrics for a batch of songs with a concurrency cap so we don't
    /// hammer LRCLIB with 100+ simultaneous requests. Saves every 10 songs.
    func autoFetchLyrics(for songs: [Song]) async {
        let songsNeedingLyrics = songs.filter { $0.syncedLyrics == nil && $0.plainLyrics == nil }
        guard !songsNeedingLyrics.isEmpty else { return }
        
        #if DEBUG
        print("🎵 Starting lyrics fetch for \(songsNeedingLyrics.count) songs")
        #endif
        
        // Max 3 concurrent requests to be respectful to LRCLIB
        var saveCounter = 0
        var songIterator = songsNeedingLyrics.makeIterator()
        let maxConcurrency = 3
        
        await withTaskGroup(of: (UUID, String?, String?).self) { group in
            var activeCount = 0
            
            // Seed initial concurrent slots
            while activeCount < maxConcurrency, let song = songIterator.next() {
                let songCopy = song
                group.addTask(priority: .background) {
                    do {
                        if let response = try await LyricsFetcher.shared.fetchLyrics(for: songCopy) {
                            return (songCopy.id, response.plainLyrics, response.syncedLyrics)
                        }
                    } catch { /* silently skip on network error */ }
                    return (songCopy.id, nil, nil)
                }
                activeCount += 1
            }
            
            // As tasks complete, save result and enqueue next
            for await (songID, plain, synced) in group {
                if plain != nil || synced != nil {
                    await MainActor.run {
                        if let index = self.songs.firstIndex(where: { $0.id == songID }) {
                            self.songs[index].plainLyrics = plain
                            self.songs[index].syncedLyrics = synced
                        }
                        if AudioPlayerManager.shared.currentSong?.id == songID {
                            AudioPlayerManager.shared.currentSong?.plainLyrics = plain
                            AudioPlayerManager.shared.currentSong?.syncedLyrics = synced
                        }
                    }
                    saveCounter += 1
                    // Batch-save every 10 songs to reduce disk write pressure
                    if saveCounter % 10 == 0 {
                        await MainActor.run { self.saveSongs() }
                    }
                }
                
                // 300ms throttle between requests to be polite to the API
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                // Enqueue next song if available
                if let next = songIterator.next() {
                    let nextCopy = next
                    group.addTask(priority: .background) {
                        do {
                            if let response = try await LyricsFetcher.shared.fetchLyrics(for: nextCopy) {
                                return (nextCopy.id, response.plainLyrics, response.syncedLyrics)
                            }
                        } catch { /* silently skip */ }
                        return (nextCopy.id, nil, nil)
                    }
                }
            }
        }
        
        // Final save for any remaining unsaved results
        await MainActor.run { self.saveSongs() }
        
        #if DEBUG
        print("✅ Lyrics fetch complete for \(songsNeedingLyrics.count) songs")
        #endif
    }
    
    func getMusicDirectory() -> URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let music = docs.appendingPathComponent("Music", isDirectory: true)
        if !fileManager.fileExists(atPath: music.path) {
            try? fileManager.createDirectory(at: music, withIntermediateDirectories: true)
        }
        return music
    }
    
    func removeSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
        ArtworkManager.shared.deleteArtwork(for: song.id)
        organizeLibrary()
        saveSongs()
        
        // Cleanup file if it was in our Music dir
        if song.url.path.contains("/Documents/Music/") {
            try? fileManager.removeItem(at: song.url)
        }
    }
    
    func deleteAllSongs() {
        // Clear memory
        songs.removeAll()
        albums.removeAll()
        artists.removeAll()
        
        // Clear artwork cache
        ArtworkManager.shared.clearAll()
        
        // Delete saved library
        if let url = songsFileURL {
            try? fileManager.removeItem(at: url)
        }
        
        // Delete physical files
        let musicDir = getMusicDirectory()
        if let files = try? fileManager.contentsOfDirectory(at: musicDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Library Organization (Optimized)
    func organizeLibrary() {
        // CRITICAL: Ensure all songs in the library have unique IDs to prevent ForEach crashes
        var seenIDs = Set<UUID>()
        self.songs = self.songs.filter { song in
            if seenIDs.contains(song.id) {
                #if DEBUG
                print("⚠️ MusicLibraryManager: Removing duplicate song ID from library: \(song.id)")
                #endif
                return false
            } else {
                seenIDs.insert(song.id)
                return true
            }
        }

        // Use dictionary for faster O(N) grouping instead of O(N^2)
        var albumDict: [String: Album] = [:]
        var artistDict: [String: Artist] = [:]
        
        for song in songs {
            // Album organization
            let effectiveAlbum = song.album.isEmpty || song.album == "Unknown Album" ? "Unknown Album" : song.album
            let albumArtist = song.artist
            let albumKey = "\(effectiveAlbum)_\(albumArtist)"
            
            if var album = albumDict[albumKey] {
                album.songs.append(song)
                albumDict[albumKey] = album
            } else {
                albumDict[albumKey] = Album(name: effectiveAlbum, artist: albumArtist, songs: [song])
            }
            
            // Artist organization
            if var artist = artistDict[song.artist] {
                artist.songs.append(song)
                artistDict[song.artist] = artist
            } else {
                artistDict[song.artist] = Artist(name: song.artist, songs: [song])
            }
        }
        
        let sortedAlbums = Array(albumDict.values).sorted { $0.name < $1.name }
        let sortedArtists = Array(artistDict.values).sorted { $0.name < $1.name }
        
        // Link albums to artists via O(N) pass instead of O(N^2) filter
        var artistAlbums: [String: [Album]] = [:]
        for album in sortedAlbums {
            artistAlbums[album.artist, default: []].append(album)
        }
        
        var finalArtists: [Artist] = []
        for var artist in sortedArtists {
            artist.albums = artistAlbums[artist.name] ?? []
            finalArtists.append(artist)
        }
        
        self.albums = sortedAlbums
        self.artists = finalArtists
    }
    
    // MARK: - Persistence
    func saveSongs() {
        guard let url = songsFileURL else { return }
        if let data = try? JSONEncoder().encode(songs) {
            try? data.write(to: url)
        }
    }
    
    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            userDefaults.set(data, forKey: playlistsKey)
        }
    }
    
    // MARK: - Backup Merge
    @MainActor
    func mergeSongs(_ imported: [Song]) {
        for song in imported {
            let isDuplicate = songs.contains {
                $0.title == song.title && $0.artist == song.artist && $0.album == song.album
            }
            if !isDuplicate { songs.append(song) }
        }
        organizeLibrary()
        saveSongs()
    }
    
    @MainActor
    func mergePlaylists(_ imported: [Playlist]) {
        for playlist in imported {
            if !playlists.contains(where: { $0.name == playlist.name }) {
                playlists.append(playlist)
            }
        }
        savePlaylists()
    }
    
    func loadSavedData() {
        Task(priority: .userInitiated) {
            // Load Playlists
            if let plistData = self.userDefaults.data(forKey: self.playlistsKey),
               let decodedPlaylists = try? JSONDecoder().decode([Playlist].self, from: plistData) {
                await MainActor.run {
                    self.playlists = decodedPlaylists
                }
            }
            
            // Load Songs
            guard let url = self.songsFileURL, let data = try? Data(contentsOf: url) else { return }
            if var decoded = try? JSONDecoder().decode([Song].self, from: data) {
                
                // Repair URLs for Sandbox Changes
                let musicDir = self.getMusicDirectory()
                for i in decoded.indices {
                    let filename = decoded[i].url.lastPathComponent
                    // Always point to current sandbox Music directory
                    decoded[i].url = musicDir.appendingPathComponent(filename)
                }
                
                await MainActor.run {
                    self.songs = decoded
                    self.organizeLibrary()
                    self.generateSmartPlaylists()
                }
                
                // Start a silent background sweep for missing metadata/lyrics/energy
                // for the entire library to catch any items that were missed previously.
                Task.detached(priority: .background) {
                    await self.performMaintenanceSweep()
                }
                
                // Trigger Spotify Sync
                await self.syncSpotifyPlaylists()
            }
        }
    }

    private func performMaintenanceSweep() async {
        let allSongs = await MainActor.run { self.songs }

        // 0. Pre-process artwork thumbnails for any song not yet on disk.
        //    Skips songs already cached — effectively a no-op after first run.
        await MainActor.run { ArtworkCacheManager.shared.preprocessArtwork(for: allSongs) }

        // 1. Fetch missing artwork/metadata
        await autoFetchMetadata(for: allSongs)
        
        // 2. Fetch missing lyrics
        await autoFetchLyrics(for: allSongs)
        
        // 3. Analyze missing audio energy
        await autoFetchEnergy(for: allSongs)
    }
    
    // MARK: - Helper Methods
    func recordPlay(for song: Song) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            var updatedSong = songs[index]
            updatedSong.lastPlayedDate = Date()
            updatedSong.playCount += 1
            songs[index] = updatedSong
            saveSongs()
        }
    }
    
    func getRecentlyPlayed(limit: Int = 50) -> [Song] {
        return songs
            .filter { $0.lastPlayedDate != nil }
            .sorted { ($0.lastPlayedDate ?? Date.distantPast) > ($1.lastPlayedDate ?? Date.distantPast) }
            .prefix(limit)
            .map { $0 }
    }
    
    func getSongsForPlaylist(_ playlist: Playlist) -> [Song] {
        return playlist.songIDs.compactMap { id in songs.first { $0.id == id } }
    }
    
    func searchSongs(query: String) -> [Song] {
        guard !query.isEmpty else { return songs }
        let q = query.lowercased()
        return songs.filter { $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q) }
    }
    
    func searchAlbums(query: String) -> [Album] {
        let q = query.lowercased()
        return albums.filter { $0.name.lowercased().contains(q) || $0.artist.lowercased().contains(q) }
    }
    
    func searchArtists(query: String) -> [Artist] {
        let q = query.lowercased()
        return artists.filter { $0.name.lowercased().contains(q) }
    }
    
    // MARK: - Playlist Management
    func createPlaylist(name: String, songIDs: [UUID] = [], spotifyPlaylistID: String? = nil) {
        let playlist = Playlist(name: name, songIDs: songIDs, spotifyPlaylistID: spotifyPlaylistID)
        playlists.append(playlist)
        savePlaylists()
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    func updatePlaylist(_ playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = playlist
            savePlaylists()
        }
    }
    
    func addSongsToPlaylist(_ songIDs: [UUID], playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            for songID in songIDs {
                playlists[index].addSong(songID)
            }
            savePlaylists()
        }
    }
    
    /// Synchronizes all Spotify-linked playlists with the current library.
    /// This will automatically add any newly matched songs from the library to the playlists.
    func syncSpotifyPlaylists() async {
        let playlistsToSync = playlists.filter { $0.spotifyPlaylistID != nil }
        guard !playlistsToSync.isEmpty else { return }
        
        #if DEBUG
        print("🔄 Syncing \(playlistsToSync.count) Spotify playlists...")
        #endif
        
        for playlist in playlistsToSync {
            guard let spotifyID = playlist.spotifyPlaylistID else { continue }
            
            do {
                // Fetch current tracks from Spotify
                let info = try await SpotifyImportService.shared.fetchPlaylistInfo(playlistID: spotifyID)
                
                // Match with current library
                let matchedIDs = SpotifyImportService.shared.matchTracksWithLibrary(spotifyTracks: info.tracks, librarySongs: self.songs)
                
                // Add missing songs
                await MainActor.run {
                    self.addSongsToPlaylist(matchedIDs, playlist: playlist)
                }
            } catch {
                print("⚠️ MusicLibraryManager: Failed to sync playlist \(playlist.name): \(error)")
            }
        }
    }
}
