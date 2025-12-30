//
//  SettingsView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearLibraryAlert = false
    @AppStorage("darkMode") private var darkMode = false
    @Environment(\.colorScheme) private var colorScheme
    
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
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
}

#Preview {
    SettingsView()
}
