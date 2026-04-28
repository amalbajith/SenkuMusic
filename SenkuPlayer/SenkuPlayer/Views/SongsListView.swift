//
//  SongsListView.swift
//  SenkuPlayer
//
//

import SwiftUI
import Combine

struct SongsListView: View {
    let songs: [Song]
    let searchText: String
    
    @State private var selectedSongs: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingPlaylistPicker = false
    @AppStorage("libraryDisplayMode") private var displayMode: String = "List"
    
    // PERF: Observe only coarse-grained player state, not the 100ms currentTime timer
    @State private var currentSongId: UUID? = AudioPlayerManager.shared.currentSong?.id
    @State private var isPlaying: Bool = AudioPlayerManager.shared.isPlaying
    @State private var hasSong: Bool = AudioPlayerManager.shared.currentSong != nil
    
    // PERF: Cache filtered songs to avoid O(N) filter in body on every render
    @State private var filteredSongs: [Song] = []
    @State private var cloudResults: [CloudSearchResult] = []
    @State private var isSearchingCloud = false
    @State private var cloudError: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        ZStack {
            ModernTheme.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        
                        // ── SECTION 1: LOCAL LIBRARY ──────────────────────
                        if !filteredSongs.isEmpty {
                            Section(header: sectionHeader("In Library")) {
                                if displayMode == "List" {
                                    ForEach(filteredSongs) { song in
                                        Button {
                                            if isSelectionMode {
                                                toggleSelection(song.id)
                                            } else {
                                                playSong(song, in: filteredSongs)
                                            }
                                        } label: {
                                            SimpleSongRow(song: song, isPlaying: isPlaying && currentSongId == song.id, isSelected: selectedSongs.contains(song.id), isSelectionMode: isSelectionMode)
                                                .contentShape(Rectangle())
                                        }
                                    }
                                } else {
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                        ForEach(filteredSongs) { song in
                                            GridSongCard(song: song, isPlaying: isPlaying && currentSongId == song.id, isSelected: selectedSongs.contains(song.id), isSelectionMode: isSelectionMode)
                                                .onTapGesture {
                                                    if isSelectionMode {
                                                        toggleSelection(song.id)
                                                    } else {
                                                        playSong(song, in: filteredSongs)
                                                    }
                                                }
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        
                        // ── SECTION 2: CLOUD DISCOVERY ────────────────────
                        if !searchText.isEmpty {
                            Section(header: sectionHeader("From the Cloud")) {
                                if isSearchingCloud {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 8) {
                                            ProgressView()
                                                .tint(ModernTheme.accentYellow)
                                            Text("Searching the web…")
                                                .font(ModernTheme.caption())
                                                .foregroundColor(ModernTheme.textSecondary)
                                        }
                                        .padding(.vertical, 40)
                                        Spacer()
                                    }
                                } else if let err = cloudError {
                                    VStack(spacing: 12) {
                                        Image(systemName: "wifi.exclamationmark")
                                            .font(.title)
                                            .foregroundColor(ModernTheme.textSecondary.opacity(0.5))
                                        Text(err)
                                            .font(ModernTheme.caption())
                                            .foregroundColor(ModernTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                        Button {
                                            cloudError = nil
                                            Task {
                                                await CloudDiscoveryService.shared.resetCache()
                                                await MainActor.run { updateFilteredSongs() }
                                            }
                                        } label: {
                                            Text("Retry")
                                                .font(ModernTheme.caption().bold())
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 8)
                                                .background(ModernTheme.accentYellow)
                                                .cornerRadius(20)
                                        }
                                    }
                                    .padding(.vertical, 40)
                                } else if cloudResults.isEmpty {
                                    // Still searching or genuinely empty — show nothing
                                    EmptyView()
                                } else {
                                    ForEach(cloudResults) { result in
                                        CloudResultRow(result: result)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        
                        Color.clear.frame(height: 100)
                    }
                }
                .onChange(of: searchText) { _, _ in updateFilteredSongs() }
                
                if isSelectionMode {
                    selectionToolbar
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: hasSong ? 80 : 0)
            }
        }
        .onAppear { updateFilteredSongs() }
        .onChange(of: searchText) { _, _ in updateFilteredSongs() }
        .onChange(of: songs.count) { _, _ in updateFilteredSongs() }
        .onReceive(AudioPlayerManager.shared.$currentSong) { song in
            currentSongId = song?.id
            hasSong = song != nil
        }
        .onReceive(AudioPlayerManager.shared.$isPlaying) { isPlaying = $0 }
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
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(ModernTheme.textSecondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No matches for \"\(searchText)\"")
                    .font(ModernTheme.body().bold())
                    .foregroundColor(ModernTheme.textPrimary)
                
                Text("Check your local library or try searching the web")
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if displayMode == "List" {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
                        Button {
                            if isSelectionMode {
                                toggleSelection(song.id)
                            } else {
                                playSong(song, in: filteredSongs)
                            }
                        } label: {
                            SimpleSongRow(
                                song: song,
                                isPlaying: currentSongId == song.id && isPlaying,
                                isSelected: selectedSongs.contains(song.id),
                                isSelectionMode: isSelectionMode
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressEffect(scale: 0.97))
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
                            isPlaying: currentSongId == song.id && isPlaying,
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
            AudioPlayerManager.shared.playNext(song: song)
        } label: {
            Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        
        Button {
            AudioPlayerManager.shared.playMoreLikeThis(song: song, from: MusicLibraryManager.shared.songs)
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
        .padding(.bottom, hasSong ? 80 : 0)
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
            AudioPlayerManager.shared.playSong(song, in: context, at: index)
        }
    }
    
    // ── HELPERS ───────────────────────────────────────
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(ModernTheme.accentYellow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(ModernTheme.backgroundPrimary)
                    .overlay(alignment: .bottom) {
                        Divider().background(Color.white.opacity(0.05))
                    }
            )
    }
    
    private func updateFilteredSongs() {
        if searchText.isEmpty {
            filteredSongs = songs
            cloudResults = []
            cloudError = nil
        } else {
            filteredSongs = songs.filter { song in
                song.title.lowercased().contains(searchText.lowercased()) ||
                song.artist.lowercased().contains(searchText.lowercased()) ||
                song.album.lowercased().contains(searchText.lowercased())
            }
            
            // Trigger Cloud Search with debounce
            searchTask?.cancel()
            cloudError = nil
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s debounce
                guard !Task.isCancelled else { return }
                
                await MainActor.run { isSearchingCloud = true }
                do {
                    let results = try await CloudDiscoveryService.shared.search(query: searchText)
                    await MainActor.run {
                        self.cloudResults = results
                        self.isSearchingCloud = false
                        // If 0 results came back, show a friendly message
                        if results.isEmpty {
                            self.cloudError = "No results found for \"\(self.searchText)\""
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isSearchingCloud = false
                        self.cloudResults = []
                        self.cloudError = error.localizedDescription
                    }
                }
            }
        }
    }
    
}

// MARK: - Simple Song Row (used across multiple views)
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
            .conditionalShadow(condition: isPlaying, color: .black.opacity(0.2), radius: 8, y: 4)
        }
        
        private func formatDuration(_ duration: TimeInterval) -> String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

// MARK: - Grid Song Card (used in grid layout)
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

// MARK: - Empty Library View (shared across Albums, Artists, Songs tabs)
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
