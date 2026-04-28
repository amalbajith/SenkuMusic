//
//  ContentView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0

    // PERF: Decouple from 100ms timer — only re-render ContentView when these
    // coarse-grained booleans change (song starts/stops, sheet opens/closes).
    @State private var hasSong: Bool = AudioPlayerManager.shared.currentSong != nil
    @State private var isNowPlayingPresented: Bool = AudioPlayerManager.shared.isNowPlayingPresented

    var body: some View {
        ZStack(alignment: .bottom) {
            ModernTheme.backgroundPrimary.ignoresSafeArea()

            // Tab Content — crossfades on tab switch
            Group {
                switch selectedTab {
                case 0: HomeView()
                case 1: LibraryView()
                case 2: PlaylistsListView(searchText: "")
                case 3: SettingsView()
                default: LibraryView()
                }
            }
            .id(selectedTab)  // Forces SwiftUI to replace the view, enabling the transition
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 200)
            }


            VStack(spacing: 0) {
                Spacer()

                // Mini Player — driven by hasSong, not the 100ms timer
                if hasSong {
                    MiniPlayerView()
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                CustomNavbar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.keyboard)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: hasSong)
        .preferredColorScheme(.dark)
        // Sheet driven by local @State, synced via onReceive
        .sheet(isPresented: $isNowPlayingPresented, onDismiss: {
            AudioPlayerManager.shared.isNowPlayingPresented = false
        }) {
            NowPlayingView()
        }
        // Only fires when song starts/stops (~rare), not every 100ms
        .onReceive(AudioPlayerManager.shared.$currentSong) { hasSong = $0 != nil }
        // Only fires when the sheet is explicitly opened/closed
        .onReceive(AudioPlayerManager.shared.$isNowPlayingPresented) { isNowPlayingPresented = $0 }
    }
}

// MARK: - Custom Navbar
struct CustomNavbar: View {
    @Binding var selectedTab: Int
    @StateObject private var player = AudioPlayerManager.shared
    @State private var accentColor: Color = ModernTheme.textSecondary
    @Namespace private var tabNamespace
    @AppStorage("performanceProfile") private var performanceProfile: PerformanceProfile = .balanced

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            tabItem(index: 0, icon: "house.fill",           inactiveIcon: "house",              label: "HOME")
            tabItem(index: 1, icon: "music.note.list",      inactiveIcon: "music.note.list",    label: "LIBRARY")
            tabItem(index: 2, icon: "rectangle.stack.fill", inactiveIcon: "rectangle.stack",    label: "PLAYLIST")
            tabItem(index: 3, icon: "gearshape.fill",       inactiveIcon: "gearshape",          label: "SETTINGS")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(navbarBackground)
        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
        .padding(.horizontal, ModernTheme.cardPadding)
        .padding(.bottom, 12)
        .onAppear { updateAccentColor() }
        .onReceive(AudioPlayerManager.shared.$currentSong) { _ in updateAccentColor() }
    }

    @ViewBuilder
    private var navbarBackground: some View {
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
    }

    private func tabItem(index: Int, icon: String, inactiveIcon: String, label: String) -> some View {
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78, blendDuration: 0)) {
                selectedTab = index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    // Sliding pill — matchedGeometryEffect makes it glide between tabs
                    if isSelected {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [accentColor.opacity(0.92), accentColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: 52, height: 32)
                            .matchedGeometryEffect(id: "TAB_PILL", in: tabNamespace)
                    } else {
                        Capsule()
                            .fill(Color.clear)
                            .frame(width: 52, height: 32)
                    }

                    Image(systemName: isSelected ? icon : inactiveIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? ModernTheme.textPrimary : ModernTheme.textTertiary)
                        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isSelected)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }

                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .kerning(0.8)
                    .foregroundColor(isSelected ? ModernTheme.textPrimary : ModernTheme.textTertiary)
                    .animation(.easeInOut(duration: 0.18), value: isSelected)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? accentColor.opacity(0.10) : Color.clear)
                    .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isSelected)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func updateAccentColor() {
        guard let song = player.currentSong else {
            withAnimation(.easeInOut(duration: 0.25)) { accentColor = ModernTheme.textSecondary }
            return
        }
        Task {
            let color = await DominantColorExtractor.shared.extractDominantColor(for: song)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) { accentColor = color }
            }
        }
    }
}

#Preview { ContentView() }
