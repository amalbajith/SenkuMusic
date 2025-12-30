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

    @Environment(\.colorScheme) private var colorScheme
    @State private var versionTapCount = 0
    @State private var showDeveloperSection = false
    
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
                            Text("1.3.1")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("20")
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
        }
        .preferredColorScheme(darkMode ? .dark : .light)
        .animation(.easeInOut(duration: 0.8), value: darkMode)
    }
    
    private func clearLibrary() {
        library.songs.removeAll()
        library.albums.removeAll()
        library.artists.removeAll()
        UserDefaults.standard.removeObject(forKey: "savedSongs")
    }
    
    private func handleVersionTap() {
        versionTapCount += 1
        
        // Haptic feedback
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
        
        // Show developer section after 7 taps
        if versionTapCount >= 7 && !showDeveloperSection {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showDeveloperSection = true
            }
            
            // Success haptic
            #if os(iOS)
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            #endif
            
            // Reset counter
            versionTapCount = 0
        }
        
        // Reset counter after 2 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if versionTapCount < 7 {
                versionTapCount = 0
            }
        }
    }
}

#Preview {
    SettingsView()
}
