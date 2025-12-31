//
//  NowPlayingView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
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
    
    // Developer Settings
    @AppStorage("devDisableArtworkAnimation") private var devDisableArtworkAnimation = false
    @AppStorage("devForceVibrantBackground") private var devForceVibrantBackground = false
    @AppStorage("devEnableDeviceTransfer") private var devEnableDeviceTransfer = false


    var body: some View {
        ZStack {
            // Background Gradient
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                Spacer()
                
                // Album Artwork
                albumArtwork
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Song Info
                songInfo
                    .padding(.horizontal, 24)
                
                // Progress Slider
                progressSlider
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                
                // Playback Controls
                playbackControls
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                
                // Additional Controls
                additionalControls
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
    }
    
    private var backgroundGradient: some View {
        #if os(iOS)
        let bgColor = Color(uiColor: .systemBackground)
        #else
        let bgColor = Color(nsColor: .windowBackgroundColor)
        #endif
        
        return LinearGradient(
            colors: [
                bgColor,
                (devForceVibrantBackground ? (player.isPlaying ? Color.blue : Color.purple) : artworkDominantColor).opacity(0.3),
                bgColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )

    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            if devEnableDeviceTransfer {
                Button {
                    player.isNowPlayingPresented = false // Dismiss player to show share sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowShareSheet"), object: player.currentSong)
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .padding(.leading, 12)
            }
            
            Spacer()
            
            Button {
                // Show queue
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - Album Artwork
    private var albumArtwork: some View {
        Group {
            if let song = player.currentSong,
               let artworkData = song.artworkData,
               let platformImage = PlatformImage.fromData(artworkData) {
                let size = PlatformUtils.screenWidth - 80
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .cornerRadius(20)
                    .scaleEffect(devDisableArtworkAnimation ? 1.0 : (player.isPlaying ? 1.0 : 0.9))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                let size = PlatformUtils.screenWidth - 80
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                devForceVibrantBackground ? Color.blue : Color.blue.opacity(0.6),
                                devForceVibrantBackground ? Color.purple : Color.purple.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .scaleEffect(devDisableArtworkAnimation ? 1.0 : (player.isPlaying ? 1.0 : 0.9))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }

        }
    }
    
    // MARK: - Song Info
    private var songInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(player.currentSong?.title ?? "Not Playing")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(player.currentSong?.artist ?? "Unknown Artist")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let song = player.currentSong {
                Button {
                    favoritesManager.toggleFavorite(song: song)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(song: song) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(favoritesManager.isFavorite(song: song) ? .red : .secondary)
                        .symbolEffect(.bounce, value: favoritesManager.isFavorite(song: song))
                }
            }
        }
    }
    
    // MARK: - Progress Slider
    private var progressSlider: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { draggedTime },
                    set: { newValue in
                        draggedTime = newValue
                        if !isDraggingSlider {
                            player.seek(to: newValue)
                        }
                    }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    isDraggingSlider = editing
                    if !editing {
                        player.seek(to: draggedTime)
                    }
                }
            )
            .tint(.blue)
            .onChange(of: player.currentTime) { oldValue, newValue in
                if !isDraggingSlider {
                    draggedTime = newValue
                }
            }
            
            HStack {
                Text(formatTime(isDraggingSlider ? draggedTime : player.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text(formatTime(player.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        HStack(spacing: 40) {
            // Previous
            Button {
                player.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
            }
            
            // Play/Pause
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.primary)
            }
            
            // Next
            Button {
                player.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Additional Controls
    private var additionalControls: some View {
        HStack {
            // Shuffle
            Button {
                player.toggleShuffle()
            } label: {
                Image(systemName: player.isShuffled ? "shuffle.circle.fill" : "shuffle")
                    .font(.title3)
                    .foregroundColor(player.isShuffled ? .blue : .primary)
            }
            
            Spacer()
            
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
                .font(.title3)
                .foregroundColor(player.repeatMode != .off ? .blue : .primary)
            }
        }
    }
    
    // MARK: - Helpers
    private var artworkDominantColor: Color {
        if let song = player.currentSong,
           let artworkData = song.artworkData,
           let platformImage = PlatformImage.fromData(artworkData) {
            #if os(iOS)
            return Color(platformColor: platformImage.averageColor ?? .systemGray6)
            #else
            return Color(platformColor: platformImage.averageColor ?? .windowBackgroundColor)
            #endif
        }
        return Color.blue
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NowPlayingView()
}
