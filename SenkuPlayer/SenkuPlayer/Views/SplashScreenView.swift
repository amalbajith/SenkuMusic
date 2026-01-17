//
//  SplashScreenView.swift
//  SenkuPlayer
//
//  Created by Amal on 16/01/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var showWaves = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: Double = 0
    @State private var orbOffset = CGSize.zero
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // MARK: - Background Layer
            Color.black.ignoresSafeArea()
            
            // Dynamic Mesh-like Background Orbs
            ZStack {
                OrbView(color: Color.white.opacity(0.12), size: 400, offset: orbOffset)
                    .blur(radius: 80)
                    .offset(x: -150, y: -200)
                
                OrbView(color: Color.white.opacity(0.08), size: 300, offset: orbOffset)
                    .blur(radius: 60)
                    .offset(x: 150, y: 200)
                
                OrbView(color: Color.white.opacity(0.05), size: 350, offset: orbOffset)
                    .blur(radius: 70)
                    .offset(x: 100, y: -300)
            }
            .opacity(isAnimating ? 1 : 0)
            
            // MARK: - Logo & Content Layer
            VStack(spacing: 40) {
                Spacer()
                
                // Impressive Animated Logo
                ZStack {
                    // Pulsing Glow
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)
                    
                    // Outer Rotating Rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 140 + CGFloat(i * 20), height: 140 + CGFloat(i * 20))
                            .rotationEffect(.degrees(rotationAngle * Double(i + 1) * 0.5))
                    }
                    
                    // Main Logo Container
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [ModernTheme.mediumGray, ModernTheme.darkGray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.white.opacity(0.5), radius: 10, x: 0, y: 0)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                }
                
                // App Branding Text
                VStack(spacing: 12) {
                    Text("Senku")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .kerning(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("PREMIUM AUDIO EXPERIENCE")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(6)
                        .foregroundColor(ModernTheme.lightGray)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
                
                Spacer()
                
                // Elegant Loading Section
                VStack(spacing: 20) {
                    HStack(spacing: 4) {
                        ForEach(0..<8) { index in
                            WaveBar(index: index, animate: showWaves)
                        }
                    }
                    
                    Text("INITIALIZING ENGINE")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(4)
                        .foregroundColor(ModernTheme.accentYellow.opacity(0.6))
                }
                .padding(.bottom, 50)
                .opacity(textOpacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startAdvancedAnimations()
        }
    }
    
    // MARK: - Animation Logic
    private func startAdvancedAnimations() {
        // Entrance sequence
        withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
            isAnimating = true
        }
        
        withAnimation(.easeOut(duration: 1.5).delay(0.6)) {
            textOffset = 0
            textOpacity = 1.0
        }
        
        // Continuous rotation
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.4
        }
        
        // Wave animation
        showWaves = true
        
        // Background orb movement
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            orbOffset = CGSize(width: 50, height: 50)
        }
    }
}

// MARK: - Supporting Views
struct OrbView: View {
    let color: Color
    let size: CGFloat
    let offset: CGSize
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(offset)
    }
}

struct WaveBar: View {
    let index: Int
    let animate: Bool
    @State private var height: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [ModernTheme.accentYellow, ModernTheme.accentYellow.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: height)
            .onAppear {
                if animate {
                    withAnimation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.15)
                    ) {
                        height = CGFloat.random(in: 15...35)
                    }
                }
            }
    }
}

#Preview {
    SplashScreenView()
}
