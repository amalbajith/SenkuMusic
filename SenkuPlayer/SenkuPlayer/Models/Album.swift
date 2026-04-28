//
//  Album.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation
import Combine

struct Album: Identifiable, Hashable {
    let id: UUID
    let name: String
    let artist: String
    var songs: [Song]
    
    init(id: UUID = UUID(), name: String, artist: String, songs: [Song] = []) {
        self.id = id
        self.name = name
        self.artist = artist
        self.songs = songs
    }
    
    var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + $1.duration }
    }
    
    var year: Int? {
        songs.compactMap { (song: Song) -> Int? in song.year }.first
    }

    var displayArtworkData: Data? {
        if let artworkData {
            return artworkData
        }

        return songs.lazy.compactMap(\.artworkData).first
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
}
