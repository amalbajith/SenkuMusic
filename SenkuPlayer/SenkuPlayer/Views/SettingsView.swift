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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingClearLibraryAlert = false
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    
    // Developer Settings
    @AppStorage("devShowFileExtensions") private var devShowFileExtensions = false
    @AppStorage("devDisableArtworkAnimation") private var devDisableArtworkAnimation = false
    @AppStorage("devEnableDebugLogging") private var devEnableDebugLogging = false
    @AppStorage("devForceVibrantBackground") private var devForceVibrantBackground = false
    @AppStorage("devEnableDeviceTransfer") private var devEnableDeviceTransfer = false

    @State private var versionTapCount = 0
    @State private var showDeveloperSection = false
    @State private var showDeviceTransferDisclaimer = false
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    
    // Dev mode password - change this to whatever you want
    private let devPassword = "senku2025"
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section {
                    Toggle(isOn: Binding(
                        get: { darkMode },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.8)) {
                                darkMode = newValue
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: darkMode ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(darkMode ? .blue : .orange)
                            Text("Dark Mode")
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { keepScreenAwake },
                        set: { newValue in
                            keepScreenAwake = newValue
                            #if os(iOS)
                            UIApplication.shared.isIdleTimerDisabled = newValue
                            #endif
                        }
                    )) {
                        HStack {
                            Image(systemName: keepScreenAwake ? "eye.fill" : "eye.slash.fill")
                                .foregroundColor(.blue)
                            Text("Keep Screen Awake")
                        }
                    }
                } header: {
                    Text("Appearance")
                }
                
                // Library Section
                Section {
                    HStack {
                        Text("Total Songs")
                        Spacer()
                        Text("\(library.songs.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Albums")
                        Spacer()
                        Text("\(library.albums.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Artists")
                        Spacer()
                        Text("\(library.artists.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Playlists")
                        Spacer()
                        Text("\(library.playlists.count)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Library Statistics")
                }
                
                // Actions Section
                Section {
                    Button(role: .destructive) {
                        showingClearLibraryAlert = true
                    } label: {
                        Label("Clear Library", systemImage: "trash")
                    }
                } header: {
                    Text("Actions")
                }
                
                // Developer Section (Easter Egg)
                if showDeveloperSection {
                    Section {
                        HStack {
                            Text("Developer")
                            Spacer()
                            Text("Amal B Ajith")
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            if let url = URL(string: "https://github.com/iamalbajith") {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Label("GitHub", systemImage: "link")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("DEBUG FEATURES")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                        
                        Toggle("Show File Extensions", isOn: $devShowFileExtensions)
                        Toggle("Disable Artwork Animation", isOn: $devDisableArtworkAnimation)
                        Toggle("Enable Console Logging", isOn: $devEnableDebugLogging)
                        Toggle("Force Vibrant UI", isOn: $devForceVibrantBackground)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("EXPERIMENTAL FEATURES")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                        
                        Toggle("Device Transfer Mode", isOn: $devEnableDeviceTransfer)
                            .onChange(of: devEnableDeviceTransfer) { newValue in
                                if newValue {
                                    showDeviceTransferDisclaimer = true
                                }
                            }
                        
                        if devEnableDeviceTransfer {
                            Text("⚠️ Only transfer music you own or have rights to share")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.vertical, 4)
                        }
                        
                        Button(role: .destructive) {
                            // Reset all dev settings
                            devShowFileExtensions = false
                            devDisableArtworkAnimation = false
                            devEnableDebugLogging = false
                            devForceVibrantBackground = false
                            devEnableDeviceTransfer = false
                        } label: {
                            Text("Reset Dev Settings")
                        }

                    } header: {
                        Text("Developer")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // About Section
                Section {
                    Button {
                        handleVersionTap()
                    } label: {
                        HStack {
                            Text("Version")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("1.4.0")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("21")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
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
            .alert("Legal Notice", isPresented: $showDeviceTransferDisclaimer) {
                Button("I Understand") { }
                Button("Disable", role: .cancel) {
                    devEnableDeviceTransfer = false
                }
            } message: {
                Text("Device Transfer Mode is intended for transferring music between your own devices.\n\n⚠️ Sharing copyrighted music without permission is illegal.\n\n✓ Only transfer music you own or have rights to share.\n✓ This feature is for personal use only.\n\nBy continuing, you agree to use this feature responsibly and legally.")
            }
            .alert("Developer Access", isPresented: $showPasswordPrompt) {
                SecureField("Enter Password", text: $passwordInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Unlock") {
                    verifyPassword()
                }
                Button("Cancel", role: .cancel) {
                    passwordInput = ""
                }
            } message: {
                Text("Enter the developer password to unlock advanced features.")
            }
        }
        .preferredColorScheme(darkMode ? .dark : .light)
        .animation(.easeInOut(duration: 0.8), value: darkMode)
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
        if versionTapCount >= 7 && !showDeveloperSection {
            showPasswordPrompt = true
            versionTapCount = 0
        }
        
        // Reset counter after 2 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if versionTapCount < 7 {
                versionTapCount = 0
            }
        }
    }
    
    private func verifyPassword() {
        if passwordInput == devPassword {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showDeveloperSection = true
            }
            
            // Success haptic
            #if os(iOS)
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            #endif
            
            showPasswordPrompt = false
            passwordInput = ""
        } else {
            // Wrong password haptic
            #if os(iOS)
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
            #endif
            
            // Shake animation would go here
            passwordInput = ""
        }
    }
}

#Preview {
    SettingsView()
}
