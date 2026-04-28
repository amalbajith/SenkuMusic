//
//  SettingsView.swift
//  SenkuPlayer
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player  = AudioPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL)  private var openURL

    @State private var showingClearLibraryAlert = false
    @AppStorage("crossfadeDuration") private var crossfadeDuration: Double = 0.0
    @AppStorage("gaplessPlayback")   private var gaplessPlayback: Bool     = true
    @AppStorage("performanceProfile") private var performanceProfile: PerformanceProfile = .balanced
    @AppStorage("volumeNormalization") private var volumeNormalization: Bool = true
    @AppStorage("autoPlayOnBluetooth") private var autoPlayOnBluetooth: Bool = false
    @AppStorage("bluetoothCarName") private var bluetoothCarName: String = ""

    @AppStorage("devBypassArtworkCache")   private var devBypassArtworkCache   = false
    @AppStorage("devSimulateNetworkDelay") private var devSimulateNetworkDelay = false
    @AppStorage("devShowAudioMetrics")     private var devShowAudioMetrics     = false

    @State private var versionTapCount      = 0
    @State private var showDeveloperSection = false
    @State private var isExporting          = false
    @State private var showingRestorePicker = false
    @State private var exportURL: URL?      = nil
    @State private var showingShareSheet    = false

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
                ModernTheme.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 36) {

                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Settings")
                                .font(ModernTheme.heroTitle())
                                .foregroundColor(ModernTheme.textPrimary)
                            Text("Playback & preferences")
                                .font(ModernTheme.body())
                                .foregroundColor(ModernTheme.textSecondary)
                        }

                        // Library stats — airy grid, no card border
                        HStack(spacing: 0) {
                            statItem(value: "\(library.songs.count)",     label: "Songs")
                            statItem(value: "\(library.albums.count)",    label: "Albums")
                            statItem(value: "\(library.artists.count)",   label: "Artists")
                            statItem(value: "\(library.playlists.count)", label: "Playlists")
                        }

                        // Audio & Performance
                        group(title: "Audio & Performance") {
                            NavigationLink(destination: EqualizerView()) {
                                row(icon: "slider.vertical.3", label: "Equalizer", chevron: true)
                            }
                            .buttonStyle(.plain)
                            
                            rowDivider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bolt.batteryblock.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(ModernTheme.textSecondary)
                                        .frame(width: 24)
                                    Text("Performance Mode")
                                        .font(ModernTheme.body())
                                        .foregroundColor(ModernTheme.textPrimary)
                                    Spacer()
                                }
                                
                                Picker("Performance Profile", selection: $performanceProfile) {
                                    ForEach(PerformanceProfile.allCases) { profile in
                                        Text(profile.rawValue).tag(profile)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                Text(performanceProfile.description)
                                    .font(ModernTheme.caption())
                                    .foregroundColor(ModernTheme.textSecondary)
                                    .padding(.top, 4)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            rowDivider()
                            toggleRow(icon: "arrow.triangle.merge", label: "Gapless Playback", binding: $gaplessPlayback)
                            rowDivider()
                            toggleRow(icon: "waveform.path.ecg", label: "Volume Normalisation", binding: $volumeNormalization)
                            rowDivider()

                            // Crossfade slider inline
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.left.and.right.square.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(ModernTheme.textSecondary)
                                    Text("Crossfade")
                                        .font(ModernTheme.body())
                                        .foregroundColor(ModernTheme.textPrimary)
                                    Spacer()
                                    Text(crossfadeDuration == 0 ? "Off" : String(format: "%.0fs", crossfadeDuration))
                                        .font(ModernTheme.caption())
                                        .foregroundColor(ModernTheme.textSecondary)
                                        .monospacedDigit()
                                }
                                Slider(value: $crossfadeDuration, in: 0...12, step: 1)
                                    .tint(ModernTheme.accentYellow)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        // Connectivity
                        group(title: "Connectivity") {
                            VStack(alignment: .leading, spacing: 4) {
                                toggleRow(icon: "car.fill", label: "Auto-Play on Bluetooth", binding: $autoPlayOnBluetooth)

                                if autoPlayOnBluetooth {
                                    Divider()
                                        .background(ModernTheme.borderSubtle)
                                        .padding(.leading, 52)

                                    HStack(spacing: 12) {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.system(size: 15))
                                            .foregroundColor(ModernTheme.textSecondary)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Device Name")
                                                .font(ModernTheme.body())
                                                .foregroundColor(ModernTheme.textPrimary)
                                            TextField("e.g. xav-w650bt (leave blank for any)", text: $bluetoothCarName)
                                                .font(ModernTheme.caption())
                                                .foregroundColor(ModernTheme.textSecondary)
                                                .autocorrectionDisabled()
                                                .textInputAutocapitalization(.never)
                                                .submitLabel(.done)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    Text(bluetoothCarName.isEmpty
                                         ? "Will auto-play when any Bluetooth audio device connects."
                                         : "Will only auto-play when \"\(bluetoothCarName)\" connects.")
                                        .font(ModernTheme.caption())
                                        .foregroundColor(ModernTheme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 10)
                                } else {
                                    Text("Automatically starts playing when your car stereo connects. No Shortcuts needed.")
                                        .font(ModernTheme.caption())
                                        .foregroundColor(ModernTheme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 10)
                                }
                            }
                        }


                        // Library actions
                        group(title: "Library") {
                            Button { showingClearLibraryAlert = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 15))
                                        .foregroundColor(ModernTheme.danger)
                                        .frame(width: 24)
                                    Text("Clear Library")
                                        .font(ModernTheme.body())
                                        .foregroundColor(ModernTheme.danger)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }


                        // Developer (hidden)
                        if showDeveloperSection {
                            group(title: "Developer") {
                                infoRow(label: "Developer", value: "Amal B Ajith")
                                rowDivider()
                                Button {
                                    if let url = URL(string: "https://github.com/iamalbajith"),
                                       isSafeURL(url) { openURL(url) }
                                } label: {
                                    row(icon: "link", label: "GitHub", chevron: true)
                                }
                                .buttonStyle(.plain)
                                rowDivider()
                                toggleRow(icon: "photo.badge.arrow.down",  label: "Bypass Artwork Cache", binding: $devBypassArtworkCache)
                                rowDivider()
                                toggleRow(icon: "network",     label: "Simulate Network Delay", binding: $devSimulateNetworkDelay)
                                rowDivider()
                                toggleRow(icon: "waveform.path.ecg",  label: "Show Audio Metrics Overlay", binding: $devShowAudioMetrics)
                                rowDivider()
                                Button {
                                    devBypassArtworkCache   = false
                                    devSimulateNetworkDelay = false
                                    devShowAudioMetrics     = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 15))
                                            .foregroundColor(ModernTheme.danger)
                                            .frame(width: 24)
                                        Text("Reset Dev Settings")
                                            .font(ModernTheme.body())
                                            .foregroundColor(ModernTheme.danger)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // About
                        group(title: "About") {
                            Button { handleVersionTap() } label: {
                                infoRow(label: "Version", value: "1.8.5")
                            }
                            .buttonStyle(.plain)
                            rowDivider()
                            infoRow(label: "Build", value: "32")
                        }
                    }
                    .padding(.horizontal, ModernTheme.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, player.currentSong != nil ? 200 : 80)
                }
            }
            .preferredColorScheme(.dark)
        }
        .alert("Clear Library", isPresented: $showingClearLibraryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) { library.deleteAllSongs() }
        } message: {
            Text("This will remove all songs from your library. This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }

        .preferredColorScheme(.dark)
    }


    // MARK: - Section group

    @ViewBuilder
    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ModernTheme.headline())
                .foregroundColor(ModernTheme.textPrimary)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ModernTheme.backgroundSecondary.opacity(0.85))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(ModernTheme.borderSubtle, lineWidth: 1)
            }
        }
    }

    // MARK: - Row helpers

    private func row(icon: String, label: String, chevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(ModernTheme.textSecondary)
                .frame(width: 24)
            Text(label)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textPrimary)
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ModernTheme.textSecondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func toggleRow(icon: String, label: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(ModernTheme.textSecondary)
                .frame(width: 24)
            Text(label)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textPrimary)
            Spacer()
            Toggle("", isOn: binding).labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textPrimary)
            Spacer()
            Text(value)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func rowDivider() -> some View {
        Divider()
            .background(ModernTheme.borderSubtle)
            .padding(.leading, 52)
    }

    // MARK: - Stats

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ModernTheme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ModernTheme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func handleVersionTap() {
        versionTapCount += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if versionTapCount >= 7 && !showDeveloperSection && canUnlockDeveloperSection {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { showDeveloperSection = true }
            versionTapCount = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if versionTapCount < 7 { versionTapCount = 0 }
        }
    }

    // VULN-05 note: this guard is sound for the hardcoded GitHub URL below.
    // Do NOT reuse this function for user-supplied URLs without additional validation —
    // hasSuffix alone is bypassable (e.g. "evil-github.com"). If user input is ever
    // involved, use a strict allowlist of exact hostnames instead.
    private func isSafeURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }
}

#Preview { SettingsView() }
