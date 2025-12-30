//
//  Playlist.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation
import SwiftUI

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var songIDs: [UUID]
    var createdDate: Date
    var modifiedDate: Date
    
    init(id: UUID = UUID(), name: String, songIDs: [UUID] = [], createdDate: Date = Date(), modifiedDate: Date = Date()) {
        self.id = id
        self.name = name
        self.songIDs = songIDs
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }
    
    mutating func addSong(_ songID: UUID) {
        if !songIDs.contains(songID) {
            songIDs.append(songID)
            modifiedDate = Date()
        }
    }
    
    mutating func removeSong(_ songID: UUID) {
        songIDs.removeAll { $0 == songID }
        modifiedDate = Date()
    }
    
    mutating func moveSong(from source: IndexSet, to destination: Int) {
        songIDs.move(fromOffsets: source, toOffset: destination)
        modifiedDate = Date()
    }
}
