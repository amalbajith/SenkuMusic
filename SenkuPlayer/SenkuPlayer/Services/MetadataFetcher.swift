//
//  MetadataFetcher.swift
//  SenkuPlayer
//
//  Automatically fetches album artwork and metadata from online sources
//

import Combine
import Foundation
import SwiftUI

class MetadataFetcher: ObservableObject {
    static let shared = MetadataFetcher()
    
    @Published var isFetching = false
    @Published var progress: Double = 0
    @Published var currentSong: String = ""
    
    private let musicBrainzBaseURL = "https://musicbrainz.org/ws/2"
    private let coverArtBaseURL = "https://coverartarchive.org"
    private let maxArtworkBytes = 8 * 1024 * 1024
    private let allowedHosts: Set<String> = ["musicbrainz.org", "coverartarchive.org"]
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetch metadata for a single song
    func fetchMetadata(for song: Song) async -> (artwork: Data?, updatedMetadata: SongMetadata?) {
        // Search MusicBrainz for the recording
        guard let recording = await searchRecording(title: song.title, artist: song.artist) else {
            return (nil, nil)
        }
        
        // Get release (album) information
        guard let releaseId = recording.releaseId else {
            return (nil, nil)
        }
        
        // Fetch album artwork
        let artwork = await fetchArtwork(releaseId: releaseId)
        
        // Create updated metadata
        let metadata = SongMetadata(
            title: recording.title ?? song.title,
            artist: recording.artist ?? song.artist,
            album: recording.album ?? song.album,
            year: recording.year,
            genre: recording.genre
        )
        
        return (artwork, metadata)
    }
    
    /// Fetch metadata for multiple songs with progress tracking
    func fetchMetadataForSongs(_ songs: [Song]) async -> [(songId: UUID, artwork: Data?, metadata: SongMetadata?)] {
        await MainActor.run {
            isFetching = true
            progress = 0
        }
        
        var results: [(UUID, Data?, SongMetadata?)] = []
        let total = Double(songs.count)
        
        for (index, song) in songs.enumerated() {
            await MainActor.run {
                currentSong = song.title
                progress = Double(index) / total
            }
            
            let (artwork, metadata) = await fetchMetadata(for: song)
            results.append((song.id, artwork, metadata))
            
            // Rate limiting - be respectful to the API
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
        
        await MainActor.run {
            isFetching = false
            progress = 1.0
            currentSong = ""
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func searchRecording(title: String, artist: String) async -> RecordingInfo? {
        guard var components = URLComponents(string: "\(musicBrainzBaseURL)/recording/") else { return nil }
        let query = "recording:\(title) AND artist:\(artist)"
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components.url, isAllowedHTTPSURL(url) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("SenkuPlayer/1.0 (contact@example.com)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            let decodedResponse = try JSONDecoder().decode(MusicBrainzRecordingResponse.self, from: data)
            
            guard let recording = decodedResponse.recordings.first else { return nil }
            
            // Extract release ID if available
            let releaseId = recording.releases?.first?.id
            let album = recording.releases?.first?.title
            let year: Int? = {
                guard let dateString = recording.releases?.first?.date else { return nil }
                let yearString = String(dateString.prefix(4))
                return Int(yearString)
            }()
            
            return RecordingInfo(
                title: recording.title,
                artist: recording.artistCredit?.first?.name,
                album: album,
                releaseId: releaseId,
                year: year,
                genre: nil
            )
        } catch {
            print("❌ MusicBrainz search failed: \(error)")
            return nil
        }
    }
    
    private func fetchArtwork(releaseId: String) async -> Data? {
        let encodedReleaseID = releaseId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? releaseId
        let urlString = "\(coverArtBaseURL)/release/\(encodedReleaseID)/front-500"
        guard let url = URL(string: urlString) else { return nil }
        guard isAllowedHTTPSURL(url) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count <= maxArtworkBytes else {
                return nil
            }
            
            return data
        } catch {
            print("❌ Artwork fetch failed: \(error)")
            return nil
        }
    }

    private func isAllowedHTTPSURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return false
        }
        return allowedHosts.contains(host)
    }
}

// MARK: - Data Models

struct SongMetadata {
    let title: String
    let artist: String
    let album: String
    let year: Int?
    let genre: String?
}

private struct RecordingInfo {
    let title: String?
    let artist: String?
    let album: String?
    let releaseId: String?
    let year: Int?
    let genre: String?
}

// MARK: - MusicBrainz API Response Models

private struct MusicBrainzRecordingResponse: Codable {
    let recordings: [MBRecording]
}

private struct MBRecording: Codable {
    let id: String
    let title: String
    let artistCredit: [MBArtistCredit]?
    let releases: [MBRelease]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, releases
        case artistCredit = "artist-credit"
    }
}

private struct MBArtistCredit: Codable {
    let name: String
}

private struct MBRelease: Codable {
    let id: String
    let title: String
    let date: String?
}
