//
//  RecentlyPlayedView.swift
//  SenkuPlayer
//
//  Created for SenkuMusic
//

import SwiftUI

struct RecentlyPlayedView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var library = MusicLibraryManager.shared
    
    var body: some View {
        let recentSongs = library.getRecentlyPlayed(limit: 50)
        
        ZStack {
            ModernTheme.backgroundPrimary
                .ignoresSafeArea()
            
            if recentSongs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock")
                        .font(.system(size: 60))
                        .foregroundColor(ModernTheme.lightGray)
                    
                    Text("No Recent History")
                        .font(ModernTheme.title())
                        .foregroundColor(.white)
                    
                    Text("Songs you play will appear here")
                        .font(ModernTheme.body())
                        .foregroundColor(ModernTheme.lightGray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(recentSongs) { song in
                        SimpleSongRow(
                            song: song,
                            isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                            isSelected: false,
                            isSelectionMode: false
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.playSong(song, in: recentSongs, at: recentSongs.firstIndex(of: song) ?? 0)
                        }
                        .contextMenu {
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
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.bottom, player.currentSong != nil ? 80 : 0)
    }
}

#Preview {
    RecentlyPlayedView()
}
