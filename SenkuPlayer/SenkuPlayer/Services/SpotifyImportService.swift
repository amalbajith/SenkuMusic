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
        // Use a Desktop User-Agent to get the full embed page
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SpotifyImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode response"])
        }
        
        let tracks = parseTracks(from: html)
        if tracks.isEmpty {
            // Fallback: Try to find track names in a more generic way if the structured JSON isn't there
            return parseTracksFallback(from: html)
        }
        return tracks
    }
    
    private func parseTracks(from html: String) -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        
        // Spotify embed pages contain a large JSON blob in a script tag.
        // We look for track names and artist names within that JSON.
        
        // Pattern 1: JSON-style track objects
        let pattern = "\"name\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"artists\"\\s*:\\s*\\[\\s*\\{\\s*\"name\"\\s*:\\s*\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let titleRange = Range(match.range(at: 1), in: html),
                   let artistRange = Range(match.range(at: 2), in: html) {
                    let title = String(html[titleRange]).decodingHTMLEntities()
                    let artist = String(html[artistRange]).decodingHTMLEntities()
                    
                    if !tracks.contains(where: { $0.title == title && $0.artist == artist }) {
                        tracks.append(SpotifyTrack(title: title, artist: artist))
                    }
                }
            }
        }
        
        return tracks
    }
    
    private func parseTracksFallback(from html: String) -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        
        // Fallback pattern: Look for title and artist in the meta tags or structured list
        // Spotify often has: <meta property="music:song" ...> or similar in some views
        // But for embed, we can look for specific class names or data-attributes if available.
        
        // Let's try a very broad regex for "Title" by "Artist" patterns
        let pattern = "### ([^\\n]+)\\s+#### ([^\\n,]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
             let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
             for match in matches {
                 if let titleRange = Range(match.range(at: 1), in: html),
                    let artistRange = Range(match.range(at: 2), in: html) {
                     let title = String(html[titleRange]).trimmingCharacters(in: .whitespaces)
                     let artist = String(html[artistRange]).trimmingCharacters(in: .whitespaces)
                     tracks.append(SpotifyTrack(title: title, artist: artist))
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
            
            // 1. Try Exact Match (Title + Artist)
            if let match = librarySongs.first(where: { song in
                let lTitle = song.title.lowercased().trimmingCharacters(in: .whitespaces)
                let lArtist = song.artist.lowercased().trimmingCharacters(in: .whitespaces)
                return lTitle == sTitle && lArtist == sArtist
            }) {
                matchedIDs.append(match.id)
                continue
            }
            
            // 2. Try Fuzzy Match (Title contains or is contained by)
            if let match = librarySongs.first(where: { song in
                let lTitle = song.title.lowercased()
                let lArtist = song.artist.lowercased()
                
                let titleMatch = lTitle.contains(sTitle) || sTitle.contains(lTitle)
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
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return self
    }
}
