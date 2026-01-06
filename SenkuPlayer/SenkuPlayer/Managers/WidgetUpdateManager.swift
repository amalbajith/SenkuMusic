
import Foundation
import WidgetKit
import SwiftUI

class WidgetUpdateManager {
    static let shared = WidgetUpdateManager()
    
    private init() {}
    
    func update(currentSong: Song?, isPlaying: Bool) {
        let stats: WidgetData
        
        if let song = currentSong {
            stats = WidgetData(
                title: song.title,
                artist: song.artist,
                album: song.album,
                artworkData: song.artworkData,
                isPlaying: isPlaying
            )
        } else {
            stats = .empty
        }
        
        save(stats)
    }
    
    private func save(_ data: WidgetData) {
        // Access the shared UserDefaults
        guard let userDefaults = UserDefaults(suiteName: WidgetKeys.appGroup) else {
            print("❌ Failed to load UserDefaults for group: \(WidgetKeys.appGroup). Make sure App Groups are enabled and the ID matches.")
            return
        }
        
        // Encode and save data
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: WidgetKeys.data)
            // Force write to disk to ensure widget gets it immediately
            userDefaults.synchronize()
            
            // Reload the widget timeline
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
