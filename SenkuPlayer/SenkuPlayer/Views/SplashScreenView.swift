//
//  SplashScreenView.swift
//  SenkuPlayer
//
//  Redesigned: cinematic splash + first-launch onboarding
//

import SwiftUI

// MARK: - App Entry Coordinator
struct AppLaunchCoordinator: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var splashDone = false

    var body: some View {
        ZStack {
            if !splashDone {
                SplashScreenView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        splashDone = true
                    }
                })
                .transition(.opacity)
                .zIndex(2)
            } else if !hasCompletedOnboarding {
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
    }
}

// MARK: - Cinematic Splash Screen
struct SplashScreenView: View {
    let onComplete: () -> Void
    @AppStorage("performanceProfile") private var performanceProfile: PerformanceProfile = .balanced

    // Animation state machine
    @State private var phase: SplashPhase = .idle

    // Individual element states
    @State private var bgOpacity: Double = 0
    @State private var particleOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkY: CGFloat = 16
    @State private var taglineOpacity: Double = 0
    @State private var waveOpacity: Double = 0
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity: Double = 1.0

    // Continuous animations
    @State private var ring1Rotation: Double = 0
    @State private var ring2Rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var particlePhase: Double = 0

    enum SplashPhase { case idle, entering, holding, exiting }

    var body: some View {
        ZStack {
            // ── Layer 1: Deep black canvas
            Color.black.ignoresSafeArea()
                .opacity(bgOpacity)

            // ── Layer 2: Ambient noise particles
            if performanceProfile != .eco {
                ParticleField(phase: particlePhase)
                    .opacity(particleOpacity)
                    .blendMode(.screen)
            }

            // ── Layer 3: Radial glow halo
            RadialGradient(
                colors: [
                    Color(hue: 0.55, saturation: 0.5, brightness: 0.95).opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .scaleEffect(pulseScale)
            .opacity(ringOpacity)
            .ignoresSafeArea()

            // ── Layer 4: Spinning orbital rings
            ZStack {
                OrbitalRing(diameter: 220, lineWidth: 0.5, dashPattern: [4, 8],
                            color: .white.opacity(0.15), rotation: ring1Rotation)
                OrbitalRing(diameter: 180, lineWidth: 1, dashPattern: [2, 6],
                            color: Color(hue: 0.55, saturation: 0.5, brightness: 0.95).opacity(0.4),
                            rotation: -ring2Rotation)
                OrbitalRing(diameter: 260, lineWidth: 0.5, dashPattern: [8, 16],
                            color: .white.opacity(0.07), rotation: ring1Rotation * 0.6)
            }
            .scaleEffect(ringScale)
            .opacity(ringOpacity)

            // ── Layer 5: Core logo
            ZStack {
                // Glow
                Circle()
                    .fill(Color(hue: 0.55, saturation: 0.6, brightness: 1.0))
                    .frame(width: 90, height: 90)
                    .blur(radius: glowRadius)
                    .opacity(0.5)

                // Logo circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.18),
                                Color(white: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color(hue: 0.55, saturation: 0.6, brightness: 0.9).opacity(0.4),
                            radius: 30, x: 0, y: 10)

                // Icon
                Image(systemName: "waveform")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hue: 0.55, saturation: 0.4, brightness: 1.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)

            // ── Layer 6: Wordmark + tagline
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 6) {
                    Text("SENKU")
                        .font(.system(size: 46, weight: .black, design: .default))
                        .kerning(12)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("MUSIC")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(8)
                        .foregroundColor(Color(hue: 0.55, saturation: 0.5, brightness: 0.95))
                        .opacity(taglineOpacity)
                }
                .offset(y: wordmarkY)
                .opacity(wordmarkOpacity)

                Spacer()
                Spacer()

                // Wave bars
                VStack(spacing: 10) {
                    SplashWaveBar(barCount: 12)
                    Text("LOADING YOUR LIBRARY")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(3)
                        .foregroundColor(.white.opacity(0.3))
                }
                .opacity(waveOpacity)
                .padding(.bottom, 52)
            }
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .preferredColorScheme(.dark)
        .onAppear { runSplashSequence() }
    }

    private func runSplashSequence() {
        // Step 1: Background fade in
        withAnimation(.easeOut(duration: 0.3)) { bgOpacity = 1 }

        // Step 2: Rings burst in (spring overshoot)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.15)) {
            ringScale = 1.0; ringOpacity = 1
        }

        // Step 3: Logo scales in with elastic spring
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.25)) {
            logoScale = 1.0; logoOpacity = 1
        }

        // Step 4: Glow blooms outward
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) { glowRadius = 40 }

        // Step 5: Wordmark slides up
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.55)) {
            wordmarkOpacity = 1; wordmarkY = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) { taglineOpacity = 1 }

        // Step 6: Particles + waves appear
        withAnimation(.easeIn(duration: 0.6).delay(0.7)) {
            particleOpacity = 1; waveOpacity = 1
        }

        // Continuous animations
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            ring1Rotation = 360
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            ring2Rotation = 360
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.12
        }
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            particlePhase = 1
        }

        // Exit: cinematic zoom-out and dissolve
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeIn(duration: 0.55)) {
                exitScale = 1.08
                exitOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                onComplete()
            }
        }
    }
}

