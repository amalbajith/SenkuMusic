//
//  Song.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation
import AVFoundation

struct Song: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    var title: String
    var artist: String
    var album: String
    var albumArtist: String?
    var duration: TimeInterval
    var artworkData: Data?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    
    init(id: UUID = UUID(), url: URL, title: String, artist: String, album: String, albumArtist: String? = nil, duration: TimeInterval, artworkData: Data? = nil, genre: String? = nil, year: Int? = nil, trackNumber: Int? = nil, discNumber: Int? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.duration = duration
        self.artworkData = artworkData
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Metadata Extraction
extension Song {
    static func fromURL(_ url: URL) async -> Song? {
        let asset = AVAsset(url: url)

        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var albumArtist: String?
        var duration: TimeInterval = 0
        var artworkData: Data?
        var genre: String?
        var year: Int?
        var trackNumber: Int?
        var discNumber: Int?

        // Load duration asynchronously to avoid blocking lower QoS threads
        do {
            let time = try await asset.load(.duration)
            duration = time.seconds
        } catch {
            // Keep default duration = 0
        }

        // Load common metadata asynchronously
        let commonMetadata: [AVMetadataItem]
        do {
            commonMetadata = try await asset.load(.commonMetadata)
        } catch {
            commonMetadata = []
        }

        for item in commonMetadata {
            guard let key = item.commonKey?.rawValue else { continue }
            switch key {
            case "title":
                if let titleValue = item.stringValue { title = titleValue }
            case "artist":
                if let artistValue = item.stringValue { artist = artistValue }
            case "albumName":
                if let albumValue = item.stringValue { album = albumValue }
            case "type":
                if let genreValue = item.stringValue { genre = genreValue }
            case "artwork":
                if let data = item.dataValue { artworkData = data }
            default:
                break
            }
        }

        // Load available metadata formats asynchronously (iOS 16+ API)
        let formats: [AVMetadataFormat]
        do {
            formats = try await asset.load(.availableMetadataFormats)
        } catch {
            formats = []
        }

        // For each format, load its metadata asynchronously and parse additional tags
        for format in formats {
            let formatMetadata: [AVMetadataItem]
            do {
                formatMetadata = try await asset.loadMetadata(for: format)
            } catch {
                continue
            }

            for item in formatMetadata {
                // Prefer stringValue to avoid bridging issues
                if let keyString = (item.key as? String) ?? item.identifier?.rawValue {
                    switch keyString {
                    case "TPE2", "©ART": // Album Artist
                        if let value = item.stringValue { albumArtist = value }
                    case "TDRC", "©day": // Year
                        if let value = item.stringValue {
                            let yearString = value.prefix(4)
                            year = Int(yearString)
                        }
                    case "TRCK": // Track Number
                        if let value = item.stringValue {
                            let components = value.split(separator: "/")
                            if let first = components.first { trackNumber = Int(first) }
                        }
                    case "TPOS": // Disc Number
                        if let value = item.stringValue {
                            let components = value.split(separator: "/")
                            if let first = components.first { discNumber = Int(first) }
                        }
                    default:
                        break
                    }
                }
            }
        }

        // Generate a stable ID based on the URL path
        let stableString = url.lastPathComponent
        let id = UUID(uuidString: stableString.padTo32()) ?? UUID()

        return Song(
            id: id,
            url: url,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            duration: duration,
            artworkData: artworkData,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber
        )
    }


}

private extension String {
    func padTo32() -> String {
        let hash = self.hashString()
        // Format as UUID: 8-4-4-4-12
        let h = hash.padding(toLength: 32, withPad: "0", startingAt: 0)
        let i = h.index(h.startIndex, offsetBy: 8)
        let j = h.index(i, offsetBy: 4)
        let k = h.index(j, offsetBy: 4)
        let l = h.index(k, offsetBy: 4)
        
        return "\(h[..<i])-\(h[i..<j])-\(h[j..<k])-\(h[k..<l])-\(h[l...])"
    }
    
    func hashString() -> String {
        let data = Data(self.utf8)
        var hash = ""
        // Simple hash to get a hex string
        var h: UInt64 = 5381
        for byte in data {
            h = ((h << 5) &+ h) &+ UInt64(byte)
        }
        // Let's use a bit more robust hex representation
        return String(format: "%016llx%016llx", h, h.reversed())
    }
}

private extension UInt64 {
    func reversed() -> UInt64 {
        var v = self
        v = ((v >> 1) & 0x5555555555555555) | ((v & 0x5555555555555555) << 1)
        v = ((v >> 2) & 0x3333333333333333) | ((v & 0x3333333333333333) << 2)
        v = ((v >> 4) & 0x0F0F0F0F0F0F0F0F) | ((v & 0x0F0F0F0F0F0F0F0F) << 4)
        v = ((v >> 8) & 0x00FF00FF00FF00FF) | ((v & 0x00FF00FF00FF00FF) << 8)
        v = ((v >> 16) & 0x0000FFFF0000FFFF) | ((v & 0x0000FFFF0000FFFF) << 16)
        v = (v >> 32) | (v << 32)
        return v
    }
}
