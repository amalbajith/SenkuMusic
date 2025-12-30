//
//  Artist.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation

struct Artist: Identifiable, Hashable {
    let id: UUID
    let name: String
    var albums: [Album]
    var songs: [Song]
    
    init(id: UUID = UUID(), name: String, albums: [Album] = [], songs: [Song] = []) {
        self.id = id
        self.name = name
        self.albums = albums
        self.songs = songs
    }
    
    var totalSongs: Int {
        songs.count
    }
    
    var totalAlbums: Int {
        albums.count
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id
    }
}
