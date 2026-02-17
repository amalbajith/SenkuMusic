//
//  WaveformView.swift
//  SenkuPlayer
//
//  Beautiful animated waveform visualization
//

import SwiftUI

struct WaveformView: View {
    let barCount: Int = 50
    let isPlaying: Bool
    let progress: Double // 0.0 to 1.0
    let songURL: URL?
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60, paused: !isPlaying)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = isPlaying ? time * 2.5 : 0
                
                let barWidth: CGFloat = 3
                let spacing: CGFloat = 3
                let totalBarWidth = barWidth + spacing
                // Center the waveform
                let totalWidth = CGFloat(barCount) * totalBarWidth - spacing
                let startX = (size.width - totalWidth) / 2
                
                for index in 0..<barCount {
                    let normalizedIndex = Double(index) / Double(barCount)
                    
                    // Wave math inside the loop - no state updates
                    // Combine 3 sine waves for organic motion
                    let wave1 = sin(normalizedIndex * .pi * 3 + phase) * 0.4
                    let wave2 = sin(normalizedIndex * .pi * 7 + phase * 0.7) * 0.3
                    let wave3 = sin(normalizedIndex * .pi * 11 + phase * 1.3) * 0.2
                    
                    // Base height + wave variation
                    let amplitude = (wave1 + wave2 + wave3 + 1.2) / 2.4 // Normalize roughly 0..1
                    
                    // Scale to view height
                    let activeHeight = CGFloat(amplitude) * (size.height * 0.8) + (size.height * 0.1)
                    let height = isPlaying ? activeHeight : (size.height * 0.15) // Static line when paused
                    
                    let x = startX + CGFloat(index) * totalBarWidth
                    let y = (size.height - height) / 2
                    
                    let path = Path(roundedRect: CGRect(x: x, y: y, width: barWidth, height: height), cornerRadius: barWidth/2)
                    
                    // Color based on playback progress
                    // We map the bar's position (normalizedIndex) against the song progress
                    if normalizedIndex <= progress {
                        context.fill(path, with: .linearGradient(
                            Gradient(colors: [ModernTheme.accentYellowSoft, ModernTheme.accentYellow]),
                            startPoint: CGPoint(x: x, y: y),
                            endPoint: CGPoint(x: x, y: y + height)
                        ))
                    } else {
                        context.fill(path, with: .color(ModernTheme.textTertiary.opacity(0.3)))
                    }
                }
            }
        }
        .frame(height: 60)
        .drawingGroup() // Offload to GPU
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 40) {
            WaveformView(isPlaying: true, progress: 0.3, songURL: nil)
            WaveformView(isPlaying: false, progress: 0.6, songURL: nil)
        }
        .padding()
    }
}
