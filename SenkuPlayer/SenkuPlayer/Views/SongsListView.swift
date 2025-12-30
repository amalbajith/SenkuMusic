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
                                shareTarget = ShareTarget(songs: [song])
                            } label: {
                                Label("Share Nearby", systemImage: "wave.3.backward.circle")
                            }
                            
                            if !isSelectionMode {
                                Button {
                                    toggleSelection(song.id)
                                    isSelectionMode = true
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                
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
        .sheet(isPresented: $showingPlaylistPicker) {
            PlaylistPickerView(songIDs: Array(selectedSongs))
        }
        .sheet(item: $shareTarget) { target in
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
                Text(song.title)
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