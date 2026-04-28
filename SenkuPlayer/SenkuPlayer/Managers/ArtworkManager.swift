//
//  ArtworkManager.swift
//  SenkuPlayer
//
//  Centralized artwork management with disk and memory caching
//

import Foundation
import SwiftUI

class ArtworkManager {
    static let shared = ArtworkManager()
    
    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, NSData>()
    
    private var artworkDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("SongArtworks")
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
    
    private init() {
        // Cache up to 100 images in memory
        cache.countLimit = 100
    }
    
    /// Save artwork data for a song ID
    func saveArtwork(_ data: Data, for id: UUID) {
        let idString = id.uuidString
        let url = artworkDirectory.appendingPathComponent("\(idString).jpg")
        
        // Save to disk
        try? data.write(to: url)
        
        // Save to memory cache
        cache.setObject(data as NSData, forKey: idString as NSString)
    }
    
    /// Get artwork data for a song ID
    func getArtwork(for id: UUID) -> Data? {
        let idString = id.uuidString
        
        // Try memory cache
        if let cached = cache.object(forKey: idString as NSString) {
            return cached as Data
        }
        
        // Try disk cache
        let url = artworkDirectory.appendingPathComponent("\(idString).jpg")
        if let data = try? Data(contentsOf: url) {
            // Re-cache to memory
            cache.setObject(data as NSData, forKey: idString as NSString)
            return data
        }
        
        return nil
    }
    
    /// Delete artwork for a song ID
    func deleteArtwork(for id: UUID) {
        let idString = id.uuidString
        let url = artworkDirectory.appendingPathComponent("\(idString).jpg")
        try? fileManager.removeItem(at: url)
        cache.removeObject(forKey: idString as NSString)
    }
    
    /// Clear all caches
    func clearAll() {
        try? fileManager.removeItem(at: artworkDirectory)
        cache.removeAllObjects()
    }
}
