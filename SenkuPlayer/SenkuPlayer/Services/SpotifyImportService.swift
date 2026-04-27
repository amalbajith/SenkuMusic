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

struct SpotifyPlaylistInfo {
    let name: String
    let tracks: [SpotifyTrack]
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
    
    /// Fetches track information and playlist name from a Spotify playlist page.
    func fetchPlaylistInfo(playlistID: String) async throws -> SpotifyPlaylistInfo {
        let urls = [
            "https://open.spotify.com/playlist/\(playlistID)",
            "https://open.spotify.com/embed/playlist/\(playlistID)"
        ]
        
        var allFoundTracks: [SpotifyTrack] = []
        var playlistName = "Spotify Mix"
        
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15.0
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let html = String(data: data, encoding: .utf8) {
                    // Extract Name
                    if let name = parsePlaylistName(from: html) {
                        playlistName = name
                    }
                    
                    // Extract Tracks
                    let found = parseTracks(from: html)
                    for track in found {
                        if !allFoundTracks.contains(where: { $0.title == track.title }) {
                            allFoundTracks.append(track)
                        }
                    }
                }
            } catch {
                print("⚠️ SpotifyImport: Failed to fetch from \(urlString): \(error)")
            }
            
            if allFoundTracks.count > 5 { break }
        }
        
        return SpotifyPlaylistInfo(name: playlistName, tracks: allFoundTracks)
    }
    
    private func parsePlaylistName(from html: String) -> String? {
        // 1. Try meta tags
        let patterns = [
            #"<meta\s+property=\"og:title\"\s+content=\"([^\"]+)\""#,
            #"\"name\"\s*:\s*\"([^\"]+)\"\s*,\s*\"type\"\s*:\s*\"playlist\""#,
            #"<title>([^<]+)\s*\|\s*Spotify</title>"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)) {
                if let range = Range(match.range(at: 1), in: html) {
                    let name = String(html[range]).decodingHTMLEntities()
                    if name != "Spotify" && !name.isEmpty {
                        return name
                    }
                }
            }
        }
        return nil
    }
    
    private func parseTracks(from html: String) -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        
        let jsonPattern = #"\"name\"\s*:\s*\"([^\"]+)\"\s*,\s*\"artists\"\s*:\s*\[\s*\{\s*\"name\"\s*:\s*\"([^\"]+)\""#
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let titleRange = Range(match.range(at: 1), in: html),
                   let artistRange = Range(match.range(at: 2), in: html) {
                    let title = String(html[titleRange]).decodingHTMLEntities()
                    let artist = String(html[artistRange]).decodingHTMLEntities()
                    if title.count > 1 && artist.count > 1 {
                        tracks.append(SpotifyTrack(title: title, artist: artist))
                    }
                }
            }
        }
        
        if tracks.isEmpty {
            let titleSubtitlePattern = #"\"title\"\s*:\s*\"([^\"]+)\"\s*,\s*\"subtitle\"\s*:\s*\"([^\"]+)\""#
            if let regex = try? NSRegularExpression(pattern: titleSubtitlePattern, options: []) {
                let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let titleRange = Range(match.range(at: 1), in: html),
                       let artistRange = Range(match.range(at: 2), in: html) {
                        let title = String(html[titleRange]).decodingHTMLEntities()
                        let artist = String(html[artistRange]).decodingHTMLEntities()
                        tracks.append(SpotifyTrack(title: title, artist: artist))
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
            
            let match = librarySongs.first { song in
                let lTitle = song.title.lowercased()
                let lArtist = song.artist.lowercased()
                
                let cleanL = lTitle.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
                let cleanS = sTitle.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
                
                let titleMatch = cleanL == cleanS || lTitle.contains(sTitle) || sTitle.contains(lTitle)
                let artistMatch = lArtist.contains(sArtist) || sArtist.contains(lArtist)
                
                return titleMatch && artistMatch
            }
            
            if let m = match {
                matchedIDs.append(m.id)
            }
        }
        
        return matchedIDs
    }
}

private extension String {
    func decodingHTMLEntities() -> String {
        if !self.contains("&") && !self.contains("\\u") { return self }
        
        var result = self
        if self.contains("\\u") {
            let pattern = "\\\\u([0-9a-fA-F]{4})"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: self, options: [], range: NSRange(self.startIndex..., in: self))
                for match in matches.reversed() {
                    if let range = Range(match.range(at: 1), in: self),
                       let code = UInt32(self[range], radix: 16),
                       let scalar = UnicodeScalar(code) {
                        let replacement = String(scalar)
                        let fullRange = Range(match.range(at: 0), in: result)!
                        result.replaceSubrange(fullRange, with: replacement)
                    }
                }
            }
        }
        
        if !result.contains("&") { return result }

        guard let data = result.data(using: .utf8) else { return result }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        var decoded = result
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
