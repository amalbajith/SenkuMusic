//
//  MiniPlayerView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import UIKit

struct MiniPlayerView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundColor: Color = .clear
    
    private func updateBackgroundColor() {
        guard let song = player.currentSong else { return }
        Task {
            let color = await DominantColorExtractor.shared.extractDominantColor(for: song)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
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
                    CachedArtworkView(song: song, size: 44, cornerRadius: 8)
                    
                    // Song Info
                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.title.normalizedForDisplay)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(ModernTheme.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Text("NOW PLAYING")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(ModernTheme.accentYellow)
                            
                            Text("•")
                                .foregroundColor(ModernTheme.textTertiary)
                                
                            Text(song.artist.normalizedForDisplay)
                                .font(.system(size: 12))
                                .foregroundColor(ModernTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Play/Pause (or Buffering spinner for cloud songs)
                    Button {
                        player.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(ModernTheme.accentGradient)
                                .frame(width: 34, height: 34)
                                .overlay { Circle().stroke(ModernTheme.borderStrong, lineWidth: 1) }
                            
                            if player.isBuffering {
                                ProgressView()
                                    .tint(ModernTheme.pureBlack)
                                    .scaleEffect(0.75)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(ModernTheme.pureBlack)
                            }
                        }
                    }
                    .disabled(player.isBuffering)
                    .padding(.trailing, ModernTheme.miniPadding)
                    
                    // Next
                    Button {
                        AudioPlayerManager.shared.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(ModernTheme.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(ModernTheme.backgroundSecondary.opacity(0.85), in: Circle())
                            .overlay {
                                Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1)
                            }
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 300
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            player.stop()
                            dragOffset = 0
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(ModernTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(ModernTheme.backgroundSecondary.opacity(0.85), in: Circle())
                            .overlay {
                                Circle().stroke(ModernTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                }
                .padding(.horizontal, ModernTheme.itemPadding)
                .padding(.vertical, ModernTheme.miniPadding)
                .background(
                    ZStack {
                        // Blurred background
                        BlurView(style: .systemThinMaterialDark)
                        
                        // Dynamic Tint
                        backgroundColor.opacity(0.3)
                        
                        // Glassy border
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ModernTheme.borderSubtle, lineWidth: 1)
                    }
                )
                .onAppear { updateBackgroundColor() }
                .onChange(of: player.currentSong) { _, _ in updateBackgroundColor() }
                .clipShape(RoundedRectangle(cornerRadius: 16))

            }
            .frame(height: 64)
            .padding(.horizontal, ModernTheme.cardPadding)
            .offset(y: dragOffset)
            .onTapGesture {
                player.isNowPlayingPresented = true
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 80 {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 300
                                player.stop()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
