import Foundation

// MARK: - Model

struct CloudSearchResult: Identifiable {
    let id: String          // Track ID
    let title: String
    let artist: String
    let duration: TimeInterval // Usually 30s for previews
    let thumbnailURL: URL?
    let previewURL: URL?       // The direct stream URL from iTunes
}

// MARK: - Errors

enum CloudDiscoveryError: LocalizedError {
    case networkError
    case noResults
    case invalidData

    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error. Please check your connection."
        case .noResults:    return "No results found on iTunes."
        case .invalidData:  return "Failed to parse discovery data."
        }
    }
}

// MARK: - Service

actor CloudDiscoveryService {
    static let shared = CloudDiscoveryService()

    // Store preview URLs to serve them instantly when play is pressed
    private var streamCache: [String: URL] = [:]

    // MARK: - Search

    func search(query: String) async throws -> [CloudSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&entity=song&limit=30"
        
        guard let url = URL(string: urlString) else {
            throw CloudDiscoveryError.invalidData
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CloudDiscoveryError.networkError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw CloudDiscoveryError.invalidData
        }

        if results.isEmpty {
            throw CloudDiscoveryError.noResults
        }

        return results.compactMap { item in
            guard let trackId = item["trackId"] as? Int,
                  let title = item["trackName"] as? String,
                  let artist = item["artistName"] as? String,
                  let previewUrlString = item["previewUrl"] as? String,
                  let previewUrl = URL(string: previewUrlString) else {
                return nil
            }

            // Get high quality artwork (replace 100x100 with 600x600)
            var artworkUrl: URL? = nil
            if let artworkUrl100 = item["artworkUrl100"] as? String {
                let highResUrl = artworkUrl100.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                artworkUrl = URL(string: highResUrl)
            }

            let idStr = String(trackId)
            
            // Cache the preview URL so we can play it instantly later
            streamCache[idStr] = previewUrl

            return CloudSearchResult(
                id: idStr,
                title: title,
                artist: artist,
                duration: 30.0, // iTunes previews are exactly 30s
                thumbnailURL: artworkUrl,
                previewURL: previewUrl
            )
        }
    }

    // MARK: - Stream URL

    func getStreamURL(for trackId: String) async throws -> URL {
        if let url = streamCache[trackId] {
            return url
        }
        throw CloudDiscoveryError.invalidData
    }

    // MARK: - Song Factory

    func makeSong(from result: CloudSearchResult) async -> Song {
        let id = result.id
        return await MainActor.run {
            Song(
                id: UUID(),
                url: URL(string: "senku://cloud/\(id)")!,
                title: result.title,
                artist: result.artist,
                album: "Cloud (iTunes Preview)",
                duration: result.duration,
                isRemote: true,
                streamURL: result.previewURL,
                thumbnailURL: result.thumbnailURL,
                hasArtwork: result.thumbnailURL != nil
            )
        }
    }

    func invalidateStream(for trackId: String) {
        // iTunes URLs don't really expire or break
    }

    func resetCache() {
        streamCache.removeAll()
    }
    
    // No-op for API compatibility
    nonisolated func warmUpInBackground() { }
}
