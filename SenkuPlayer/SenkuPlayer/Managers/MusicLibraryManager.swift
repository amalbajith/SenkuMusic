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
        loadSavedData()
        scanMusicDirectory()
        organizeLibrary()
    }
    
    // MARK: - Scan Music Directory
    private func scanMusicDirectory() {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let musicDirectory = documentsURL.appendingPathComponent("Music", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: musicDirectory.path) {
            try? fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
            return
        }
        
        // Scan for MP3 files
        guard let files = try? fileManager.contentsOfDirectory(at: musicDirectory, includingPropertiesForKeys: nil) else { return }
        
        let mp3Files = files.filter { $0.pathExtension.lowercased() == "mp3" }
        
        for fileURL in mp3Files {
            // Add if not already in library
            if !songs.contains(where: { $0.url == fileURL }) {
                if let song = Song.fromURL(fileURL) {
                    songs.append(song)
                }
            }
        }
    }
    
    // MARK: - File Scanning
    func scanDirectory(_ url: URL) {
        isScanning = true
        scanProgress = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
                    if let song = Song.fromURL(fileURL) {
                        foundSongs.append(song)
                    }
                    
                    DispatchQueue.main.async {
                        self.scanProgress = Double(index + 1) / total
                    }
                }
            }
            
            DispatchQueue.main.async {
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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var foundSongs: [Song] = []
            let total = Double(urls.count)
            
            // Get app's Documents/Music directory
            guard let documentsURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
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
                            if let song = Song.fromURL(destinationURL) {
                                foundSongs.append(song)
                            }
                        } catch {
                            print("Failed to copy file: \(error)")
                        }
                    } else {
                        // File exists, check if already in library
                        if !self.songs.contains(where: { $0.url == destinationURL }) {
                            if let song = Song.fromURL(destinationURL) {
                                foundSongs.append(song)
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.scanProgress = Double(index + 1) / total
                }
            }
            
            DispatchQueue.main.async {
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
        organizeAlbums()
        organizeArtists()
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
        return playlist.songIDs.compactMap { songID in
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
    
    private func loadSavedData() {
        // Load song URLs and recreate Song objects
        if let data = userDefaults.data(forKey: songsKey),
           let urls = try? JSONDecoder().decode([URL].self, from: data) {
            // Recreate songs from URLs
            songs = urls.compactMap { url in
                guard fileManager.fileExists(atPath: url.path) else { return nil }
                return Song.fromURL(url)
            }
        }
        
        // Load playlists
        if let data = userDefaults.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decoded
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
