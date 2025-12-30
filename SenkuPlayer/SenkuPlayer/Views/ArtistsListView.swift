//
//  ArtistsListView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct ArtistsListView: View {
    @StateObject private var library = MusicLibraryManager.shared
    let searchText: String
    
    private var filteredArtists: [Artist] {
        if searchText.isEmpty {
            return library.artists
        } else {
            return library.searchArtists(query: searchText)
        }
    }
    
    var body: some View {
        if filteredArtists.isEmpty {
            EmptyLibraryView()
        } else {
            List {
                ForEach(filteredArtists, id: \.id) { artist in
                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                        ArtistRow(artist: artist)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct ArtistRow: View {
    let artist: Artist
    
    var body: some View {
        HStack(spacing: 12) {
            // Artist Avatar
            if let firstSong = artist.songs.first,
               let artworkData = firstSong.artworkData,
               let platformImage = PlatformImage.fromData(artworkData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(artist.name.prefix(1).uppercased())
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
            }
            
            // Artist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(artist.totalAlbums) album\(artist.totalAlbums != 1 ? "s" : ""), \(artist.totalSongs) song\(artist.totalSongs != 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ArtistDetailView: View {
    @StateObject private var player = AudioPlayerManager.shared
    let artist: Artist
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    // Artist Avatar
                    if let firstSong = artist.songs.first,
                       let artworkData = firstSong.artworkData,
                       let platformImage = PlatformImage.fromData(artworkData) {
                        Image(platformImage: platformImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay {
                                Text(artist.name.prefix(1).uppercased())
                                    .font(.system(size: 50))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                    }
                    
                    // Artist Name
                    Text(artist.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("\(artist.totalAlbums) Albums • \(artist.totalSongs) Songs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Play All Button
                    Button {
                        if let firstSong = artist.songs.first {
                            player.playSong(firstSong, in: artist.songs, at: 0)
                        }
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 24)
                
                // Albums Section
                if !artist.albums.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Albums")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(artist.albums, id: \.id) { album in
                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                        ArtistAlbumItem(album: album)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // All Songs Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("All Songs")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(artist.songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(
                                song: song,
                                isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                                isSelected: false,
                                isSelectionMode: false
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.playSong(song, in: artist.songs, at: index)
                            }
                            .padding(.horizontal)
                            
                            if index < artist.songs.count - 1 {
                                Divider()
                                    .padding(.leading, 74)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ArtistAlbumItem: View {
    let album: Album
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            if let artworkData = album.artworkData,
               let platformImage = PlatformImage.fromData(artworkData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            
            // Album Info
            Text(album.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
            
            if let year = album.year {
                Text("\(year)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ArtistsListView(searchText: "")
    }
}
