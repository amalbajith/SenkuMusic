//
//  SongsListView.swift
//  SenkuPlayer
//

import SwiftUI

struct SongsListView: View {
    @StateObject private var player = AudioPlayerManager.shared
    let songs: [Song]
    let searchText: String
    @State private var selectedSongs: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingPlaylistPicker = false

    
    var body: some View {
        ZStack {
            ModernTheme.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if songs.isEmpty {
                    EmptyLibraryView()
                } else {
                    let filteredSongs = songs.filter { song in
                        searchText.isEmpty ||
                        song.title.localizedCaseInsensitiveContains(searchText) ||
                        song.artist.localizedCaseInsensitiveContains(searchText) ||
                        song.album.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    if filteredSongs.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(ModernTheme.mediumGray)
                            Text("No matches for \"\(searchText)\"")
                                .foregroundColor(ModernTheme.lightGray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredSongs) { song in
                                SimpleSongRow(
                                    song: song,
                                    isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                                    isSelected: selectedSongs.contains(song.id),
                                    isSelectionMode: isSelectionMode
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isSelectionMode {
                                        toggleSelection(song.id)
                                    } else {
                                        playSong(song, in: filteredSongs)
                                    }
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
                                    
                                    Button {
                                        selectedSongs = [song.id]
                                        showingPlaylistPicker = true
                                    } label: {
                                        Label("Add to a Playlist...", systemImage: "music.note.list")
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
                
                if isSelectionMode {
                    selectionToolbar
                }
            }
            #if os(iOS)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
            }
            #endif
        }
        .toolbar {
            if !songs.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedSongs.removeAll()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPlaylistPicker, onDismiss: {
            if isSelectionMode {
                isSelectionMode = false
                selectedSongs.removeAll()
            }
        }) {
            PlaylistPickerView(songIDs: Array(selectedSongs))
        }

        .preferredColorScheme(.dark)
    }


    private var selectionToolbar: some View {
        HStack {
            Text("\(selectedSongs.count) selected")
                .font(.subheadline)
                .foregroundColor(ModernTheme.textSecondary)
            
            Spacer()
            
            Button {
                showingPlaylistPicker = true
            } label: {
                Label("Playlist", systemImage: "plus.app")
            }
            .disabled(selectedSongs.isEmpty)
        }
        .padding()
        .background(ModernTheme.backgroundSecondary)
        .overlay(alignment: .top) {
            Divider().background(ModernTheme.borderSubtle)
        }
        #if os(iOS)
        .padding(.bottom, player.currentSong != nil ? 80 : 0)
        #endif
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedSongs.contains(id) {
            selectedSongs.remove(id)
        } else {
            selectedSongs.insert(id)
        }
    }
    
    private func playSong(_ song: Song, in context: [Song]) {
        if let index = context.firstIndex(of: song) {
            player.playSong(song, in: context, at: index)
        }
    }
}

// MARK: - Simple Song Row
struct SimpleSongRow: View {
    let song: Song
    let isPlaying: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    
    @AppStorage("devShowFileExtensions") private var devShowFileExtensions = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? ModernTheme.accentYellow : ModernTheme.lightGray)
                    .font(.title3)
            }
            
            // Artwork
            if let artworkData = song.artworkData,
               let platformImage = PlatformImage.fromData(artworkData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ModernTheme.backgroundSecondary)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(ModernTheme.lightGray)
                    }
            }
            
            // Song Info
            VStack(alignment: .leading, spacing: 4) {
                Text((devShowFileExtensions ? song.url.lastPathComponent : song.title).normalizedForDisplay)
                    .font(ModernTheme.body())
                    .foregroundColor(isPlaying ? ModernTheme.accentYellow : .white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(song.artist.normalizedForDisplay)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Playing Indicator / Duration
            if isPlaying && !isSelectionMode {
                Image(systemName: "waveform")
                    .foregroundColor(ModernTheme.accentYellow)
                    .symbolEffect(.variableColor.iterative)
            } else if !isSelectionMode {
                Text(formatDuration(song.duration))
                    .font(.caption)
                    .foregroundColor(ModernTheme.textTertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPlaying ? ModernTheme.backgroundSecondary : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPlaying ? ModernTheme.accentYellow.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isPlaying ? ModernTheme.accentYellow.opacity(0.1) : .clear, radius: 10, x: 0, y: 5)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Empty Library View
struct EmptyLibraryView: View {
    var body: some View {
        ZStack {
            ModernTheme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(ModernTheme.lightGray)
                
                Text("No Songs")
                    .font(ModernTheme.title())
                    .foregroundColor(.white)
                
                Text("Add music files to get started")
                    .font(ModernTheme.body())
                    .foregroundColor(ModernTheme.lightGray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        SongsListView(songs: [], searchText: "")
    }
}
