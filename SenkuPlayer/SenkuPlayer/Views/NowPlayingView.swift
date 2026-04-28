//
//  NowPlayingView.swift
//  SenkuPlayer
//
//  Modern redesign with waveform visualization
//

import SwiftUI
import UIKit
import MediaPlayer

struct NowPlayingView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var backgroundColor: Color = ModernTheme.pureBlack
    @State private var showingLyrics = false
    @State private var showingSleepTimer = false
    @State private var showingQueue = false
    @State private var showingEqualizer = false
    
    // Developer Settings
    @AppStorage("performanceProfile") private var performanceProfile: PerformanceProfile = .balanced

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ── Background ────────────────────────────────────
                LinearGradient(
                    colors: [backgroundColor.opacity(0.85), ModernTheme.backgroundPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: backgroundColor)
                .overlay {
                    LinearGradient(
                        colors: [ModernTheme.pureBlack.opacity(0.15), ModernTheme.pureBlack.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: verticalSpacing(for: geometry.size.height)) {
                        NowPlayingHeader(
                            showingLyrics: $showingLyrics,
                            showingSleepTimer: $showingSleepTimer,
                            showingQueue: $showingQueue,
                            showingEqualizer: $showingEqualizer
                        )
                        .padding(.top, geometry.safeAreaInsets.top + 20)

                        albumArtwork(in: geometry.size)
                            .padding(.horizontal, ModernTheme.screenPadding + 16)

                        songInfo
                            .padding(.horizontal, ModernTheme.screenPadding + 8)

                        if performanceProfile != .eco {
                            WaveformView(
                                isPlaying: player.isPlaying,
                                progress: player.currentTime / max(player.duration, 1),
                                songURL: player.currentSong?.url,
                                onSeek: { progress in
                                    guard player.duration > 0 else { return }
                                    player.seek(to: progress * player.duration)
                                }
                            )
                            .padding(.horizontal, ModernTheme.screenPadding + 8)
                        } else {
                            // Simple progress bar fallback for Eco Mode
                            Slider(value: Binding(
                                get: { player.currentTime / max(player.duration, 1) },
                                set: { player.seek(to: $0 * player.duration) }
                            ), in: 0...1)
                            .tint(ModernTheme.accentYellow)
                            .padding(.horizontal, ModernTheme.screenPadding + 8)
                            .padding(.vertical, 20)
                        }

                        playbackControls
                            .padding(.horizontal, ModernTheme.screenPadding + 8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24) + 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: player.currentSong) { _, _ in
            updateBackgroundColor()
        }
        .onAppear {
            updateBackgroundColor()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > vertical else { return }
                    if horizontal < -50 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.playNext()
                    } else if horizontal > 50 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.playPrevious()
                    }
                }
        )
        .fullScreenCover(isPresented: $showingLyrics) {
            LyricsView()
        }
        .fullScreenCover(isPresented: $showingEqualizer) {
            EqualizerView()
        }
        .sheet(isPresented: $showingSleepTimer) {
            SleepTimerView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingQueue) {
            QueueView()
                .presentationDetents([.large])
        }
    }
    
    // MARK: - Album Artwork
    private func albumArtwork(in containerSize: CGSize) -> some View {
        Group {
            let availableWidth = max(containerSize.width - ((ModernTheme.screenPadding + 16) * 2), 160)
            let availableHeight = max(containerSize.height * 0.34, 160)
            let size = min(availableWidth, availableHeight, 320)
            
            if let song = player.currentSong {
                CachedArtworkView(song: song, size: size)
                    .shadow(color: backgroundColor.opacity(0.4), radius: 20, x: 0, y: 12)
                    .scaleEffect(player.isPlaying ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: player.isPlaying)
                    .id(song.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity
                    ))
            } else {
                ZStack {
                    ModernTheme.backgroundSecondary
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(width: size, height: size)
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Song Info
    private var songInfo: some View {
        VStack(alignment: .center, spacing: 8) {
            Text((player.currentSong?.title ?? "Not Playing").normalizedForDisplay)
                .font(ModernTheme.title())
                .foregroundColor(ModernTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.tail)
            
            Text((player.currentSong?.artist ?? "Unknown Artist").normalizedForDisplay)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.tail)

            albumMetadata
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .id(player.currentSong?.id)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .center)),
            removal: .opacity.combined(with: .scale(scale: 1.05, anchor: .center))
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: player.currentSong?.id)
    }
    
    // MARK: - Album Metadata
    private var albumMetadata: some View {
        let metadataItems = nowPlayingMetadataItems

        return Group {
            if metadataItems.isEmpty {
                EmptyView()
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(metadataItems.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Text("•")
                                .foregroundColor(ModernTheme.textTertiary)
                        }

                        Text(item)
                            .font(ModernTheme.caption())
                            .foregroundColor(ModernTheme.textTertiary)
                            .lineLimit(1)
                    }
                }
                .lineLimit(1)
            }
        }
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 0) {
                // Previous
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(ModernTheme.backgroundSecondary.opacity(0.9), in: Circle())
                        .overlay { Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1) }
                }
                .buttonStyle(PressEffect(scale: 0.90))
                .frame(maxWidth: .infinity)

                
                // Play/Pause (or Buffering for cloud songs)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        if player.isBuffering {
                            ZStack {
                                Circle()
                                    .fill(ModernTheme.accentYellow.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                ProgressView()
                                    .tint(ModernTheme.accentYellow)
                                    .scaleEffect(1.8)
                            }
                        } else {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(ModernTheme.accentGradient)
                                .shadow(color: ModernTheme.accentYellow.opacity(0.35), radius: 18, x: 0, y: 8)
                        }
                    }
                    .frame(width: 80, height: 80)
                }
                .buttonStyle(PressEffect(scale: 0.88))
                .disabled(player.isBuffering)
                .frame(maxWidth: .infinity)

                // Next
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(ModernTheme.backgroundSecondary.opacity(0.9), in: Circle())
                        .overlay { Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1) }
                }
                .buttonStyle(PressEffect(scale: 0.90))
                .frame(maxWidth: .infinity)

            }

            HStack(spacing: 0) {
                // Shuffle
                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: player.isShuffled ? "shuffle.circle.fill" : "shuffle")
                        .font(.title2)
                        .foregroundColor(player.isShuffled ? ModernTheme.accentYellow : ModernTheme.textSecondary)
                        .frame(width: 50, height: 50)
                        .background(ModernTheme.backgroundSecondary.opacity(0.7), in: Circle())
                }
                .buttonStyle(PressEffect(scale: 0.92))
                .frame(maxWidth: .infinity)

                // Lyrics
                Button {
                    showingLyrics = true
                } label: {
                    Image(systemName: "quote.bubble.fill")
                        .font(.title2)
                        .foregroundColor(ModernTheme.textSecondary)
                        .frame(width: 50, height: 50)
                        .background(ModernTheme.backgroundSecondary.opacity(0.7), in: Circle())
                }
                .buttonStyle(PressEffect(scale: 0.92))
                .frame(maxWidth: .infinity)

                Button {
                    player.toggleRepeat()
                } label: {
                    Image(systemName: player.repeatMode == .off ? "repeat" : (player.repeatMode == .one ? "repeat.1.circle.fill" : "repeat.circle.fill"))
                        .font(.title2)
                        .foregroundColor(player.repeatMode != .off ? ModernTheme.accentYellow : ModernTheme.textSecondary)
                        .frame(width: 50, height: 50)
                        .background(ModernTheme.backgroundSecondary.opacity(0.7), in: Circle())
                }
                .buttonStyle(PressEffect(scale: 0.92))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var nowPlayingMetadataItems: [String] {
        guard let song = player.currentSong else { return [] }
        var items: [String] = []
        if !song.album.isEmpty, song.album != "Unknown Album" { items.append(song.album) }
        if let year = song.year { items.append(String(year)) }
        return items
    }

    private func verticalSpacing(for height: CGFloat) -> CGFloat {
        min(max(height * 0.035, 18), 28)
    }
    
    private func updateBackgroundColor() {
        guard let song = player.currentSong else {
            backgroundColor = ModernTheme.pureBlack
            return
        }
        Task {
            let color = await DominantColorExtractor.shared.extractDominantColor(for: song)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.45)) {
                    self.backgroundColor = color
                }
            }
        }
    }
}

