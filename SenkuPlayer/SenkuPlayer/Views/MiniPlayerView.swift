//
//  MiniPlayerView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct MiniPlayerView: View {
    @StateObject private var player = AudioPlayerManager.shared
    
    var body: some View {
        if player.currentSong != nil {
            VStack(spacing: 0) {
                // Progress Bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(player.currentTime / max(player.duration, 1)))
                }
                .frame(height: 2)
                
                // Mini Player Content
                HStack(spacing: 12) {
                    // Artwork
                    if let artworkData = player.currentSong?.artworkData,
                       let platformImage = PlatformImage.fromData(artworkData) {
                        Image(platformImage: platformImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundColor(.white)
                            }
                    }
                    
                    // Song Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.currentSong?.title ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(player.currentSong?.artist ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Previous Button
                    Button {
                        player.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }

                    // Play/Pause Button
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                    
                    // Next Button
                    Button {
                        player.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .contentShape(Rectangle())
                .onTapGesture {
                    player.isNowPlayingPresented = true
                }

            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .sheet(isPresented: $player.isNowPlayingPresented) {
                NowPlayingView()
            }
            .cornerRadius(35)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 60) // Float above TabBar
        }
    }
}

#Preview {
    VStack {
        Spacer()
        MiniPlayerView()
    }
}
