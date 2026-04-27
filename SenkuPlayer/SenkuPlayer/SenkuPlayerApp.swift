//
//  SenkuPlayerApp.swift
//  SenkuPlayer
//

import SwiftUI
import AVFoundation

@main
struct SenkuPlayerApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app — always loaded so audio engine initialises immediately
                ContentView()
                    .opacity(splashDone && hasCompletedOnboarding ? 1 : 0)

                // Splash
                if !splashDone {
                    SplashScreenView(onComplete: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            splashDone = true
                        }
                    })
                    .transition(.opacity)
                    .zIndex(2)
                }

                // Onboarding (first launch only, after splash)
                if splashDone && !hasCompletedOnboarding {
                    OnboardingView(onComplete: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            hasCompletedOnboarding = true
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: splashDone)
            .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
        }
    }
}
