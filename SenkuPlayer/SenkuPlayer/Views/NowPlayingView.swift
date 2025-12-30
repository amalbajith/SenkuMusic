//
//  NowPlayingView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct NowPlayingView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isDraggingSlider = false
    @State private var draggedTime: TimeInterval = 0
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    artworkDominantColor.opacity(0.3),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width - 80, height: UIScreen.main.bounds.width - 80)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: UIScreen.main.bounds.width - 80, height: UIScreen.main.bounds.width - 80)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
        }
    }
    
    // MARK: - Song Info
    private var songInfo: some View {
        VStack(spacing: 8) {
            Text(player.currentSong?.title ?? "Not Playing")
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(player.currentSong?.artist ?? "Unknown Artist")
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(1)
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
            .onChange(of: player.currentTime) { newValue in
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
           let uiImage = UIImage(data: artworkData) {
            return Color(uiImage.averageColor ?? .systemGray)
        }
        return Color.blue
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - UIImage Extension for Average Color
extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}

#Preview {
    NowPlayingView()
}
