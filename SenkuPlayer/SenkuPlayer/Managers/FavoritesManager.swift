//
//  FavoritesManager.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation
import SwiftUI
import Combine

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published private(set) var favoriteIDs: Set<UUID> = []
    
    private let favoritesKey = "senku_favorites"
    private var favoritesFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDirectory.appendingPathComponent("favorites.json")
    }
    
    private init() {
        loadFavorites()
    }
    
    func toggleFavorite(song: Song) {
        if favoriteIDs.contains(song.id) {
            favoriteIDs.remove(song.id)
        } else {
            favoriteIDs.insert(song.id)
        }
        saveFavorites()
    }
    
    func isFavorite(song: Song) -> Bool {
        return favoriteIDs.contains(song.id)
    }
    
    func getFavorites(from songs: [Song]) -> [Song] {
        return songs.filter { favoriteIDs.contains($0.id) }
    }
    
    private func saveFavorites() {
        guard let url = favoritesFileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(favoriteIDs)
            try data.write(to: url)
        } catch {
            print("❌ Failed to save favorites: \(error.localizedDescription)")
        }
    }
    
    private func loadFavorites() {
        guard let url = favoritesFileURL else { return }
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                favoriteIDs = try JSONDecoder().decode(Set<UUID>.self, from: data)
            }
        } catch {
            print("❌ Failed to load favorites: \(error.localizedDescription)")
            // Fallback: try loading from UserDefaults if migration is needed in future, currently fresh start
        }
    }
}
