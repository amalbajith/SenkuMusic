//
//  SpotifyImportService.swift
//  SenkuPlayer
//

import Foundation
import UIKit

struct SpotifyTrack: Codable {
    let title: String
    let artist: String
}

class SpotifyImportService {
    static let shared = SpotifyImportService()
    
    /// Parses a Spotify embed iframe or URL and extracts the playlist ID.
    func extractPlaylistID(from input: String) -> String? {
        let patterns = [
            "playlist/([a-zA-Z0-9]+)",
            "playlist:([a-zA-Z0-9]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input)) {
                if let range = Range(match.range(at: 1), in: input) {
                    return String(input[range])
                }
            }
        }
        
        return nil
    }
    
    /// Fetches track information from a Spotify playlist embed page.
    func fetchPlaylistTracks(playlistID: String) async throws -> [SpotifyTrack] {
        let embedURLString = "https://open.spotify.com/embed/playlist/\(playlistID)"
        guard let url = URL(string: embedURLString) else {
            throw NSError(domain: "SpotifyImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        // Use a generic Desktop User-Agent which is often more reliable for the embed page data
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SpotifyImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode response"])
        }
        
        return parseTracks(from: html)
    }
    
    private func parseTracks(from html: String) -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        
        // Spotify's embed data is usually hidden in a large JSON string.
        // We use several regex patterns to catch different ways the data might be structured.
        
        let patterns = [
            // 1. Standard JSON track object: "name":"Title","artists":[{"name":"Artist"}]
            #"\"name\"\s*:\s*\"([^\"]+)\"\s*,\s*\"artists\"\s*:\s*\[\s*\{\s*\"name\"\s*:\s*\"([^\"]+)\""#,
            // 2. Simpler track/subtitle pattern: "title":"Title","subtitle":"Artist"
            #"\"title\"\s*:\s*\"([^\"]+)\"\s*,\s*\"subtitle\"\s*:\s*\"([^\"]+)\""#,
            // 3. Alternative: "name":"Title" ... "artistName":"Artist"
            #"\"name\"\s*:\s*\"([^\"]+)\".*?\"artistName\"\s*:\s*\"([^\"]+)\""#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let titleRange = Range(match.range(at: 1), in: html),
                       let artistRange = Range(match.range(at: 2), in: html) {
                        let title = String(html[titleRange]).decodingHTMLEntities()
                        let artist = String(html[artistRange]).decodingHTMLEntities()
                        
                        // Clean up escaping (e.g. \u0026)
                        let cleanTitle = title.replacingOccurrences(of: "\\\\u([0-9a-fA-F]{4})", with: "", options: .regularExpression)
                        
                        if !tracks.contains(where: { $0.title == title }) && title.count > 1 && artist.count > 1 {
                            tracks.append(SpotifyTrack(title: title, artist: artist))
                        }
                    }
                }
            }
        }
        
        return tracks
    }
    
    /// Matches scraped Spotify tracks with local library songs.
    func matchTracksWithLibrary(spotifyTracks: [SpotifyTrack], librarySongs: [Song]) -> [UUID] {
        var matchedIDs: [UUID] = []
        
        for sTrack in spotifyTracks {
            let sTitle = sTrack.title.lowercased().trimmingCharacters(in: .whitespaces)
            let sArtist = sTrack.artist.lowercased().trimmingCharacters(in: .whitespaces)
            
            // 1. Try Exact Match
            if let match = librarySongs.first(where: { song in
                let lTitle = song.title.lowercased().trimmingCharacters(in: .whitespaces)
                let lArtist = song.artist.lowercased().trimmingCharacters(in: .whitespaces)
                return lTitle == sTitle && lArtist == sArtist
            }) {
                matchedIDs.append(match.id)
                continue
            }
            
            // 2. Try Fuzzy Match
            if let match = librarySongs.first(where: { song in
                let lTitle = song.title.lowercased()
                let lArtist = song.artist.lowercased()
                
                let cleanLTitle = lTitle.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
                let cleanSTitle = sTitle.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
                
                let titleMatch = cleanLTitle.contains(cleanSTitle) || cleanSTitle.contains(cleanLTitle) || 
                                 lTitle.contains(sTitle) || sTitle.contains(lTitle)
                
                let artistMatch = lArtist.contains(sArtist) || sArtist.contains(lArtist)
                
                return titleMatch && artistMatch
            }) {
                matchedIDs.append(match.id)
            }
        }
        
        return matchedIDs
    }
}

private extension String {
    func decodingHTMLEntities() -> String {
        if !self.contains("&") && !self.contains("\\u") { return self }
        
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        var decoded = self
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                decoded = attributedString.string
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 0.5)
        
        return decoded
    }
}
