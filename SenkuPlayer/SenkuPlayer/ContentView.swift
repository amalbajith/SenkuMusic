//
//  ContentView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            ModernTheme.backgroundPrimary.ignoresSafeArea()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    LibraryView()
                case 2:
                    PlaylistsListView(searchText: "")
                case 3:
                    SettingsView()
                default:
                    LibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 200)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Mini Player (Only if a song is playing)
                if player.currentSong != nil {
                    MiniPlayerView()
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Modern Navbar
                CustomNavbar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: player.currentSong != nil)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $player.isNowPlayingPresented) {
            NowPlayingView()
        }
    }
}

// MARK: - Components for iOS
struct CustomNavbar: View {
    @Binding var selectedTab: Int
    @StateObject private var player = AudioPlayerManager.shared
    @State private var accentColor: Color = ModernTheme.textSecondary
    
    @AppStorage("performanceProfile") private var performanceProfile: PerformanceProfile = .balanced
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            tabItem(index: 0, icon: "house.fill", inactiveIcon: "house", label: "HOME")
            tabItem(index: 1, icon: "music.note.list", inactiveIcon: "music.note.list", label: "LIBRARY")
            tabItem(index: 2, icon: "rectangle.stack.fill", inactiveIcon: "rectangle.stack", label: "PLAYLIST")
            tabItem(index: 3, icon: "gearshape.fill", inactiveIcon: "gearshape", label: "SETTINGS")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            ZStack {
                if performanceProfile != .eco {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(.clear)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
                }
                
                RoundedRectangle(cornerRadius: 26)
                    .fill(ModernTheme.backgroundSecondary.opacity(performanceProfile == .eco ? 0.98 : 0.82))

                RoundedRectangle(cornerRadius: 26)
                    .stroke(ModernTheme.borderSubtle.opacity(0.8), lineWidth: 0.5)
            }
        )
        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
        .padding(.horizontal, ModernTheme.cardPadding)
        .padding(.bottom, 12)
        .onAppear {
            updateAccentColor()
        }
        .onChange(of: player.currentSong) { _, _ in
            updateAccentColor()
        }
    }
    
    private func tabItem(index: Int, icon: String, inactiveIcon: String, label: String) -> some View {
        let isSelected = selectedTab == index

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Capsule()
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [accentColor.opacity(0.92), accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 52, height: 32)
                        .opacity(isSelected ? 1 : 0)

                    Image(systemName: isSelected ? icon : inactiveIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? ModernTheme.textPrimary : ModernTheme.textTertiary)
                }

                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .kerning(0.8)
            }
            .foregroundColor(isSelected ? ModernTheme.textPrimary : ModernTheme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? accentColor.opacity(0.12) : Color.white.opacity(0.01))
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func updateAccentColor() {
        guard let song = player.currentSong else {
            accentColor = ModernTheme.textSecondary
            return
        }

        Task {
            let extractedColor = await DominantColorExtractor.shared.extractDominantColor(for: song)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    accentColor = extractedColor
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
