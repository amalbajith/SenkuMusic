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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedSongs.removeAll()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPlaylistPicker) {
            PlaylistPickerView(songIDs: Array(selectedSongs))
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
                Label("Add to Playlist", systemImage: "text.badge.plus")
            }
            .disabled(selectedSongs.isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
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
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
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
