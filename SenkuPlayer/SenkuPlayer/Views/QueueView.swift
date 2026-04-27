//
//  QueueView.swift
//  SenkuPlayer
//
//  Live playback queue with reorder and remove — accessible from NowPlayingView.
//

import SwiftUI

struct QueueView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.ignoresSafeArea()

                if player.queue.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 52))
                            .foregroundColor(ModernTheme.lightGray)
                        Text("Queue is Empty")
                            .font(ModernTheme.title())
                            .foregroundColor(.white)
                        Text("Start playing music to build a queue.")
                            .font(ModernTheme.body())
                            .foregroundColor(ModernTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Currently playing section
                        if let current = player.currentSong {
                            Section {
                                nowPlayingRow(current)
                                    .listRowBackground(ModernTheme.accentYellow.opacity(0.08))
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            } header: {
                                Text("NOW PLAYING")
                                    .font(.system(size: 10, weight: .black))
                                    .kerning(2)
                                    .foregroundColor(ModernTheme.accentYellow)
                            }
                        }

                        // Up next
                        let upNext = Array(player.queue.dropFirst(player.currentIndex + 1))
                        if !upNext.isEmpty {
                            Section {
                                ForEach(Array(upNext.enumerated()), id: \.element.id) { offset, song in
                                    queueRow(song: song, queueOffset: player.currentIndex + 1 + offset)
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                                .onMove { from, to in
                                    moveItems(from: from, to: to, in: upNext)
                                }
                                .onDelete { offsets in
                                    deleteItems(offsets: offsets, in: upNext)
                                }
                            } header: {
                                Text("UP NEXT — \(upNext.count) songs")
                                    .font(.system(size: 10, weight: .black))
                                    .kerning(2)
                                    .foregroundColor(ModernTheme.textSecondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(.active)) // Always show drag handles
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ModernTheme.accentYellow)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if player.queue.count > player.currentIndex + 1 {
                        Button {
                            clearUpNext()
                        } label: {
                            Text("Clear")
                                .foregroundColor(ModernTheme.danger)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Row Views

    private func nowPlayingRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            SongArtworkThumbnail(song: song, size: 48, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title.normalizedForDisplay)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernTheme.accentYellow)
                    .lineLimit(1)
                Text(song.artist.normalizedForDisplay)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Equaliser animation
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ModernTheme.accentYellow)
                        .frame(width: 3, height: player.isPlaying ? CGFloat.random(in: 8...18) : 6)
                        .animation(
                            player.isPlaying
                            ? .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.12)
                            : .default,
                            value: player.isPlaying
                        )
                }
            }
            .frame(width: 16)
        }
        .padding(.vertical, 4)
    }

    private func queueRow(song: Song, queueOffset: Int) -> some View {
        HStack(spacing: 12) {
            SongArtworkThumbnail(song: song, size: 44, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title.normalizedForDisplay)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernTheme.textPrimary)
                    .lineLimit(1)
                Text(song.artist.normalizedForDisplay)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            player.playSong(song, in: player.queue, at: queueOffset)
        }
    }

    // MARK: - Queue Mutations

    private func moveItems(from source: IndexSet, to destination: Int, in upNext: [Song]) {
        // Map relative indices back to absolute queue indices
        let base = player.currentIndex + 1
        var q = player.queue
        let absoluteSource = IndexSet(source.map { $0 + base })
        let absoluteDest = destination + base
        q.move(fromOffsets: absoluteSource, toOffset: absoluteDest)
        player.queue = q
    }

    private func deleteItems(offsets: IndexSet, in upNext: [Song]) {
        let base = player.currentIndex + 1
        var q = player.queue
        let absoluteOffsets = IndexSet(offsets.map { $0 + base })
        q.remove(atOffsets: absoluteOffsets)
        player.queue = q
    }

    private func clearUpNext() {
        let upToAndIncludingCurrent = Array(player.queue.prefix(player.currentIndex + 1))
        player.queue = upToAndIncludingCurrent
    }
}
