//
//  NowPlayingView.swift
//  SenkuPlayer
//
//  Modern redesign with waveform visualization
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct NowPlayingView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var backgroundColor: Color = ModernTheme.pureBlack
    
    // Developer Settings
    @AppStorage("devDisableArtworkAnimation") private var devDisableArtworkAnimation = false

    var body: some View {
        ZStack {
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
            
            VStack(spacing: 0) {
                header
                    .padding(.top, 20)
                
                Spacer()
                    .frame(minHeight: 10, maxHeight: 20)
                
                // Large Album Artwork
                albumArtwork
                    .padding(.horizontal, ModernTheme.screenPadding + 16) // Extra space for large artwork
                
                Spacer()
                    .frame(minHeight: 20, maxHeight: 30)
                
                songInfo
                    .padding(.horizontal, ModernTheme.screenPadding + 8)
                
                WaveformView(
                    isPlaying: player.isPlaying,
                    progress: player.currentTime / max(player.duration, 1),
                    songURL: player.currentSong?.url
                )
                .padding(.horizontal, ModernTheme.screenPadding + 8)
                .padding(.top, 16)
                
                Spacer()
                    .frame(minHeight: 20, maxHeight: 30)
                
                playbackControls
                    .padding(.horizontal, ModernTheme.screenPadding + 16)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
        .onChange(of: player.currentSong) { _, _ in
            updateBackgroundColor()
        }
        .onAppear {
            updateBackgroundColor()
        }
        #if os(iOS)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > vertical else { return } // Must be more horizontal than vertical
                    if horizontal < -50 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.playNext()
                    } else if horizontal > 50 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.playPrevious()
                    }
                }
        )
        #endif
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundColor(ModernTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(ModernTheme.backgroundSecondary.opacity(0.85), in: Circle())
                    .overlay {
                        Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            Text("NOW PLAYING")
                .font(.system(size: 12, weight: .black))
                .kerning(4)
                .foregroundColor(ModernTheme.textSecondary)
            
            Spacer()
            
            // Buffer to keep title centered
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, ModernTheme.screenPadding)

    }
    
    // MARK: - Album Artwork
    private var albumArtwork: some View {
        Group {
            #if os(iOS)
            // Use windowScene to get screen bounds (UIScreen.main is deprecated in newer iOS versions)
            let screenWidth = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen.bounds.width ?? 390
            #else
            let screenWidth = NSScreen.main?.frame.width ?? 800
            #endif
            let size = min(screenWidth - 100, 300)
            
            if let song = player.currentSong,
               let artworkData = song.artworkData,
               let platformImage = PlatformImage.fromData(artworkData) {
                
                ArtworkView(platformImage: platformImage, size: size, glowingColor: backgroundColor)
                    .scaleEffect(devDisableArtworkAnimation ? 1.0 : (player.isPlaying ? 1.0 : 0.8))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: player.isPlaying)
                    .id(song.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity
                    ))
            } else {
                // Fallback
                ArtworkView(platformImage: nil, size: size, glowingColor: ModernTheme.accentYellow)
                    .scaleEffect(devDisableArtworkAnimation ? 1.0 : (player.isPlaying ? 1.0 : 0.8))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: player.isPlaying)
            }
        }
    }
    
    // MARK: - Artwork Component
    struct ArtworkView: View {
        let platformImage: PlatformImage?
        let size: CGFloat
        let glowingColor: Color
        
        var body: some View {
            Group {
                if let image = platformImage {
                    Image(platformImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Fallback visual
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .frame(width: size, height: size)
            .cornerRadius(16)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ModernTheme.borderSubtle, lineWidth: 1)
            }
            // Dynamic colored shadow
            .shadow(color: glowingColor.opacity(0.5), radius: 25, x: 0, y: 12)
            // Depth shadow
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 6)
        }
    }
    
    // MARK: - Song Info
    private var songInfo: some View {
        VStack(alignment: .center, spacing: 8) {
            Text((player.currentSong?.title ?? "Not Playing").normalizedForDisplay)
                .font(ModernTheme.title())
                .foregroundColor(ModernTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Text((player.currentSong?.artist ?? "Unknown Artist").normalizedForDisplay)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textSecondary)
                .lineLimit(1)
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
        HStack(spacing: 8) {
            if let album = player.currentSong?.album, !album.isEmpty {
                Text(album)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textTertiary)
                
                Text("•")
                    .foregroundColor(ModernTheme.textTertiary)
            }
        }
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        VStack(spacing: 24) {
            // Main controls: Previous, Play/Pause, Next
            HStack(spacing: 40) {
                // Previous
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    player.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(ModernTheme.backgroundSecondary.opacity(0.9), in: Circle())
                        .overlay {
                            Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
                
                // Play/Pause - The Star Button
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(ModernTheme.accentGradient)
                        .shadow(color: ModernTheme.accentYellow.opacity(0.35), radius: 18, x: 0, y: 8)
                        .contentShape(Circle())
                }
                
                // Next
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(ModernTheme.backgroundSecondary.opacity(0.9), in: Circle())
                        .overlay {
                            Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
            }
            
            // Secondary controls: Shuffle, Heart, Repeat
            HStack(spacing: 60) {
                // Shuffle
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    player.toggleShuffle()
                } label: {
                    Image(systemName: player.isShuffled ? "shuffle.circle.fill" : "shuffle")
                        .font(.title2)
                        .foregroundColor(player.isShuffled ? ModernTheme.accentYellow : ModernTheme.textSecondary)
                        .frame(width: 50, height: 50)
                        .background(ModernTheme.backgroundSecondary.opacity(0.7), in: Circle())
                        .symbolEffect(.bounce, value: player.isShuffled)
                }
                
                // Heart (Favorite)
                if let song = player.currentSong {
                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        favoritesManager.toggleFavorite(song: song)
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(song: song) ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(favoritesManager.isFavorite(song: song) ? ModernTheme.accentYellow : ModernTheme.textSecondary)
                            .frame(width: 50, height: 50)
                            .background(ModernTheme.backgroundSecondary.opacity(0.7), in: Circle())
                            .symbolEffect(.bounce, value: favoritesManager.isFavorite(song: song))
                    }
                }
                
                // Repeat
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    player.toggleRepeat()
                } label: {
                    Group {
                        switch player.repeatMode {
                        case .off:
                            Image(systemName: "repeat")
                        case .all:
                            Image(systemName: "repeat.circle.fill")
                        case .one:
                            Image(systemName: "repeat.1.circle.fill")
                        }
                    }
                    .font(.title2)
                    .foregroundColor(player.repeatMode != .off ? ModernTheme.accentYellow : ModernTheme.textSecondary)
                    .frame(width: 50, height: 50)
                    .background(ModernTheme.backgroundSecondary.opacity(0.7), in: Circle())
                    .symbolEffect(.bounce, value: player.repeatMode)
                }
            }
        }
    }
    
    private func updateBackgroundColor() {
        guard let song = player.currentSong else {
            backgroundColor = ModernTheme.pureBlack
            return
        }
        
        // Extract color on background to avoid stutter
        DispatchQueue.global(qos: .userInitiated).async {
            let color = DominantColorExtractor.shared.extractDominantColor(for: song)
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.45)) {
                    self.backgroundColor = color
                }
            }
        }
    }
}

#Preview {
    NowPlayingView()
}
