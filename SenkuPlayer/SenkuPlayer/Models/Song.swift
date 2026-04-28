//
//  Song.swift
//  SenkuPlayer
//

import Foundation
import AVFoundation

struct Song: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var title: String
    var artist: String
    var album: String
    var albumArtist: String?
    var duration: TimeInterval
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var energy: Float?
    var plainLyrics: String?
    var syncedLyrics: String?
    
    // Remote Streaming Support
    var isRemote: Bool = false
    var streamURL: URL?
    var thumbnailURL: URL?
    
    // Playback Stats
    var lastPlayedDate: Date?
    var playCount: Int = 0
    
    // We remove artworkData from the struct to save memory
    // Instead, views can fetch it from ArtworkManager or MusicLibraryManager
    var hasArtwork: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, url, title, artist, album, albumArtist, duration, genre, year, trackNumber, discNumber, energy, plainLyrics, syncedLyrics, isRemote, streamURL, thumbnailURL, hasArtwork, lastPlayedDate, playCount
    }
    
    init(id: UUID = UUID(), url: URL, title: String, artist: String, album: String, albumArtist: String? = nil, duration: TimeInterval, genre: String? = nil, year: Int? = nil, trackNumber: Int? = nil, discNumber: Int? = nil, energy: Float? = nil, plainLyrics: String? = nil, syncedLyrics: String? = nil, isRemote: Bool = false, streamURL: URL? = nil, thumbnailURL: URL? = nil, hasArtwork: Bool = false, lastPlayedDate: Date? = nil, playCount: Int = 0) {
        self.id = id
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.duration = duration
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.energy = energy
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
        self.isRemote = isRemote
        self.streamURL = streamURL
        self.thumbnailURL = thumbnailURL
        self.hasArtwork = hasArtwork
        self.lastPlayedDate = lastPlayedDate
        self.playCount = playCount
    }
    
    // ── SAFE DECODING FOR OLD DATA ────────────────────────
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        album = try container.decode(String.self, forKey: .album)
        albumArtist = try container.decodeIfPresent(String.self, forKey: .albumArtist)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .trackNumber)
        discNumber = try container.decodeIfPresent(Int.self, forKey: .discNumber)
        energy = try container.decodeIfPresent(Float.self, forKey: .energy)
        plainLyrics = try container.decodeIfPresent(String.self, forKey: .plainLyrics)
        syncedLyrics = try container.decodeIfPresent(String.self, forKey: .syncedLyrics)
        
        // New fields — use decodeIfPresent to avoid crashing on old data
        isRemote = try container.decodeIfPresent(Bool.self, forKey: .isRemote) ?? false
        streamURL = try container.decodeIfPresent(URL.self, forKey: .streamURL)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        
        hasArtwork = try container.decode(Bool.self, forKey: .hasArtwork)
        lastPlayedDate = try container.decodeIfPresent(Date.self, forKey: .lastPlayedDate)
        playCount = try container.decode(Int.self, forKey: .playCount)
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
    

}

// MARK: - Metadata Extraction
extension Song {
    static func fromURL(_ url: URL) async -> (Song, Data?)? {
        let asset = AVURLAsset(url: url)

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

        do {
            let time = try await asset.load(.duration)
            duration = time.seconds
        } catch {}

        let commonMetadata: [AVMetadataItem]
        do {
            commonMetadata = try await asset.load(.commonMetadata)
        } catch {
            commonMetadata = []
        }

        for item in commonMetadata {
            guard let key = item.commonKey?.rawValue else { continue }
            
            do {
                switch key {
                case "title":
                    if let value = try await item.load(.stringValue) { title = value }
                case "artist":
                    if let value = try await item.load(.stringValue) { artist = value }
                case "albumName":
                    if let value = try await item.load(.stringValue) { album = value }
                case "type":
                    if let value = try await item.load(.stringValue) { genre = value }
                case "artwork":
                    if let value = try await item.load(.dataValue) { artworkData = value }
                default:
                    break
                }
            } catch {}
        }

        let formats: [AVMetadataFormat]
        do {
            formats = try await asset.load(.availableMetadataFormats)
        } catch {
            formats = []
        }

        for format in formats {
            let formatMetadata: [AVMetadataItem]
            do {
                formatMetadata = try await asset.loadMetadata(for: format)
            } catch {
                continue
            }

            for item in formatMetadata {
                if let keyString = (item.key as? String) ?? item.identifier?.rawValue {
                    switch keyString {
                    case "TPE2", "©ART": // Album Artist
                        if let value = try? await item.load(.stringValue) { albumArtist = value }
                    case "TDRC", "©day": // Year
                        if let value = try? await item.load(.stringValue) {
                            year = Int(value.prefix(4))
                        }
                    case "TRCK": // Track Number
                        if let value = try? await item.load(.stringValue) {
                            trackNumber = Int(value.split(separator: "/").first ?? "")
                        }
                    case "TPOS": // Disc Number
                        if let value = try? await item.load(.stringValue) {
                            discNumber = Int(value.split(separator: "/").first ?? "")
                        }
                    default:
                        break
                    }
                }
            }
        }

        // Generate a stable ID
        let stableString = url.lastPathComponent
        let id = UUID(uuidString: stableString.padTo32()) ?? UUID()

        let song = Song(
            id: id,
            url: url,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            duration: duration,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber,
            energy: nil,
            hasArtwork: artworkData != nil
        )
        
        return (song, artworkData)
    }
}

private extension String {
    func padTo32() -> String {
        let hash = self.hashString()
        let h = hash.padding(toLength: 32, withPad: "0", startingAt: 0)
        let i = h.index(h.startIndex, offsetBy: 8)
        let j = h.index(i, offsetBy: 4)
        let k = h.index(j, offsetBy: 4)
        let l = h.index(k, offsetBy: 4)
        return "\(h[..<i])-\(h[i..<j])-\(h[j..<k])-\(h[k..<l])-\(h[l...])"
    }
    
    func hashString() -> String {
        let data = Data(self.utf8)
        var h: UInt64 = 5381
        for byte in data { h = ((h << 5) &+ h) &+ UInt64(byte) }
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
