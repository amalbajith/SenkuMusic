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
        // Use a generic mobile browser User-Agent to ensure we get a parseable version
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SpotifyImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode response"])
        }
        
        var tracks = parseTracksFromJSON(from: html)
        if tracks.isEmpty {
            tracks = parseTracksFromHTML(from: html)
        }
        
        return tracks
    }
    
    private func parseTracksFromJSON(from html: String) -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        
        // Spotify often embeds data in a JSON blob. We search for patterns like:
        // "name":"Song Name","artists":[{"name":"Artist Name"}]
        // We use a flexible regex to catch variations in whitespace/escaping.
        
        let pattern = #""name"\s*:\s*"([^"]+)"\s*,\s*"artists"\s*:\s*\[\s*\{\s*"name"\s*:\s*"([^"]+)""#
        
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
    
    private func parseTracksFromHTML(from html: String) -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        
        // If JSON parsing fails, look for HTML patterns.
        // Spotify's embed often has track names in spans/divs with certain data attributes or classes.
        
        // Pattern: Search for anything that looks like "Title" followed by "Artist" in proximity
        // This is a broad "catch-all" regex for structured lists
        let patterns = [
            // Matches: <span ...>Title</span><span ...>Artist</span>
            #"<span[^>]*>([^<]+)</span>\s*<span[^>]*>([^<]+)</span>"#,
            // Matches: "title":"Title","artist":"Artist"
            #""title"\s*:\s*"([^"]+)"\s*,\s*"artist"\s*:\s*"([^"]+)""#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let titleRange = Range(match.range(at: 1), in: html),
                       let artistRange = Range(match.range(at: 2), in: html) {
                        let title = String(html[titleRange]).decodingHTMLEntities().trimmingCharacters(in: .whitespaces)
                        let artist = String(html[artistRange]).decodingHTMLEntities().trimmingCharacters(in: .whitespaces)
                        
                        if title.count > 1 && artist.count > 1 && !tracks.contains(where: { $0.title == title }) {
                            tracks.append(SpotifyTrack(title: title, artist: artist))
                        }
                    }
                }
            }
            if !tracks.isEmpty { break }
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
            
            // 2. Try Fuzzy Match (Title contains or is contained by)
            if let match = librarySongs.first(where: { song in
                let lTitle = song.title.lowercased()
                let lArtist = song.artist.lowercased()
                
                // Remove common suffixes like "(Remastered)", "- Single", etc for better matching
                let cleanLTitle = lTitle.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
                let cleanSTitle = sTitle.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
                
                let titleMatch = cleanLTitle.contains(cleanSTitle) || cleanSTitle.contains(cleanLTitle)
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
        // If it doesn't look like it has entities, skip the expensive conversion
        if !self.contains("&") { return self }
        
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        // Run on main thread if needed, though NSAttributedString is generally safe for simple HTML
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
