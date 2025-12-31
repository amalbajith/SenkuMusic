//
//  SongsListView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct SongsListView: View {
    @StateObject private var player = AudioPlayerManager.shared
    let songs: [Song]
    let searchText: String
    @State private var selectedSongs: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingPlaylistPicker = false
    @State private var shareTarget: ShareTarget?
    
    struct ShareTarget: Identifiable {
        let id = UUID()
        let songs: [Song]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if songs.isEmpty {
                EmptyLibraryView()
            } else {
                List {
                    ForEach(songs) { song in
                        SongRow(
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
                                playSong(song)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                shareTarget = ShareTarget(songs: [song])
                            } label: {
                                Label("Share", systemImage: "wave.3.backward.circle.fill")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                player.playNext(song)
                            } label: {
                                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                            }
                            
                            Button {
                                player.playLater(song)
                            } label: {
                                Label("Play Last", systemImage: "text.line.last.and.arrowtriangle.forward")
                            }
                            
                            Divider()
                            
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
                        } preview: {
                            SongPreviewView(song: song)
                        }
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: player.currentSong != nil ? 80 : 0)
                }
                
                if isSelectionMode {
                    selectionToolbar
                }
            }
        }
        .toolbar {
            if !songs.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Button(isSelectionMode ? (selectedSongs.isEmpty ? "Done" : "Send") : "Select") {
                        if isSelectionMode {
                            if !selectedSongs.isEmpty {
                                let selected = songs.filter { selectedSongs.contains($0.id) }
                                shareTarget = ShareTarget(songs: selected)
                            } else {
                                isSelectionMode = false
                                selectedSongs.removeAll()
                            }
                        } else {
                            isSelectionMode = true
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
        .sheet(item: $shareTarget, onDismiss: {
            if isSelectionMode {
                isSelectionMode = false
                selectedSongs.removeAll()
            }
        }) { target in
            NavigationStack {
                NearbyShareView(songs: target.songs)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowShareSheet"))) { notification in
            if let song = notification.object as? Song {
                shareTarget = ShareTarget(songs: [song])
            }
        }
    }
    
    private var selectionToolbar: some View {
        HStack {
            Text("\(selectedSongs.count) selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                showingPlaylistPicker = true
            } label: {
                Label("Playlist", systemImage: "plus.app")
            }
            .disabled(selectedSongs.isEmpty)
        }
        .padding()
        .background(Color.gray.opacity(0.12))
        .padding(.bottom, player.currentSong != nil ? 80 : 0)
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedSongs.contains(id) {
            selectedSongs.remove(id)
        } else {
            selectedSongs.insert(id)
        }
    }
    
    private func playSong(_ song: Song) {
        if let index = songs.firstIndex(of: song) {
            player.playSong(song, in: songs, at: index)
        }
    }
}

// MARK: - Song Row
struct SongRow: View {
    let song: Song
    let isPlaying: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    
    @AppStorage("devShowFileExtensions") private var devShowFileExtensions = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
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
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    }
            }
            
            // Song Info
            VStack(alignment: .leading, spacing: 4) {
                Text(devShowFileExtensions ? song.url.lastPathComponent : song.title)
                    .font(.body)
                    .foregroundColor(isPlaying ? .blue : .primary)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            
            Spacer()
            
            // Playing Indicator
            if isPlaying && !isSelectionMode {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .symbolEffect(.variableColor.iterative)
            } else {
                Text(formatDuration(song.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


// MARK: - Song Preview View
struct SongPreviewView: View {
    let song: Song
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let artworkData = song.artworkData,
               let platformImage = PlatformImage.fromData(artworkData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 250, height: 250)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(song.album)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .padding(16)
        .background(Color(platformColor: .secondaryBackground))
    }
}

// MARK: - Empty Library View
struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Songs")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add music files to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        SongsListView(songs: [], searchText: "")
    }
}