// MARK: - Onboarding
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var buttonScale: CGFloat = 1.0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform.circle.fill",
            accent: Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
            title: "Your Music,\nUnchained",
            subtitle: "A studio-grade listening experience. No subscriptions, no tracking — just you and your music.",
            visual: .waveform
        ),
        OnboardingPage(
            icon: "sparkles",
            accent: Color(hue: 0.83, saturation: 0.7, brightness: 0.95),
            title: "Auto Mix\nIntelligence",
            subtitle: "Let Senku build a perfect queue from your library using genre and artist affinity.",
            visual: .automix
        ),
        OnboardingPage(
            icon: "arrow.down.circle.fill",
            accent: Color(hue: 0.35, saturation: 0.8, brightness: 0.85),
            title: "Import\nAnything",
            subtitle: "Drop in MP3, FLAC, M4A, WAV — even ZIP archives of albums. Artwork loads automatically.",
            visual: .import_
        )
    ]

    var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Page content
            #if os(iOS)
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { idx in
                    OnboardingPageView(page: pages[idx], isActive: currentPage == idx)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)
            #else
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { idx in
                    OnboardingPageView(page: pages[idx], isActive: currentPage == idx)
                        .tag(idx)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)
            #endif

            // Bottom controls overlay
            VStack {
                Spacer()

                // Page indicator dots
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { idx in
                        Capsule()
                            .fill(currentPage == idx
                                  ? pages[currentPage].accent
                                  : Color.white.opacity(0.25))
                            .frame(width: currentPage == idx ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 28)

                // CTA button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        buttonScale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            buttonScale = 1.0
                        }
                        if isLastPage {
                            onComplete()
                        } else {
                            withAnimation { currentPage += 1 }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(isLastPage ? "Let's Go" : "Continue")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                        Image(systemName: isLastPage ? "checkmark" : "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        pages[currentPage].accent
                            .animation(.easeInOut(duration: 0.4), value: currentPage)
                    )
                    .clipShape(Capsule())
                    .shadow(color: pages[currentPage].accent.opacity(0.5), radius: 20, x: 0, y: 8)
                }
                .scaleEffect(buttonScale)
                .padding(.horizontal, 28)

                // Skip (only on non-last pages)
                if !isLastPage {
                    Button("Skip") {
                        withAnimation { currentPage = pages.count - 1 }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 10)
                }

                Color.clear.frame(height: 20)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    @State private var visualAnimating = false
    @State private var titleOpacity: Double = 0
    @State private var titleY: CGFloat = 24
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Visual illustration
            ZStack {
                // Ambient glow
                Circle()
                    .fill(page.accent)
                    .frame(width: 200, height: 200)
                    .blur(radius: 80)
                    .opacity(0.25)
                    .scaleEffect(visualAnimating ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: visualAnimating)

                OnboardingVisual(type: page.visual, accent: page.accent, isAnimating: visualAnimating)
                    .frame(width: 260, height: 260)
            }
            .frame(height: 300)

            Spacer().frame(height: 44)

            // Title
            Text(page.title)
                .font(.system(size: 38, weight: .black, design: .default))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(white: 0.85)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .lineSpacing(2)
                .opacity(titleOpacity)
                .offset(y: titleY)
                .padding(.horizontal, 32)

            Spacer().frame(height: 16)

            // Subtitle
            Text(page.subtitle)
                .font(.system(size: 16, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(4)
                .opacity(subtitleOpacity)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
            // Bottom padding for the CTA overlay
            Color.clear.frame(height: 160)
        }
        .onChange(of: isActive) { _, active in
            if active { animateIn() } else { reset() }
        }
        .onAppear { if isActive { animateIn() } }
    }

    private func animateIn() {
        visualAnimating = true
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
            titleOpacity = 1; titleY = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            subtitleOpacity = 1
        }
    }

    private func reset() {
        visualAnimating = false
        titleOpacity = 0; titleY = 24; subtitleOpacity = 0
    }
}

// MARK: - Data model
struct OnboardingPage {
    enum Visual { case waveform, automix, import_ }
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
    let visual: Visual
}

// MARK: - Onboarding Visuals (custom per-page illustrations)
struct OnboardingVisual: View {
    let type: OnboardingPage.Visual
    let accent: Color
    let isAnimating: Bool

    @State private var barHeights: [CGFloat] = Array(repeating: 20, count: 16)
    @State private var orb1: CGSize = .zero
    @State private var orb2: CGSize = .zero

