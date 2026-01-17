//
//  PlaylistsListView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct PlaylistsListView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
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
                    // Favorites Section
                    if searchText.isEmpty {
                        NavigationLink(destination: FavoritesDetailView()) {
                            FavoritesRow()
                        }
                    }
                    
                    
                    ForEach(filteredPlaylists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlistID: playlist.id)) {
                            PlaylistRow(playlistID: playlist.id)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                library.deletePlaylist(playlist)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deletePlaylists)
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
                }
            }
        }
        .navigationTitle("Playlists")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
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
        .preferredColorScheme(.dark)
    }
    
    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            let playlist = filteredPlaylists[index]
            library.deletePlaylist(playlist)
        }
    }
}

// MARK: - Favorites Components

struct FavoritesRow: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var favorites = FavoritesManager.shared
    
    private var songs: [Song] {
        favorites.getFavorites(from: library.songs)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let song = songs.first, 
                   let artworkData = song.artworkData, 
                   let platformImage = PlatformImage.fromData(artworkData) {
                    Image(platformImage: platformImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay {
                            Color.black.opacity(0.3)
                                .cornerRadius(8)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ModernTheme.mediumGray)
                        .frame(width: 60, height: 60)
                }
                
                Image(systemName: "heart.fill")
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Favorites")
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

struct FavoritesDetailView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var favorites = FavoritesManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    
    private var songs: [Song] {
        favorites.getFavorites(from: library.songs)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                ZStack {
                     if let song = songs.first, 
                        let artworkData = song.artworkData, 
                        let platformImage = PlatformImage.fromData(artworkData) {
                          Image(platformImage: platformImage)
                              .resizable()
                              .aspectRatio(contentMode: .fill)
                              .frame(width: 200, height: 200)
                              .cornerRadius(16)
                              .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                     } else {
                          RoundedRectangle(cornerRadius: 16)
                              .fill(ModernTheme.mediumGray)
                              .frame(width: 200, height: 200)
                              .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                     }
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
                
                Text("Favorites")
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
                             .foregroundColor(ModernTheme.pureBlack)
                             .frame(maxWidth: .infinity)
                             .padding()
                             .background(Color.white)
                             .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
            
            if songs.isEmpty {
                 VStack(spacing: 16) {
                     Image(systemName: "heart.slash")
                         .font(.system(size: 50))
                         .foregroundColor(.gray)
                     
                     Text("No Favorites Yet")
                         .font(.title3)
                         .fontWeight(.semibold)
                     
                     Text("Tap the heart icon on the player to add songs")
                         .font(.subheadline)
                         .foregroundColor(.secondary)
                         .multilineTextAlignment(.center)
                 }
                 .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SimpleSongRow(
                            song: song,
                            isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                            isSelected: false,
                            isSelectionMode: false
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.playSong(song, in: songs, at: index)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                favorites.toggleFavorite(song: song)
                            } label: {
                                Label("Remove", systemImage: "heart.slash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Playlist Components

struct PlaylistRow: View {
    @StateObject private var library = MusicLibraryManager.shared
    let playlistID: UUID
    
    private var playlist: Playlist? {
        library.playlists.first { $0.id == playlistID }
    }
    
    private var songs: [Song] {
        guard let playlist = playlist else { return [] }
        return library.getSongsForPlaylist(playlist)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            PlaylistArtwork(songs: songs)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text((playlist?.name ?? "Unknown Playlist").normalizedForDisplay)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text("\(songs.count) song\(songs.count != 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
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
                .fill(Color.gray.opacity(0.15))
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
               let platformImage = PlatformImage.fromData(artworkData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.mediumGray, ModernTheme.darkGray],
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
               let platformImage = PlatformImage.fromData(artworkData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: size, height: size)
            }
        }
    }
}

struct PlaylistDetailView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    let playlistID: UUID
    @Environment(\.dismiss) private var dismiss
    
    private var playlist: Playlist? {
        library.playlists.first { $0.id == playlistID }
    }
    
    private var songs: [Song] {
        guard let playlist = playlist else { return [] }
        return library.getSongsForPlaylist(playlist)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                PlaylistArtwork(songs: songs)
                    .frame(width: 200, height: 200)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                
                Text(playlist?.name ?? "Playlist")
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
                            .foregroundColor(ModernTheme.pureBlack)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
            
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
                        SimpleSongRow(
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
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
        }
    }
    
    private func deleteSongs(at offsets: IndexSet) {
        guard var updatedPlaylist = playlist else { return }
        for index in offsets {
            let song = songs[index]
            updatedPlaylist.removeSong(song.id)
        }
        library.updatePlaylist(updatedPlaylist)
    }
    
    private func moveSongs(from source: IndexSet, to destination: Int) {
        guard var updatedPlaylist = playlist else { return }
        updatedPlaylist.moveSong(from: source, to: destination)
        library.updatePlaylist(updatedPlaylist)
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
                    .foregroundColor(ModernTheme.pureBlack)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        PlaylistsListView(searchText: "")
    }
}
