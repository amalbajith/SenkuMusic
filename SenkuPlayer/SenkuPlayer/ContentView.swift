//
//  ContentView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var multipeer = MultipeerManager.shared
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Pure black background for dark mode
            if darkMode {
                Color.black.ignoresSafeArea()
            }
            
            // Main Tab View
            TabView {
                LibraryView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                
                PlaylistsListView(searchText: "")
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                
                NavigationStack {
                    NearbyShareView(songs: [])
                }
                .tabItem {
                    Label("Nearby", systemImage: "wave.3.backward.circle.fill")
                }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .tint(.blue)
            
            VStack {
                // Received Notification
                if multipeer.showReceivedNotification {
                    receivedNotificationView
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                }
                
                Spacer()
                
                // Mini Player Overlay
                if player.currentSong != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.keyboard)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: player.currentSong != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: multipeer.showReceivedNotification)
        .preferredColorScheme(darkMode ? .dark : .light)
        .alert("Connect Request", isPresented: $multipeer.showingInvitationAlert) {
            Button("Decline", role: .cancel) {
                multipeer.declineInvitation()
            }
            Button("Accept") {
                multipeer.acceptInvitation()
            }
        } message: {
            Text("'\(multipeer.invitationSenderName)' wants to connect with you to share music.")
        }
    }
    
    private var receivedNotificationView: some View {
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
                withAnimation {
                    multipeer.showReceivedNotification = false
                }
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
                .fill(Color(platformColor: .secondaryBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .onAppear {
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
            
            // Auto hide after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    multipeer.showReceivedNotification = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
