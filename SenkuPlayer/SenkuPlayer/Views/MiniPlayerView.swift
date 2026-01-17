//
//  MiniPlayerView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MiniPlayerView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundColor: Color = .clear
    
    private func updateBackgroundColor() {
        guard let song = player.currentSong else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let color = DominantColorExtractor.shared.extractDominantColor(for: song)
            DispatchQueue.main.async {
                withAnimation {
                    self.backgroundColor = color
                }
            }
        }
    }
    
    var body: some View {
        if let song = player.currentSong {
            ZStack(alignment: .bottom) {
                // Main Pill Container
                HStack(spacing: 12) {
                    // Artwork
                    if let artworkData = song.artworkData,
                       let platformImage = PlatformImage.fromData(artworkData) {
                        Image(platformImage: platformImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(ModernTheme.mediumGray)
                            .frame(width: 44, height: 44)
                            .cornerRadius(8)
                            .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.3)))
                    }
                    
                    // Song Info
                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.title.normalizedForDisplay)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Text("NOW PLAYING")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(ModernTheme.accentYellow)
                            
                            Text("•")
                                .foregroundColor(.white.opacity(0.3))
                                
                            Text(song.artist.normalizedForDisplay)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Play/Pause
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 8)
                    
                    // Next
                    Button {
                        AudioPlayerManager.shared.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        // Blurred background
                        BlurView(style: .systemThinMaterialDark)
                        
                        // Dynamic Tint
                        backgroundColor.opacity(0.3)
                        
                        // Glassy border
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                )
                .onAppear { updateBackgroundColor() }
                .onChange(of: player.currentSong) { _, _ in updateBackgroundColor() }
                .clipShape(RoundedRectangle(cornerRadius: 16))

            }
            .frame(height: 64)
            .padding(.horizontal, 12)
            .onTapGesture {
                player.isNowPlayingPresented = true
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 80 {
                            withAnimation(.spring()) {
                                dragOffset = 300
                                player.stop()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dragOffset = 0
                            }
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
    }
}

// MARK: - Blur View Helper
#if os(iOS)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
#else
enum BlurStyle {
    case systemThinMaterialDark
    case regular
}

struct BlurView: View {
    init(style: BlurStyle) {}
    var body: some View {
        Color.black.opacity(0.8)
            .background(.ultraThinMaterial)
    }
}
#endif

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            MiniPlayerView()
        }
    }
}