// MARK: - Specialized Subviews to prevent Menu re-render warnings
struct NowPlayingHeader: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player = AudioPlayerManager.shared
    @ObservedObject var favoritesManager = FavoritesManager.shared
    
    @Binding var showingLyrics: Bool
    @Binding var showingSleepTimer: Bool
    @Binding var showingQueue: Bool
    @Binding var showingEqualizer: Bool
    
    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundColor(ModernTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(ModernTheme.backgroundSecondary.opacity(0.85), in: Circle())
                    .overlay { Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1) }
            }
            
            Spacer()
            
            Text("NOW PLAYING")
                .font(.system(size: 12, weight: .black))
                .kerning(4)
                .foregroundColor(ModernTheme.textSecondary)
            
            Spacer()
            
            Menu {
                // Favorite (Moved from main row)
                Button {
                    if let song = player.currentSong {
                        favoritesManager.toggleFavorite(song: song)
                    }
                } label: {
                    let isFav = player.currentSong.map { favoritesManager.isFavorite(song: $0) } ?? false
                    Label(isFav ? "Remove from Favorites" : "Favorite", systemImage: isFav ? "heart.fill" : "heart")
                }
                
                Button { showingEqualizer = true } label: {
                    Label("Equalizer", systemImage: "slider.horizontal.3")
                }
                
                Button { showingSleepTimer = true } label: {
                    Label("Sleep Timer", systemImage: "timer")
                }
                
                Button { showingQueue = true } label: {
                    Label("Up Next", systemImage: "list.number")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(ModernTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(ModernTheme.backgroundSecondary.opacity(0.85), in: Circle())
                    .overlay { Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1) }
            }
        }
        .padding(.horizontal, ModernTheme.screenPadding)
    }
}
