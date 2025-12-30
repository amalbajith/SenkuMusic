//
//  PlaylistPickerView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct PlaylistPickerView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @Environment(\.dismiss) private var dismiss
    let songIDs: [UUID]
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Create New Playlist
                Button {
                    showingCreatePlaylist = true
                } label: {
                    Label("New Playlist", systemImage: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                
                // Existing Playlists
                Section {
                    ForEach(library.playlists) { playlist in
                        Button {
                            addToPlaylist(playlist)
                        } label: {
                            HStack {
                                PlaylistArtwork(songs: library.getSongsForPlaylist(playlist))
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.name)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(playlist.songIDs.count) songs")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("New Playlist", isPresented: $showingCreatePlaylist) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        createAndAddToPlaylist()
                    }
                }
            } message: {
                Text("Enter a name for your new playlist")
            }
        }
    }
    
    private func addToPlaylist(_ playlist: Playlist) {
        library.addSongsToPlaylist(songIDs, playlist: playlist)
        dismiss()
    }
    
    private func createAndAddToPlaylist() {
        library.createPlaylist(name: newPlaylistName, songIDs: songIDs)
        newPlaylistName = ""
        dismiss()
    }
}

#Preview {
    PlaylistPickerView(songIDs: [])
}
