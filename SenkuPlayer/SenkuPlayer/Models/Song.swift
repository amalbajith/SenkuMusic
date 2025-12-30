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
    static func fromURL(_ url: URL) -> Song? {
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
        
        // Get duration
        duration = asset.duration.seconds
        
        // Extract metadata
        let metadata = asset.commonMetadata
        
        for item in metadata {
            guard let key = item.commonKey?.rawValue,
                  let value = item.value else { continue }
            
            switch key {
            case "title":
                if let titleValue = value as? String {
                    title = titleValue
                }
            case "artist":
                if let artistValue = value as? String {
                    artist = artistValue
                }
            case "albumName":
                if let albumValue = value as? String {
                    album = albumValue
                }
            case "type":
                if let genreValue = value as? String {
                    genre = genreValue
                }
            case "artwork":
                if let imageData = value as? Data {
                    artworkData = imageData
                }
            default:
                break
            }
        }
        
        // Try to extract additional ID3 tags
        for format in asset.availableMetadataFormats {
            let formatMetadata = asset.metadata(forFormat: format)
            
            for item in formatMetadata {
                if let keyString = item.key as? String {
                    switch keyString {
                    case "TPE2", "©ART": // Album Artist
                        if let value = item.stringValue {
                            albumArtist = value
                        }
                    case "TDRC", "©day": // Year
                        if let value = item.stringValue {
                            let yearString = value.prefix(4)
                            year = Int(yearString)
                        }
                    case "TRCK": // Track Number
                        if let value = item.stringValue {
                            let components = value.split(separator: "/")
                            if let first = components.first {
                                trackNumber = Int(first)
                            }
                        }
                    case "TPOS": // Disc Number
                        if let value = item.stringValue {
                            let components = value.split(separator: "/")
                            if let first = components.first {
                                discNumber = Int(first)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        return Song(
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
