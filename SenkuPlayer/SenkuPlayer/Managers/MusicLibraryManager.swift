//
//  MusicLibraryManager.swift
//  SenkuPlayer
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
        if let data = userDefaults.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = decoded
        }
        loadSavedData()
    }
    
    // MARK: - Import & Scanning
    func importFiles(_ urls: [URL]) {
        isScanning = true
        scanProgress = 0
        
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            var foundSongs: [Song] = []
            let musicDir = self.getMusicDirectory()
            let total = Double(urls.count)
            
            for (index, url) in urls.enumerated() {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                
                if url.pathExtension.lowercased() == "mp3" {
                    let dest = musicDir.appendingPathComponent(url.lastPathComponent)
                    if !self.fileManager.fileExists(atPath: dest.path) {
                        try? self.fileManager.copyItem(at: url, to: dest)
                    }
                    
                    if let (song, artwork) = await Song.fromURL(dest) {
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
                    if !self.songs.contains(where: { $0.id == newSong.id }) {
                        self.songs.append(newSong)
                    }
                }
                self.organizeLibrary()
                self.saveSongs()
                self.isScanning = false
                self.scanProgress = 0
            }
            
            // Automatically fetch metadata for songs without artwork
            await self.autoFetchMetadata(for: foundSongs)
        }
    }
    
    // Helper to add song from a known URL (e.g. from Sync or Download)
    func addSongFromURL(_ url: URL) async {
        if let (song, artwork) = await Song.fromURL(url) {
            await MainActor.run {
                if let artwork = artwork {
                    ArtworkManager.shared.saveArtwork(artwork, for: song.id)
                }
                
                if !self.songs.contains(where: { $0.id == song.id }) {
                    self.songs.append(song)
                    self.organizeLibrary()
                    self.saveSongs()
                }
            }
            // Auto fetch metadata if needed
            if !song.hasArtwork {
                await self.autoFetchMetadata(for: [song])
            }
        }
    }
    
    // MARK: - Auto Metadata Fetching
    private func autoFetchMetadata(for songs: [Song]) async {
        // Only fetch for songs missing artwork
        let songsNeedingArtwork = songs.filter { !$0.hasArtwork }
        
        guard !songsNeedingArtwork.isEmpty else { return }
        
        print("🎨 Auto-fetching metadata for \(songsNeedingArtwork.count) songs...")
        
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
                print("✅ Auto-fetched metadata for \(updateCount) songs")
            }
        }
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
        // Use dictionary for faster lookup during organization
        var albumDict: [String: Album] = [:]
        var artistDict: [String: Artist] = [:]
        
        for song in songs {
            // Album organization
            let albumKey = "\(song.album)_\(song.artist)"
            if albumDict[albumKey] == nil {
                albumDict[albumKey] = Album(name: song.album, artist: song.artist, songs: [], artworkData: nil)
            }
            albumDict[albumKey]?.songs.append(song)
            
            // Artist organization
            if artistDict[song.artist] == nil {
                artistDict[song.artist] = Artist(name: song.artist, songs: [])
            }
            artistDict[song.artist]?.songs.append(song)
        }
        
        self.albums = Array(albumDict.values).sorted { $0.name < $1.name }
        self.artists = Array(artistDict.values).sorted { $0.name < $1.name }
        
        // Link albums to artists
        for i in artists.indices {
            let name = artists[i].name
            artists[i].albums = albums.filter { $0.artist == name }
        }
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
    
    func loadSavedData() {
        Task(priority: .userInitiated) {
            guard let url = songsFileURL, let data = try? Data(contentsOf: url) else { return }
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
                }
            }
        }
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
    func createPlaylist(name: String, songIDs: [UUID] = []) {
        let playlist = Playlist(name: name, songIDs: songIDs)
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
}