    var body: some View {
        ZStack {
            switch type {
            case .waveform:
                // Animated equalizer bars
                HStack(alignment: .center, spacing: 5) {
                    ForEach(barHeights.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(colors: [accent, accent.opacity(0.3)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 8, height: barHeights[i])
                    }
                }
                .frame(height: 120)


            case .automix:
                // Music note bubbles floating
                ZStack {
                    noteBubble("♪", size: 54, offset: CGSize(width: -60, height: 20), delay: 0)
                    noteBubble("♫", size: 42, offset: CGSize(width: 40, height: -50), delay: 0.4)
                    noteBubble("♩", size: 36, offset: CGSize(width: 70, height: 40), delay: 0.8)
                    noteBubble("𝄞", size: 48, offset: CGSize(width: -30, height: -60), delay: 1.2)

                    // Center spark
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundColor(accent)
                        .shadow(color: accent.opacity(0.6), radius: 16)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isAnimating)
                }

            case .import_:
                // File stack with arrow
                ZStack {
                    fileCard(offset: CGSize(width: -8, height: 16), opacity: 0.3, rotation: -6)
                    fileCard(offset: CGSize(width: 4, height: 8), opacity: 0.6, rotation: 3)
                    fileCard(offset: .zero, opacity: 1.0, rotation: 0)

                    // Download arrow
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(accent)
                            .offset(y: isAnimating ? 6 : -6)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
                    }
                    .offset(y: -80)
                }
            }
        }
        .onAppear {
            if type == .waveform {
                animateBars()
            }
        }
    }

    private func animateBars() {
        for i in barHeights.indices {
            let delay = Double(i) * 0.07
            withAnimation(.easeInOut(duration: 0.5 + Double.random(in: 0...0.4))
                            .repeatForever(autoreverses: true)
                            .delay(delay)) {
                barHeights[i] = CGFloat.random(in: 24...110)
            }
        }
    }

    private func deviceIcon(_ name: String, offset: CGSize) -> some View {
        Image(systemName: name)
            .font(.system(size: 28))
            .foregroundColor(.white.opacity(0.85))
            .offset(offset)
    }

    private func noteBubble(_ note: String, size: CGFloat, offset: CGSize, delay: Double) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.15))
                .frame(width: size + 16, height: size + 16)
            Text(note)
                .font(.system(size: size * 0.55))
                .foregroundColor(accent)
        }
        .offset(offset)
        .offset(y: isAnimating ? -8 : 8)
        .animation(.easeInOut(duration: 1.6 + delay * 0.3).repeatForever(autoreverses: true).delay(delay), value: isAnimating)
    }

    private func fileCard(offset: CGSize, opacity: Double, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(white: 0.14))
            .frame(width: 140, height: 100)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .overlay(
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .foregroundColor(accent)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 70, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 6)
                    }
                }
            )
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .opacity(opacity)
    }
}

// MARK: - Splash Supporting Views
struct OrbitalRing: View {
    let diameter: CGFloat
    let lineWidth: CGFloat
    let dashPattern: [CGFloat]
    let color: Color
    let rotation: Double

    var body: some View {
        Circle()
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: dashPattern)
            )
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(rotation))
    }
}

struct SplashWaveBar: View {
    let barCount: Int
    @State private var heights: [CGFloat] = []

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
                                Color(hue: 0.55, saturation: 0.5, brightness: 0.95).opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: heights.count > i ? heights[i] : 6)
            }
        }
        .onAppear {
            heights = Array(repeating: 6, count: barCount)
            for i in 0..<barCount {
                withAnimation(
                    .easeInOut(duration: 0.5 + Double.random(in: 0...0.4))
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.1)
                ) {
                    heights[i] = CGFloat.random(in: 10...30)
                }
            }
        }
    }
}

struct ParticleField: View {
    let phase: Double

    // Fixed particle positions seeded for determinism
    private let particles: [(CGFloat, CGFloat, CGFloat, Double)] = (0..<40).map { i in
        let rng = Double(i) * 137.508 // golden angle distribution
        let x = CGFloat((sin(rng) * 0.5 + 0.5))
        let y = CGFloat((cos(rng * 0.618) * 0.5 + 0.5))
        let size = CGFloat.random(in: 1...3)
        let speed = Double.random(in: 0.3...1.0)
        return (x, y, size, speed)
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(particles.indices, id: \.self) { i in
                let p = particles[i]
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.35)))
                    .frame(width: p.2, height: p.2)
                    .position(
                        x: p.0 * geo.size.width,
                        y: (p.1 + CGFloat(phase * p.3 * 0.05)).truncatingRemainder(dividingBy: 1.0) * geo.size.height
                    )
            }
        }
        .ignoresSafeArea()
    }
}

#Preview("Splash") { SplashScreenView(onComplete: {}) }
#Preview("Onboarding") { OnboardingView(onComplete: {}) }
