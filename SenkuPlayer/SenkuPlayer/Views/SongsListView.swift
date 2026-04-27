//
//  SongsListView.swift
//  SenkuPlayer
//
//

import SwiftUI
import Combine

struct SongsListView: View {
    @StateObject private var player = AudioPlayerManager.shared
    let songs: [Song]
    let searchText: String
    
    @State private var selectedSongs: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingPlaylistPicker = false
    @AppStorage("libraryDisplayMode") private var displayMode: String = "List"

    // PERF: Cache filtered songs to avoid O(N) filter in body on every 100ms timer tick
    @State private var filteredSongs: [Song] = []
    
    var body: some View {
        ZStack {
            ModernTheme.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if songs.isEmpty {
                    EmptyLibraryView()
                } else if filteredSongs.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else {
                    contentView
                }
                
                if isSelectionMode {
                    selectionToolbar
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
            }
        }
        .onAppear { updateFilteredSongs() }
        .onChange(of: searchText) { _, _ in updateFilteredSongs() }
        .onChange(of: songs.count) { _, _ in updateFilteredSongs() }
        .toolbar {
            if !songs.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation {
                                displayMode = displayMode == "List" ? "Grid" : "List"
                            }
                        } label: {
                            Image(systemName: displayMode == "List" ? "square.grid.2x2" : "list.bullet")
                        }
                        
                        Button(isSelectionMode ? "Done" : "Select") {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedSongs.removeAll()
                            }
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
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(ModernTheme.mediumGray)
            Text("No matches for \"\(searchText)\"")
                .foregroundColor(ModernTheme.lightGray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if displayMode == "List" {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
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
                            rowContextMenu(for: song)
                        }
                    }
                }
                .padding(.horizontal, ModernTheme.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 24) {
                    ForEach(filteredSongs) { song in
                        GridSongCard(
                            song: song,
                            isPlaying: player.currentSong?.id == song.id && player.isPlaying,
                            isSelected: selectedSongs.contains(song.id),
                            isSelectionMode: isSelectionMode
                        )
                        .onTapGesture {
                            if isSelectionMode {
                                toggleSelection(song.id)
                            } else {
                                playSong(song, in: filteredSongs)
                            }
                        }
                        .contextMenu {
                            rowContextMenu(for: song)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
    }
    
    @ViewBuilder
    private func rowContextMenu(for song: Song) -> some View {
        Button {
            player.playNext(song: song)
        } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        
        Button {
            player.playMoreLikeThis(song: song, from: MusicLibraryManager.shared.songs)
        } label: {
            Label("More Like This", systemImage: "wand.and.stars")
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

    private func updateFilteredSongs() {
        if searchText.isEmpty {
            filteredSongs = songs
        } else {
            let query = searchText.lowercased()
            filteredSongs = songs.filter {
                $0.title.lowercased().contains(query) ||
                $0.artist.lowercased().contains(query) ||
                $0.album.lowercased().contains(query)
            }
        }
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
        .padding(.bottom, player.currentSong != nil ? 80 : 0)
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

// MARK: - Simple Song Row (Optimized)
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
            
            // PERF: CachedArtworkView uses background decoding
            CachedArtworkView(song: song, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text((devShowFileExtensions ? song.url.lastPathComponent : song.title).normalizedForDisplay)
                    .font(ModernTheme.body())
                    .foregroundColor(isPlaying ? ModernTheme.accentYellow : .white)
                    .lineLimit(1)
                
                Text(song.artist.normalizedForDisplay)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
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
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPlaying ? ModernTheme.backgroundSecondary.opacity(0.88) : Color.clear)
                .overlay {
                    if isPlaying {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
        )
        // PERF: Avoid shadows on all items, only for playing items if needed
        .shadow(color: isPlaying ? Color.black.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Grid Song Card (Optimized)
struct GridSongCard: View {
    let song: Song
    let isPlaying: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    
    @AppStorage("devShowFileExtensions") private var devShowFileExtensions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // PERF: Unified with CachedArtworkView
                CachedArtworkView(song: song, size: 140, cornerRadius: 12)
                
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? ModernTheme.accentYellow : .white)
                        .font(.title3)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                        .padding(8)
                }
                
                if isPlaying && !isSelectionMode {
                    Image(systemName: "waveform")
                        .foregroundColor(ModernTheme.accentYellow)
                        .symbolEffect(.variableColor.iterative)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                        .padding(8)
                }
            }
            .shadow(color: isPlaying ? ModernTheme.accentYellow.opacity(0.3) : .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text((devShowFileExtensions ? song.url.lastPathComponent : song.title).normalizedForDisplay)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isPlaying ? ModernTheme.accentYellow : .white)
                    .lineLimit(1)
                
                Text(song.artist.normalizedForDisplay)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
    }
}

struct EmptyLibraryView: View {
    var body: some View {
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
