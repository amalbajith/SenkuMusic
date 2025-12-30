//
//  Album.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation

struct Album: Identifiable, Hashable {
    let id: UUID
    let name: String
    let artist: String
    var songs: [Song]
    var artworkData: Data?
    
    init(id: UUID = UUID(), name: String, artist: String, songs: [Song] = [], artworkData: Data? = nil) {
        self.id = id
        self.name = name
        self.artist = artist
        self.songs = songs
        self.artworkData = artworkData
    }
    
    var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + $1.duration }
    }
    
    var year: Int? {
        songs.compactMap { $0.year }.first
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
}
