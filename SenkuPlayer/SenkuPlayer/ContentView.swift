//
//  ContentView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Pure black background for dark mode
            if darkMode {
                Color.black.ignoresSafeArea()
            }
            
            // Main Library View
            LibraryView()
            
            // Mini Player Overlay
            if player.currentSong != nil {
                MiniPlayerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: player.currentSong != nil)
        .preferredColorScheme(darkMode ? .dark : .light)
    }
}

#Preview {
    ContentView()
}
