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
    @State private var isDraggingSlider = false
    @State private var draggedTime: TimeInterval = 0
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var backgroundColor: Color = ModernTheme.pureBlack
    
    // Developer Settings
    @AppStorage("devDisableArtworkAnimation") private var devDisableArtworkAnimation = false
    @AppStorage("devForceVibrantBackground") private var devForceVibrantBackground = false
    @AppStorage("devEnableDeviceTransfer") private var devEnableDeviceTransfer = false

    var body: some View {
        ZStack {
            // Solid Black Background for BW Theme
            // Dynamic Background Gradient
            LinearGradient(
                colors: [backgroundColor, ModernTheme.pureBlack],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.linear(duration: 0.5), value: backgroundColor)
            
            VStack(spacing: 0) {
                // Header with back button
                header
                    .padding(.top, 8)
                
                Spacer()
                    .frame(minHeight: 10, maxHeight: 20)
                
                // Large Album Artwork
                albumArtwork
                    .padding(.horizontal, 40)
                
                Spacer()
                    .frame(minHeight: 20, maxHeight: 30)
                
                // Song Info
                songInfo
                    .padding(.horizontal, 32)
                
                // Waveform Visualization
                WaveformView(
                    isPlaying: player.isPlaying,
                    progress: player.currentTime / max(player.duration, 1),
                    songURL: player.currentSong?.url
                )
                .padding(.horizontal, 32)
                .padding(.top, 16)
                
                Spacer()
                    .frame(minHeight: 20, maxHeight: 30)
                
                // Playback Controls
                playbackControls
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
        .onChange(of: player.currentSong) { oldValue, newValue in
            updateBackgroundColor()
        }
        .onAppear {
            updateBackgroundColor()
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .glassmorphism(cornerRadius: 22)
            }
            
            Spacer()
            
            Text("NOW PLAYING")
                .font(.system(size: 12, weight: .black))
                .kerning(4)
                .foregroundColor(ModernTheme.lightGray)
            
            Spacer()
            
            if devEnableDeviceTransfer {
                Button {
                    player.showingShareRadar = true
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .glassmorphism(cornerRadius: 22)
                }
            } else {
                // Buffer to keep title centered
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $player.showingShareRadar) {
            if let song = player.currentSong {
                NearbyShareView(songs: [song])
            }
        }
    }
    
    // MARK: - Album Artwork
    private var albumArtwork: some View {
        Group {
            if let song = player.currentSong,
               let artworkData = song.artworkData,
               let platformImage = PlatformImage.fromData(artworkData) {
                #if os(iOS)
                let screenWidth = UIScreen.main.bounds.width
                #else
                let screenWidth = NSScreen.main?.frame.width ?? 800
                #endif
                let size = min(screenWidth - 100, 260)
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .cornerRadius(ModernTheme.cardRadius)
                    .shadow(
                        color: ModernTheme.cardShadow.color,
                        radius: ModernTheme.cardShadow.radius,
                        x: ModernTheme.cardShadow.x,
                        y: ModernTheme.cardShadow.y
                    )
                    .scaleEffect(devDisableArtworkAnimation ? 1.0 : (player.isPlaying ? 1.0 : 0.95))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
            } else {
                #if os(iOS)
                let screenWidth = UIScreen.main.bounds.width
                #else
                let screenWidth = NSScreen.main?.frame.width ?? 800
                #endif
                let size = min(screenWidth - 100, 260)
                RoundedRectangle(cornerRadius: ModernTheme.cardRadius)
                    .fill(ModernTheme.cardGradient)
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .shadow(
                        color: ModernTheme.cardShadow.color,
                        radius: ModernTheme.cardShadow.radius,
                        x: ModernTheme.cardShadow.x,
                        y: ModernTheme.cardShadow.y
                    )
                    .scaleEffect(devDisableArtworkAnimation ? 1.0 : (player.isPlaying ? 1.0 : 0.95))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
            }
        }
    }
    
    // MARK: - Song Info
    private var songInfo: some View {
        VStack(alignment: .center, spacing: 8) {
            Text((player.currentSong?.title ?? "Not Playing").normalizedForDisplay)
                .font(ModernTheme.title())
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Text((player.currentSong?.artist ?? "Unknown Artist").normalizedForDisplay)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.lightGray)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Album Metadata
    private var albumMetadata: some View {
        HStack(spacing: 8) {
            if let album = player.currentSong?.album, !album.isEmpty {
                Text(album)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.lightGray)
                
                Text("•")
                    .foregroundColor(ModernTheme.lightGray)
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
                    player.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(ModernTheme.mediumGray)
                        .clipShape(Circle())
                }
                
                // Play/Pause - The Star Button
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(ModernTheme.pureBlack)
                        .frame(width: 80, height: 80)
                        .background(ModernTheme.accentYellow)
                        .clipShape(Circle())
                        .shadow(
                            color: ModernTheme.accentYellow.opacity(0.5),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                }
                
                // Next
                Button {
                    player.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(ModernTheme.mediumGray)
                        .clipShape(Circle())
                }
            }
            
            // Secondary controls: Shuffle, Heart, Repeat
            HStack(spacing: 60) {
                // Shuffle
                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: player.isShuffled ? "shuffle.circle.fill" : "shuffle")
                        .font(.title2)
                        .foregroundColor(player.isShuffled ? ModernTheme.accentYellow : ModernTheme.lightGray)
                        .frame(width: 50, height: 50)
                }
                
                // Heart (Favorite)
                if let song = player.currentSong {
                    Button {
                        favoritesManager.toggleFavorite(song: song)
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(song: song) ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(favoritesManager.isFavorite(song: song) ? ModernTheme.accentYellow : ModernTheme.lightGray)
                            .frame(width: 50, height: 50)
                            .symbolEffect(.bounce, value: favoritesManager.isFavorite(song: song))
                    }
                }
                
                // Repeat
                Button {
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
                    .foregroundColor(player.repeatMode != .off ? ModernTheme.accentYellow : ModernTheme.lightGray)
                    .frame(width: 50, height: 50)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
                self.backgroundColor = color
            }
        }
    }
}

#Preview {
    NowPlayingView()
}
