//
//  BackupManager.swift
//  SenkuPlayer
//

import Foundation
import UIKit

class BackupManager {
    static let shared = BackupManager()
    private let fm = FileManager.default
    
    private init() {}
    
    // MARK: - Export
    /// Creates a .senkubackup zip file in the temp directory and returns its URL for sharing.
    func createBackup() async throws -> URL {
        let library = MusicLibraryManager.shared
        let songs = library.songs
        let playlists = library.playlists
        
        return try await Task.detached(priority: .background) {
            let fm = FileManager.default
            // Stage area
            let stagingDir = fm.temporaryDirectory
                .appendingPathComponent("SenkuBackup_\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: stagingDir) }
            
            // 1. songs.json
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let songsData = try encoder.encode(songs)
            try songsData.write(to: stagingDir.appendingPathComponent("songs.json"))
            
            // 2. playlists.json
            let playlistsData = try encoder.encode(playlists)
            try playlistsData.write(to: stagingDir.appendingPathComponent("playlists.json"))
            
            // 3. Artwork
            let artworkDir = stagingDir.appendingPathComponent("artwork", isDirectory: true)
            try fm.createDirectory(at: artworkDir, withIntermediateDirectories: true)
            
            // 4. Audio
            let audioDir = stagingDir.appendingPathComponent("audio", isDirectory: true)
            try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
            
            for song in songs {
                // Yield occasionally to prevent starving the background pool
                await Task.yield() 
                
                // Copy Artwork
                let artworkMgr = await ArtworkManager.shared
                if let data = await artworkMgr.getArtwork(for: song.id) {
                    try? data.write(to: artworkDir.appendingPathComponent("\(song.id.uuidString).jpg"))
                }
                
                // Copy Audio File
                let audioDest = audioDir.appendingPathComponent(song.url.lastPathComponent)
                if fm.fileExists(atPath: song.url.path) && !fm.fileExists(atPath: audioDest.path) {
                    try? fm.copyItem(at: song.url, to: audioDest)
                }
            }
            
            // 5. Zip it up
            let zipURL = fm.temporaryDirectory
                .appendingPathComponent("SenkuBackup_\(Date().timeIntervalSince1970).senkubackup")
            try ZipExtractor.compress(directory: stagingDir, to: zipURL)
            return zipURL
        }.value
    }
    
    // MARK: - Restore
    func restoreBackup(from url: URL) async throws {
        try await Task.detached(priority: .background) {
            let fm = FileManager.default
            let restoreDir = fm.temporaryDirectory
                .appendingPathComponent("SenkuRestore_\(UUID().uuidString)", isDirectory: true)
            defer { try? fm.removeItem(at: restoreDir) }
            
            let files = try ZipExtractor.extract(zipURL: url, to: restoreDir)
            _ = files
            
            let decoder = JSONDecoder()
            
            // Restore songs metadata
            let songsURL = restoreDir.appendingPathComponent("songs.json")
            if let data = try? Data(contentsOf: songsURL),
               let songs = try? decoder.decode([Song].self, from: data) {
                await MainActor.run {
                    MusicLibraryManager.shared.mergeSongs(songs)
                }
            }
            
            // Restore playlists
            let playlistsURL = restoreDir.appendingPathComponent("playlists.json")
            if let data = try? Data(contentsOf: playlistsURL),
               let playlists = try? decoder.decode([Playlist].self, from: data) {
                await MainActor.run {
                    MusicLibraryManager.shared.mergePlaylists(playlists)
                }
            }
            
            // Restore artwork
            let artworkDir = restoreDir.appendingPathComponent("artwork")
            if let artFiles = try? fm.contentsOfDirectory(at: artworkDir, includingPropertiesForKeys: nil) {
                for file in artFiles {
                    await Task.yield() // Prevent CPU starvation
                    let name = file.deletingPathExtension().lastPathComponent
                    if let uid = UUID(uuidString: name),
                       let data = try? Data(contentsOf: file) {
                        let artworkMgr = await ArtworkManager.shared
                        await artworkMgr.saveArtwork(data, for: uid)
                    }
                }
            }
            
            // Restore audio
            let audioDir = restoreDir.appendingPathComponent("audio")
            if let audioFiles = try? fm.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) {
                // We need to use the actual Music directory method (since it's inside MusicLibraryManager)
                // However, we can just let `importFiles` handle it, or copy directly.
                // Since loadSavedData() fixes URLs based on getMusicDirectory(), we MUST place them there.
                let musicDir = await MainActor.run { MusicLibraryManager.shared.getMusicDirectory() }
                for file in audioFiles {
                    await Task.yield()
                    let dest = musicDir.appendingPathComponent(file.lastPathComponent)
                    if !fm.fileExists(atPath: dest.path) {
                        try? fm.copyItem(at: file, to: dest)
                    }
                }
            }
        }.value
    }

    
    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
