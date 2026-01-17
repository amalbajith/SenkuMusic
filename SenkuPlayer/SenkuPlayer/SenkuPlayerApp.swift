//
//  SenkuPlayerApp.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import AVFoundation

@main
struct SenkuPlayerApp: App {
    @State private var showSplash = true
    
    init() {
        // Audio session setup is handled in AudioPlayerManager
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)
                
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Hide splash screen after 3.5 seconds to allow animations to play
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
