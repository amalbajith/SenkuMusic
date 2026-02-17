//
//  SettingsView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingClearLibraryAlert = false
    @AppStorage("crossfadeDuration") private var crossfadeDuration: Double = 0.0
    @AppStorage("gaplessPlayback") private var gaplessPlayback: Bool = true

    // Developer Settings
    @AppStorage("devShowFileExtensions") private var devShowFileExtensions = false
    @AppStorage("devDisableArtworkAnimation") private var devDisableArtworkAnimation = false
    @AppStorage("devEnableDebugLogging") private var devEnableDebugLogging = false
    @AppStorage("devForceVibrantBackground") private var devForceVibrantBackground = false

    @State private var versionTapCount = 0
    @State private var showDeveloperSection = false

    private var canUnlockDeveloperSection: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headerSection
                        audioSection
                        librarySection
                        
                        if showDeveloperSection {
                            developerSection
                        }
                        
                        aboutSection
                    }
                    .padding(.bottom, player.currentSong != nil ? 100 : 20)
                }
            }
            .preferredColorScheme(.dark)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ModernTheme.lightGray)
                    }
                }
            }
        }
        .alert("Clear Library", isPresented: $showingClearLibraryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearLibrary()
            }
        } message: {
            Text("This will remove all songs from your library. This action cannot be undone.")
        }
        .background(ModernTheme.backgroundPrimary)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        Text("Settings")
            .font(ModernTheme.heroTitle())
            .foregroundColor(.white)
            .fontWeight(.bold)
            .padding(.horizontal, ModernTheme.screenPadding)
            .padding(.top, ModernTheme.screenPadding)
    }
    
    // MARK: - Audio & Playback (single card)
    
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio & Playback")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            VStack(spacing: 0) {
                // Equalizer
                NavigationLink(destination: EqualizerView()) {
                    groupedRow(icon: "slider.vertical.3", title: "Equalizer", showChevron: true)
                }
                .buttonStyle(.plain)
                
                groupedDivider()
                
                // Gapless Playback
                groupedToggleRow(icon: "arrow.triangle.merge", title: "Gapless Playback", isOn: $gaplessPlayback)
                
                groupedDivider()
                
                // Crossfade
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        settingsIcon("arrow.left.and.right.square.fill")
                        
                        Text("Crossfade")
                            .font(ModernTheme.body())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(crossfadeDuration == 0 ? "Off" : String(format: "%.0fs", crossfadeDuration))
                            .font(ModernTheme.body())
                            .foregroundColor(ModernTheme.lightGray)
                    }
                    
                    Slider(value: $crossfadeDuration, in: 0...12, step: 1)
                        .tint(ModernTheme.accentYellow)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .cardBackground()
            .padding(.horizontal, ModernTheme.screenPadding)
        }
    }
    
    // MARK: - Library (stats + actions in one section)
    
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            // Stats row - compact horizontal
            HStack(spacing: 0) {
                statItem(value: "\(library.songs.count)", label: "Songs")
                statDivider()
                statItem(value: "\(library.albums.count)", label: "Albums")
                statDivider()
                statItem(value: "\(library.artists.count)", label: "Artists")
                statDivider()
                statItem(value: "\(library.playlists.count)", label: "Playlists")
            }
            .padding(.vertical, 16)
            .cardBackground()
            .padding(.horizontal, ModernTheme.screenPadding)
            
            // Clear library action
            Button {
                showingClearLibraryAlert = true
            } label: {
                HStack(spacing: 12) {
                    settingsIcon("trash", color: .red)
                    
                    Text("Clear Library")
                        .font(ModernTheme.body())
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .cardBackground()
            }
            .padding(.horizontal, ModernTheme.screenPadding)
        }
    }
    
    // MARK: - Developer (hidden section)
    
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Developer")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            VStack(spacing: 0) {
                // Info
                groupedInfoRow(title: "Developer", value: "Amal B Ajith")
                
                groupedDivider()
                
                // GitHub
                Button {
                    if let url = URL(string: "https://github.com/iamalbajith"), isSafeExternalURL(url) {
                        openURL(url)
                    }
                } label: {
                    groupedRow(icon: "link", title: "GitHub", showChevron: true)
                }
                .buttonStyle(.plain)
                
                groupedDivider()
                
                // Debug header
                Text("DEBUG")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(ModernTheme.lightGray)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                
                groupedToggleRow(icon: "doc.text", title: "Show File Extensions", isOn: $devShowFileExtensions)
                groupedDivider()
                groupedToggleRow(icon: "photo", title: "Disable Artwork Animation", isOn: $devDisableArtworkAnimation)
                groupedDivider()
                groupedToggleRow(icon: "terminal", title: "Console Logging", isOn: $devEnableDebugLogging)
                groupedDivider()
                groupedToggleRow(icon: "sparkles", title: "Force Vibrant UI", isOn: $devForceVibrantBackground)
                
                groupedDivider()
                
                // Reset
                Button {
                    devShowFileExtensions = false
                    devDisableArtworkAnimation = false
                    devEnableDebugLogging = false
                    devForceVibrantBackground = false
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("arrow.counterclockwise", color: .red)
                        
                        Text("Reset Dev Settings")
                            .font(ModernTheme.body())
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .cardBackground()
            .padding(.horizontal, ModernTheme.screenPadding)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            VStack(spacing: 0) {
                Button {
                    handleVersionTap()
                } label: {
                    groupedInfoRow(title: "Version", value: "1.8.3")
                }
                .buttonStyle(.plain)
                
                groupedDivider()
                
                groupedInfoRow(title: "Build", value: "30")
            }
            .cardBackground()
            .padding(.horizontal, ModernTheme.screenPadding)
        }
    }
    
    // MARK: - Shared Components
    
    private func settingsIcon(_ name: String, color: Color = .white) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(ModernTheme.mediumGray)
            .cornerRadius(8)
    }
    
    private func groupedRow(icon: String, title: String, showChevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)
            
            Text(title)
                .font(ModernTheme.body())
                .foregroundColor(.white)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ModernTheme.lightGray.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func groupedToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)
            
            Text(title)
                .font(ModernTheme.body())
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private func groupedInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(ModernTheme.body())
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.lightGray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func groupedDivider() -> some View {
        Divider()
            .background(ModernTheme.lightGray.opacity(0.15))
            .padding(.leading, 60)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ModernTheme.lightGray)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func statDivider() -> some View {
        Rectangle()
            .fill(ModernTheme.lightGray.opacity(0.15))
            .frame(width: 1, height: 30)
    }
    
    // MARK: - Logic
    
    private func clearLibrary() {
        library.deleteAllSongs()
    }
    
    private func handleVersionTap() {
        versionTapCount += 1
        
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        
        if versionTapCount >= 7 && !showDeveloperSection && canUnlockDeveloperSection {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showDeveloperSection = true
            }
            versionTapCount = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if versionTapCount < 7 {
                versionTapCount = 0
            }
        }
    }

    private func isSafeExternalURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }
}

#Preview {
    SettingsView()
}
