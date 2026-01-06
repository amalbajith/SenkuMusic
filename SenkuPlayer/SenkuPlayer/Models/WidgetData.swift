
import Foundation

struct WidgetData: Codable, Equatable {
    let title: String
    let artist: String
    let album: String
    let artworkData: Data?
    let isPlaying: Bool
    
    static let empty = WidgetData(
        title: "Not Playing",
        artist: "Senku Player",
        album: "",
        artworkData: nil,
        isPlaying: false
    )
}

enum WidgetKeys {
    static let appGroup = "group.com.senku.player" // REPLACE THIS with your App Group ID
    static let data = "widgetData"
}
