//
//  WaveformView.swift
//  SenkuPlayer
//
//  Beautiful animated waveform visualization
//

import SwiftUI

struct WaveformView: View {
    let barCount: Int = 60
    let isPlaying: Bool
    let progress: Double // 0.0 to 1.0
    let songURL: URL?
    
    @State private var amplitudes: [CGFloat] = []
    @State private var animationTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(barColor(for: index))
                        .frame(width: 2, height: barHeight(for: index, maxHeight: geometry.size.height))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: amplitudes)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 80)
        .onAppear {
            generateWaveform()
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onChange(of: songURL) { oldValue, newValue in
            generateWaveform()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func barColor(for index: Int) -> LinearGradient {
        let normalizedIndex = Double(index) / Double(barCount)
        
        if normalizedIndex <= progress {
            // Played portion - yellow gradient
            return LinearGradient(
                colors: [ModernTheme.accentYellow, ModernTheme.accentYellow.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Unplayed portion - gray
            return LinearGradient(
                colors: [ModernTheme.lightGray.opacity(0.4), ModernTheme.lightGray.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        guard index < amplitudes.count else { return maxHeight * 0.2 }
        
        let baseHeight = amplitudes[index]
        let minHeight = maxHeight * 0.15
        let maxBarHeight = maxHeight * 0.95
        
        return max(minHeight, min(baseHeight, maxBarHeight))
    }
    
    private func generateWaveform() {
        // Create a natural-looking waveform with variation
        amplitudes = (0..<barCount).map { index in
            let normalizedIndex = Double(index) / Double(barCount)
            
            // Multiple sine waves for natural variation
            let wave1 = sin(normalizedIndex * .pi * 3) * 0.4
            let wave2 = sin(normalizedIndex * .pi * 7) * 0.3
            let wave3 = sin(normalizedIndex * .pi * 11) * 0.2
            
            let combined = (wave1 + wave2 + wave3 + 1.0) / 2.0
            let randomVariation = Double.random(in: 0.85...1.15)
            
            return CGFloat(combined * randomVariation * 70 + 15)
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                updateAmplitudes()
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAmplitudes() {
        let time = Date().timeIntervalSince1970
        
        amplitudes = (0..<barCount).map { index in
            let normalizedIndex = Double(index) / Double(barCount)
            
            // Animated waves
            let wave1 = sin(normalizedIndex * .pi * 3 + time * 1.5) * 0.4
            let wave2 = sin(normalizedIndex * .pi * 7 + time * 2.0) * 0.3
            let wave3 = sin(normalizedIndex * .pi * 11 + time * 2.5) * 0.2
            
            let combined = (wave1 + wave2 + wave3 + 1.0) / 2.0
            let randomVariation = Double.random(in: 0.9...1.1)
            
            return CGFloat(combined * randomVariation * 70 + 15)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        WaveformView(isPlaying: true, progress: 0.3, songURL: nil)
            .background(Color.black)
        
        WaveformView(isPlaying: false, progress: 0.6, songURL: nil)
            .background(Color.black)
    }
    .padding()
}
