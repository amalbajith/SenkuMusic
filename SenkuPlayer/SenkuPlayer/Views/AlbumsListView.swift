//
//  AlbumsListView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct AlbumsListView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    let searchText: String
    
    private var filteredAlbums: [Album] {
        if searchText.isEmpty {
            return library.albums
        } else {
            return library.searchAlbums(query: searchText)
        }
    }
    
    var body: some View {
        Group {
            if filteredAlbums.isEmpty {
                EmptyLibraryView()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(filteredAlbums, id: \.id) { album in
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                AlbumGridItem(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(ModernTheme.cardPadding)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AlbumGridItem: View {
    let album: Album
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            CachedArtworkView(song: album.songs.first, size: 160, cornerRadius: 12)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            
            // Album Info
            Text(album.name.normalizedForDisplay)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Text(album.artist.normalizedForDisplay)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

struct AlbumDetailView: View {
    @StateObject private var player = AudioPlayerManager.shared
    let album: Album
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    // Artwork
                    CachedArtworkView(song: album.songs.first, size: 200, cornerRadius: 16)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                    
                    // Album Info
                    VStack(spacing: 4) {
                        Text(album.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(album.artist)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if let year = album.year {
                            Text("\(year)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Play Button
                    Button {
                        if let firstSong = album.songs.first {
                            player.playSong(firstSong, in: album.songs, at: 0)
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .pillButtonStyle()
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
                
                // Songs List
                VStack(spacing: 0) {
                    ForEach(Array(album.songs.enumerated()), id: \.element.id) { index, song in
                        AlbumSongRow(
                            song: song,
                            trackNumber: index + 1,
                            isPlaying: player.currentSong?.id == song.id && player.isPlaying
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.playSong(song, in: album.songs, at: index)
                        }
                        
                        if index < album.songs.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AlbumSongRow: View {
    let song: Song
    let trackNumber: Int
    let isPlaying: Bool
    @ObservedObject var player = AudioPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Track Number
            Text("\(trackNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
            
            // Song Info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title.normalizedForDisplay)
                    .font(.body)
                    .foregroundColor(isPlaying ? ModernTheme.accentYellow : ModernTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if song.artist != song.album {
                    Text(song.artist.normalizedForDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Playing Indicator or Duration
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(ModernTheme.accentYellow)
                    .symbolEffect(.variableColor.iterative)
            } else {
                Menu {
                    Button {
                        player.playNext(song: song)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    
                    Button {
                        FavoritesManager.shared.toggleFavorite(song: song)
                    } label: {
                        let isFav = FavoritesManager.shared.isFavorite(song: song)
                        Label(isFav ? "Remove from Favorites" : "Favorite",
                              systemImage: isFav ? "heart.slash.fill" : "heart")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(4)
                }

                Text(formatDuration(song.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        AlbumsListView(searchText: "")
    }
}
