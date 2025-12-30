//
//  PlaylistsListView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct PlaylistsListView: View {
    @StateObject private var library = MusicLibraryManager.shared
    let searchText: String
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""
    
    private var filteredPlaylists: [Playlist] {
        if searchText.isEmpty {
            return library.playlists
        } else {
            let lowercased = searchText.lowercased()
            return library.playlists.filter { $0.name.lowercased().contains(lowercased) }
        }
    }
    
    var body: some View {
        VStack {
            if filteredPlaylists.isEmpty && searchText.isEmpty {
                EmptyPlaylistsView {
                    showingCreatePlaylist = true
                }
            } else {
                List {
                    ForEach(filteredPlaylists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                            PlaylistRow(playlist: playlist)
                        }
                    }
                    .onDelete(perform: deletePlaylists)
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreatePlaylist = true
                } label: {
                    Image(systemName: "plus")
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
                    library.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        } message: {
            Text("Enter a name for your new playlist")
        }
    }
    
    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            let playlist = filteredPlaylists[index]
            library.deletePlaylist(playlist)
        }
    }
}

struct PlaylistRow: View {
    @StateObject private var library = MusicLibraryManager.shared
    let playlist: Playlist
    
    private var songs: [Song] {
        library.getSongsForPlaylist(playlist)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Playlist Artwork (Grid of 4 songs)
            PlaylistArtwork(songs: songs)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            // Playlist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(songs.count) song\(songs.count != 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PlaylistArtwork: View {
    let songs: [Song]
    
    var body: some View {
        if songs.isEmpty {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .overlay {
                    Image(systemName: "music.note.list")
                        .foregroundColor(.gray)
                }
        } else if songs.count == 1 {
            singleArtwork(songs[0])
        } else {
            gridArtwork
        }
    }
    
    private func singleArtwork(_ song: Song) -> some View {
        Group {
            if let artworkData = song.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                    }
            }
        }
    }
    
    private var gridArtwork: some View {
        GeometryReader { geometry in
            let size = geometry.size.width / 2
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    artworkTile(for: songs[safe: 0], size: size)
                    artworkTile(for: songs[safe: 1], size: size)
                }
                HStack(spacing: 0) {
                    artworkTile(for: songs[safe: 2], size: size)
                    artworkTile(for: songs[safe: 3], size: size)
                }
            }
        }
    }
    
    private func artworkTile(for song: Song?, size: CGFloat) -> some View {
        Group {
            if let song = song,
               let artworkData = song.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct PlaylistDetailView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    @State var playlist: Playlist
    @State private var isEditMode = false
    @Environment(\.dismiss) private var dismiss
    
    private var songs: [Song] {
        library.getSongsForPlaylist(playlist)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                PlaylistArtwork(songs: songs)
                    .frame(width: 200, height: 200)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                
                Text(playlist.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(songs.count) song\(songs.count != 1 ? "s" : "")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !songs.isEmpty {
                    Button {
                        if let firstSong = songs.first {
                            player.playSong(firstSong, in: songs, at: 0)
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
            
            // Songs List
            if songs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Songs")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Add songs to this playlist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongRow(
                            song: song,
                            isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                            isSelected: false,
                            isSelectionMode: false
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.playSong(song, in: songs, at: index)
                        }
                    }
                    .onDelete(perform: deleteSongs)
                    .onMove(perform: moveSongs)
                }
                .listStyle(.plain)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            let song = songs[index]
            playlist.removeSong(song.id)
        }
        library.updatePlaylist(playlist)
    }
    
    private func moveSongs(from source: IndexSet, to destination: Int) {
        playlist.moveSong(from: source, to: destination)
        library.updatePlaylist(playlist)
    }
}

struct EmptyPlaylistsView: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Playlists")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a playlist to organize your music")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                onCreate()
            } label: {
                Label("Create Playlist", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    NavigationStack {
        PlaylistsListView(searchText: "")
    }
}
