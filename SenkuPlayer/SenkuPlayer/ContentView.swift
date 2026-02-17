//
//  ContentView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var multipeer = MultipeerManager.shared
    
    @State private var selectedTab = 0
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        Group {
            #if os(macOS)
            MacOSLayout(selectedTab: $selectedTab)
            #else
            IOSLayout(selectedTab: $selectedTab)
            #endif
        }
        .preferredColorScheme(.dark)
        .alert("Connect Request", isPresented: $multipeer.showingInvitationAlert) {
            Button("Decline", role: .cancel) { multipeer.declineInvitation() }
            Button("Accept") { multipeer.acceptInvitation() }
        } message: {
            Text("'\(multipeer.invitationSenderName)' wants to connect for device transfer.")
        }

        #if os(iOS)
        .sheet(isPresented: $player.isNowPlayingPresented) {
            NowPlayingView()
        }
        #endif
    }
}

// MARK: - macOS Specific Layout
#if os(macOS)
struct MacOSLayout: View {
    @Binding var selectedTab: Int
    @StateObject private var player = AudioPlayerManager.shared
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section(header: Text("Browse")) {
                    NavigationLink(value: 0) {
                        Label("Home", systemImage: "house")
                    }
                    NavigationLink(value: 1) {
                        Label("Library", systemImage: "music.note.list")
                    }
                }
                
                Section(header: Text("Tools")) {
                    NavigationLink(value: 2) {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    NavigationLink(value: 3) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            
            Spacer()
        } detail: {
            VStack(spacing: 0) {
                ZStack {
                    ModernTheme.backgroundPrimary.ignoresSafeArea()
                    
                    switch selectedTab {
                    case 0:
                        LibraryView()
                    case 1:
                        PlaylistsListView(searchText: "")
                    case 2:
                        SyncView()
                    case 3:
                        SettingsView()
                    default:
                        LibraryView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    Task {
                        var urls: [URL] = []
                        for provider in providers {
                            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil),
                               let data = item as? Data,
                               let url = URL(dataRepresentation: data, relativeTo: nil) {
                                urls.append(url)
                            } else if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil),
                                      let url = item as? URL {
                                urls.append(url)
                            }
                        }
                        if !urls.isEmpty {
                            await MainActor.run {
                                MusicLibraryManager.shared.importFiles(urls)
                            }
                        }
                    }
                    return true
                }
                
                // Mini Player at the bottom of main view
                if player.currentSong != nil {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    MiniPlayerView()
                        .padding()
                        .background(ModernTheme.backgroundSecondary)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
#endif

// MARK: - iOS Specific Layout
struct IOSLayout: View {
    @Binding var selectedTab: Int
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var multipeer = MultipeerManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            ModernTheme.backgroundPrimary.ignoresSafeArea()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    LibraryView()
                case 1:
                    PlaylistsListView(searchText: "")
                case 2:
                    SyncView()
                case 3:
                    SettingsView()
                default:
                    LibraryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                // Buffer for MiniPlayer + Navbar (Fixed height to prevent jumping)
                Color.clear.frame(height: 140)
            }
            
            VStack(spacing: 0) {
                // Received Notification
                if multipeer.showReceivedNotification {
                    ReceivedNotificationView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                }
                
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: player.currentSong != nil)
    }
}

// MARK: - Components for iOS
struct CustomNavbar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabItem(index: 0, icon: "house", label: "HOME")
            tabItem(index: 1, icon: "music.note.list", label: "LIBRARY")
            tabItem(index: 2, icon: "arrow.triangle.2.circlepath", label: "SYNC")
            tabItem(index: 3, icon: "gearshape", label: "SETTINGS")
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            ModernTheme.backgroundSecondary.opacity(0.85)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            Divider().background(ModernTheme.borderSubtle)
        }
    }
    
    private func tabItem(index: Int, icon: String, label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(selectedTab == index ? ModernTheme.accentYellow : ModernTheme.textTertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}

struct ReceivedNotificationView: View {
    @StateObject private var multipeer = MultipeerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Song Received")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text(multipeer.lastReceivedSongName ?? "Unknown Song")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                withAnimation { multipeer.showReceivedNotification = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .background(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
