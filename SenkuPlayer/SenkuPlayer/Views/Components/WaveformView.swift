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
    @State private var displayLink: CADisplayLink?
    @State private var phase: Double = 0
    
    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 2
            let spacing: CGFloat = 3
            let totalBarWidth = barWidth + spacing
            let startX = (size.width - CGFloat(barCount) * totalBarWidth + spacing) / 2
            
            for index in 0..<barCount {
                guard index < amplitudes.count else { continue }
                
                let normalizedIndex = Double(index) / Double(barCount)
                let x = startX + CGFloat(index) * totalBarWidth
                let height = max(size.height * 0.15, min(amplitudes[index], size.height * 0.95))
                let y = (size.height - height) / 2
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: height)
                let path = Capsule().path(in: rect)
                
                if normalizedIndex <= progress {
                    context.fill(path, with: .linearGradient(
                        Gradient(colors: [ModernTheme.accentYellowSoft, ModernTheme.accentYellow]),
                        startPoint: CGPoint(x: x, y: y),
                        endPoint: CGPoint(x: x, y: y + height)
                    ))
                } else {
                    context.fill(path, with: .linearGradient(
                        Gradient(colors: [
                            ModernTheme.textTertiary.opacity(0.45),
                            ModernTheme.textTertiary.opacity(0.2)
                        ]),
                        startPoint: CGPoint(x: x, y: y),
                        endPoint: CGPoint(x: x, y: y + height)
                    ))
                }
            }
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
                generateWaveform()
            }
        }
        .onChange(of: songURL) { oldValue, newValue in
            generateWaveform()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func generateWaveform() {
        amplitudes = (0..<barCount).map { index in
            let normalizedIndex = Double(index) / Double(barCount)
            
            let wave1 = sin(normalizedIndex * .pi * 3) * 0.4
            let wave2 = sin(normalizedIndex * .pi * 7) * 0.3
            let wave3 = sin(normalizedIndex * .pi * 11) * 0.2
            
            let combined = (wave1 + wave2 + wave3 + 1.0) / 2.0
            let randomVariation = Double.random(in: 0.85...1.15)
            
            return CGFloat(combined * randomVariation * 70 + 15)
        }
    }
    
    private func startAnimation() {
        stopAnimation()
        let link = CADisplayLink(target: DisplayLinkTarget { [self] in
            self.phase += 0.025
            self.updateAmplitudes()
        }, selector: #selector(DisplayLinkTarget.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func updateAmplitudes() {
        amplitudes = (0..<barCount).map { index in
            let normalizedIndex = Double(index) / Double(barCount)
            
            let wave1 = sin(normalizedIndex * .pi * 3 + phase * 1.5) * 0.4
            let wave2 = sin(normalizedIndex * .pi * 7 + phase * 2.0) * 0.3
            let wave3 = sin(normalizedIndex * .pi * 11 + phase * 2.5) * 0.2
            
            let combined = (wave1 + wave2 + wave3 + 1.0) / 2.0
            
            return CGFloat(combined * 70 + 15)
        }
    }
}

// MARK: - CADisplayLink Target Helper
private class DisplayLinkTarget: NSObject {
    let callback: () -> Void
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    @objc func tick() {
        callback()
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
