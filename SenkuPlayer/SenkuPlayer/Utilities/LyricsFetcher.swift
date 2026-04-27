//
//  LyricsFetcher.swift
//  SenkuPlayer
//

import Foundation

struct LRCLibResponse: Codable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?
}

class LyricsFetcher {
    static let shared = LyricsFetcher()
    
    func fetchLyrics(for song: Song) async throws -> LRCLibResponse? {
        let baseUrl = "https://lrclib.net/api/get"
        guard var components = URLComponents(string: baseUrl) else { return nil }
        
        let duration = song.duration > 0 ? String(Int(song.duration)) : nil
        
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: song.artist),
            URLQueryItem(name: "track_name", value: song.title)
        ]
        
        if !song.album.isEmpty && song.album != "Unknown Album" {
            components.queryItems?.append(URLQueryItem(name: "album_name", value: song.album))
        }
        
        if let d = duration {
            components.queryItems?.append(URLQueryItem(name: "duration", value: d))
        }
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("SenkuMusicPlayer/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { return nil }
        
        if httpResponse.statusCode == 404 {
            // Not found
            return nil
        }
        
        guard httpResponse.statusCode == 200 else { return nil }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(LRCLibResponse.self, from: data)
        return result
    }
}
