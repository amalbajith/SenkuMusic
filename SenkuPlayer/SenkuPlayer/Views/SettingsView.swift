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
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        audioSection
                        libraryStatsSection
                        actionsSection
                        
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
            Button("Clear", role: .destructive) {
                clearLibrary()
            }
        } message: {
            Text("This will remove all songs from your library. This action cannot be undone.")
        }
        .background(ModernTheme.backgroundPrimary)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        Text("Settings")
            .font(ModernTheme.heroTitle())
            .foregroundColor(.white)
            .fontWeight(.bold)
            .padding(.horizontal, ModernTheme.screenPadding)
            .padding(.top, ModernTheme.screenPadding)
    }
    

    
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio & Playback")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            VStack(spacing: 12) {
                NavigationLink(destination: EqualizerView()) {
                    SettingsNavigationRow(
                        icon: "slider.vertical.3",
                        iconColor: .white,
                        title: "Equalizer"
                    )
                }
                .buttonStyle(.plain)
                

                SettingsToggleRow(
                    icon: "arrow.triangle.merge",
                    iconColor: .white,
                    title: "Gapless Playback",
                    isOn: $gaplessPlayback
                )
                
                SettingsSliderRow(
                    icon: "arrow.left.and.right.square.fill",
                    iconColor: .white,
                    title: "Crossfade",
                    value: $crossfadeDuration,
                    range: 0...12,
                    step: 1,
                    valueFormatter: { value in
                        value == 0 ? "Off" : String(format: "%.1fs", value)
                    }
                )
            }
            .padding(.horizontal, ModernTheme.screenPadding)
        }
    }
    
    private var libraryStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Library Statistics")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            HStack(spacing: 12) {
                VStack(spacing: 12) {
                    statBox(title: "Songs", value: "\(library.songs.count)")
                    statBox(title: "Artists", value: "\(library.artists.count)")
                }
                VStack(spacing: 12) {
                    statBox(title: "Albums", value: "\(library.albums.count)")
                    statBox(title: "Playlists", value: "\(library.playlists.count)")
                }
            }
            .padding(.horizontal, ModernTheme.screenPadding)
        }
    }
    
    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(ModernTheme.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ModernTheme.cardPadding)
        .cardBackground()
    }
    

    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            Button {
                showingClearLibraryAlert = true
            } label: {
                SettingsActionRow(
                    icon: "trash",
                    iconColor: .red,
                    title: "Clear Library",
                    isDestructive: true
                )
            }
            .padding(.horizontal, ModernTheme.screenPadding)
        }
    }
    
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Developer")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            VStack(spacing: 12) {
                SettingsInfoRow(title: "Developer", value: "Amal B Ajith")
                
                Button {
                    if let url = URL(string: "https://github.com/iamalbajith"), isSafeExternalURL(url) {
                        openURL(url)
                    }
                } label: {
                    SettingsNavigationRow(
                        icon: "link",
                        iconColor: .white,
                        title: "GitHub"
                    )
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(ModernTheme.lightGray.opacity(0.3))
                    .padding(.vertical, ModernTheme.miniPadding)
                
                Text("DEBUG FEATURES")
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.lightGray)
                    .fontWeight(.bold)
                    .padding(.horizontal, ModernTheme.cardPadding)
                
                SettingsToggleRow(icon: "doc.text", iconColor: .white, title: "Show File Extensions", isOn: $devShowFileExtensions)
                SettingsToggleRow(icon: "photo", iconColor: .white, title: "Disable Artwork Animation", isOn: $devDisableArtworkAnimation)
                SettingsToggleRow(icon: "terminal", iconColor: .white, title: "Enable Console Logging", isOn: $devEnableDebugLogging)
                SettingsToggleRow(icon: "sparkles", iconColor: .white, title: "Force Vibrant UI", isOn: $devForceVibrantBackground)
                
                Divider()
                    .background(ModernTheme.lightGray.opacity(0.3))
                    .padding(.vertical, ModernTheme.miniPadding)
                
                Text("EXPERIMENTAL FEATURES")
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.lightGray)
                    .fontWeight(.bold)
                    .padding(.horizontal, ModernTheme.cardPadding)
                
                Button {
                    devShowFileExtensions = false
                    devDisableArtworkAnimation = false
                    devEnableDebugLogging = false
                    devForceVibrantBackground = false
                } label: {
                    SettingsActionRow(
                        icon: "arrow.counterclockwise",
                        iconColor: .red,
                        title: "Reset Dev Settings",
                        isDestructive: true
                    )
                }
            }
            .padding(.horizontal, ModernTheme.screenPadding)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .sectionHeaderStyle()
                .padding(.horizontal, ModernTheme.screenPadding)
            
            VStack(spacing: 12) {
                Button {
                    handleVersionTap()
                } label: {
                    SettingsInfoRow(title: "Version", value: "1.8.0")
                }
                .buttonStyle(.plain)
                
                SettingsInfoRow(title: "Build", value: "25")
            }
            .padding(.horizontal, ModernTheme.screenPadding)
        }
    }
    
    private func clearLibrary() {
        library.deleteAllSongs()
    }
    
    private func handleVersionTap() {
        versionTapCount += 1
        
        // Haptic feedback
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
        
        // Show password prompt after 7 taps
        if versionTapCount >= 7 && !showDeveloperSection && canUnlockDeveloperSection {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showDeveloperSection = true
            }
            versionTapCount = 0
        }
        
        // Reset counter after 2 seconds of inactivity
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

// MARK: - Settings Row Components

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(ModernTheme.mediumGray)
                .cornerRadius(ModernTheme.smallRadius)
            
            Text(title)
                .font(ModernTheme.body())
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(ModernTheme.cardPadding)
        .cardBackground()
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(ModernTheme.mediumGray)
                .cornerRadius(ModernTheme.smallRadius)
            
            Text(title)
                .font(ModernTheme.body())
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ModernTheme.lightGray)
        }
        .padding(ModernTheme.cardPadding)
        .cardBackground()
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(ModernTheme.body())
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.lightGray)
        }
        .padding(16)
        .cardBackground()
    }
}

struct SettingsActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let isDestructive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(ModernTheme.mediumGray)
                .cornerRadius(ModernTheme.smallRadius)
            
            Text(title)
                .font(ModernTheme.body())
                .foregroundColor(isDestructive ? .red : .white)
            
            Spacer()
        }
        .padding(16)
        .cardBackground()
    }
}

struct SettingsSliderRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
                    .frame(width: 44, height: 44)
                    .background(ModernTheme.mediumGray)
                    .cornerRadius(ModernTheme.smallRadius)
                
                Text(title)
                    .font(ModernTheme.body())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(valueFormatter(value))
                    .font(ModernTheme.body())
                    .foregroundColor(ModernTheme.lightGray)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(ModernTheme.accentYellow)
        }
        .padding(16)
        .cardBackground()
    }
}

#Preview {
    SettingsView()
}
