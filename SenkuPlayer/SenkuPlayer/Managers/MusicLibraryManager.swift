//
//  MusicLibraryManager.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation
import Combine

class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()
    
    // MARK: - Published Properties
    @Published var songs: [Song] = []
    @Published var albums: [Album] = []
    @Published var artists: [Artist] = []
    @Published var playlists: [Playlist] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let songsKey = "savedSongs"
    private let playlistsKey = "savedPlaylists"
    
    // MARK: - Initialization
    private init() {
        // Load partial data immediately for UI skeleton
        if let data = userDefaults.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = decoded
        }
        
        // Heavy lifting on background
        loadSavedData()
    }
    
// Consolidated scanning logic now handled in loadSavedData() and scanMusicDirectoryAsync()

    
    // MARK: - File Scanning
    func scanDirectory(_ url: URL) {
        isScanning = true
        scanProgress = 0
        
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            var foundSongs: [Song] = []
            
            if let enumerator = self.fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                let urls = enumerator.allObjects as? [URL] ?? []
                let mp3URLs = urls.filter { $0.pathExtension.lowercased() == "mp3" }
                let total = Double(mp3URLs.count)
                
                for (index, fileURL) in mp3URLs.enumerated() {
                    if let song = await Song.fromURL(fileURL) {
                        foundSongs.append(song)
                    }
                    
                    let progress = Double(index + 1) / total
                    await MainActor.run {
                        self.scanProgress = progress
                    }
                }
            }
            
            await MainActor.run {
                self.songs.append(contentsOf: foundSongs)
                self.organizeLibrary()
                self.saveSongs()
                self.isScanning = false
                self.scanProgress = 0
            }
        }
    }
    
    // MARK: - Import Individual Files
    func importFiles(_ urls: [URL]) {
        isScanning = true
        scanProgress = 0
        
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            var foundSongs: [Song] = []
            let total = Double(urls.count)
            
            // Get app's Documents/Music directory
            guard let documentsURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                await MainActor.run {
                    self.isScanning = false
                    self.scanProgress = 0
                }
                return
            }
            
            let musicDirectory = documentsURL.appendingPathComponent("Music", isDirectory: true)
            
            // Create Music directory if it doesn't exist
            if !self.fileManager.fileExists(atPath: musicDirectory.path) {
                try? self.fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
            }
            
            for (index, fileURL) in urls.enumerated() {
                // Only process MP3 files
                if fileURL.pathExtension.lowercased() == "mp3" {
                    // Copy file to app's Music directory
                    let fileName = fileURL.lastPathComponent
                    let destinationURL = musicDirectory.appendingPathComponent(fileName)
                    
                    // Check if file already exists
                    if !self.fileManager.fileExists(atPath: destinationURL.path) {
                        do {
                            try self.fileManager.copyItem(at: fileURL, to: destinationURL)
                            
                            // Create Song from copied file
                            if let song = await Song.fromURL(destinationURL) {
                                foundSongs.append(song)
                            }
                        } catch {
                            print("Failed to copy file: \(error)")
                        }
                    } else {
                        // File exists, check if already in library
                        let songExists = await MainActor.run {
                            self.songs.contains(where: { $0.url == destinationURL })
                        }
                        
                        if !songExists {
                            if let song = await Song.fromURL(destinationURL) {
                                foundSongs.append(song)
                            }
                        }
                    }
                }
                
                let progress = Double(index + 1) / total
                await MainActor.run {
                    self.scanProgress = progress
                }
            }
            
            await MainActor.run {
                if !foundSongs.isEmpty {
                    self.songs.append(contentsOf: foundSongs)
                    self.organizeLibrary()
                    self.saveSongs()
                }
                self.isScanning = false
                self.scanProgress = 0
            }
        }
    }
    
    func addSong(_ song: Song) {
        if !songs.contains(where: { $0.id == song.id }) {
            songs.append(song)
            organizeLibrary()
            saveSongs()
        }
    }
    
    func removeSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
        
        // Remove from playlists
        for index in playlists.indices {
            playlists[index].removeSong(song.id)
        }
        
        organizeLibrary()
        saveSongs()
        savePlaylists()
    }
    
    // MARK: - Library Organization
    private func organizeLibrary() {
        removeDuplicateSongs()
        organizeAlbums()
        organizeArtists()
    }
    
    private func removeDuplicateSongs() {
        var seenIDs = Set<UUID>()
        songs = songs.filter { (song: Song) -> Bool in
            if seenIDs.contains(song.id) {
                return false
            } else {
                seenIDs.insert(song.id)
                return true
            }
        }
    }
    
    private func organizeAlbums() {
        var albumDict: [String: Album] = [:]
        
        for song in songs {
            let key = "\(song.album)_\(song.artist)"
            
            if var album = albumDict[key] {
                album.songs.append(song)
                albumDict[key] = album
            } else {
                let album = Album(
                    name: song.album,
                    artist: song.artist,
                    songs: [song],
                    artworkData: song.artworkData
                )
                albumDict[key] = album
            }
        }
        
        albums = Array(albumDict.values).sorted { $0.name < $1.name }
        
        // Sort songs within each album by track number
        for index in albums.indices {
            albums[index].songs.sort { (song1, song2) -> Bool in
                if let track1 = song1.trackNumber, let track2 = song2.trackNumber {
                    return track1 < track2
                }
                return song1.title < song2.title
            }
        }
    }
    
    private func organizeArtists() {
        var artistDict: [String: Artist] = [:]
        
        for song in songs {
            let artistName = song.artist
            
            if var artist = artistDict[artistName] {
                artist.songs.append(song)
                artistDict[artistName] = artist
            } else {
                let artist = Artist(name: artistName, songs: [song])
                artistDict[artistName] = artist
            }
        }
        
        // Organize albums for each artist
        for (name, var artist) in artistDict {
            let artistAlbums = albums.filter { $0.artist == name }
            artist.albums = artistAlbums
            artistDict[name] = artist
        }
        
        artists = Array(artistDict.values).sorted { $0.name < $1.name }
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
    
    func getSongsForPlaylist(_ playlist: Playlist) -> [Song] {
        return playlist.songIDs.compactMap { (songID: UUID) -> Song? in
            songs.first { $0.id == songID }
        }
    }
    


    // MARK: - Persistence
    private func saveSongs() {
        // Only save URLs, not full Song objects (to avoid UserDefaults size limit)
        let urls = songs.map { $0.url }
        if let encoded = try? JSONEncoder().encode(urls) {
            userDefaults.set(encoded, forKey: songsKey)
        }
    }
    
    private func savePlaylists() {
        if let encoded = try? JSONEncoder().encode(playlists) {
            userDefaults.set(encoded, forKey: playlistsKey)
        }
    }
    
    func loadSavedData() {
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            var loadedSongs: [Song] = []
            
            // 1. Load song URLs from UserDefaults
            if let data = self.userDefaults.data(forKey: self.songsKey),
               let urls = try? JSONDecoder().decode([URL].self, from: data) {
                
                for url in urls {
                    if self.fileManager.fileExists(atPath: url.path) {
                        if let song = await Song.fromURL(url) {
                            loadedSongs.append(song)
                        }
                    }
                }
                
                await MainActor.run {
                    self.songs = loadedSongs
                    self.organizeLibrary()
                }
            }
            
            // 2. Scan Music directory for NEW files
            // Pass loadedSongs to avoid race condition with self.songs
            self.scanMusicDirectoryAsync(existingSongs: loadedSongs)
        }
    }
    
    private func scanMusicDirectoryAsync(existingSongs: [Song]? = nil) {
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let musicDirectory = documentsURL.appendingPathComponent("Music", isDirectory: true)
            
            if !fileManager.fileExists(atPath: musicDirectory.path) {
                try? fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
                return
            }
            
            guard let files = try? fileManager.contentsOfDirectory(at: musicDirectory, includingPropertiesForKeys: nil) else { return }
            let mp3Files = files.filter { $0.pathExtension.lowercased() == "mp3" }
            
            // Use provided list or current library
            let referenceSongs = existingSongs ?? (await MainActor.run { self.songs })
            
            var newSongs: [Song] = []
            for fileURL in mp3Files {
                // Use stable ID to check for duplicates
                if !referenceSongs.contains(where: { $0.url.lastPathComponent == fileURL.lastPathComponent }) {
                    if let song = await Song.fromURL(fileURL) {
                        newSongs.append(song)
                    }
                }
            }
            
            if !newSongs.isEmpty {
                await MainActor.run {
                    self.songs.append(contentsOf: newSongs)
                    self.organizeLibrary()
                    self.saveSongs()
                }
            }
        }
    }
    
    // MARK: - Search
    func searchSongs(query: String) -> [Song] {
        guard !query.isEmpty else { return songs }
        
        let lowercasedQuery = query.lowercased()
        return songs.filter {
            $0.title.lowercased().contains(lowercasedQuery) ||
            $0.artist.lowercased().contains(lowercasedQuery) ||
            $0.album.lowercased().contains(lowercasedQuery)
        }
    }
    
    func searchAlbums(query: String) -> [Album] {
        guard !query.isEmpty else { return albums }
        
        let lowercasedQuery = query.lowercased()
        return albums.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.artist.lowercased().contains(lowercasedQuery)
        }
    }
    
    func searchArtists(query: String) -> [Artist] {
        guard !query.isEmpty else { return artists }
        
        let lowercasedQuery = query.lowercased()
        return artists.filter {
            $0.name.lowercased().contains(lowercasedQuery)
        }
    }
}
