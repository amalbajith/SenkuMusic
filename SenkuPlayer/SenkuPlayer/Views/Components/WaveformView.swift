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
    let onSeek: ((Double) -> Void)?

    @State private var scrubProgress: Double?

    init(
        isPlaying: Bool,
        progress: Double,
        songURL: URL?,
        onSeek: ((Double) -> Void)? = nil
    ) {
        self.isPlaying = isPlaying
        self.progress = progress
        self.songURL = songURL
        self.onSeek = onSeek
    }
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1/60, paused: !isPlaying)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = isPlaying ? time * 2.5 : 0
                    let displayedProgress = displayProgress
                    
                    let barWidth: CGFloat = 3
                    let spacing: CGFloat = 3
                    let totalBarWidth = barWidth + spacing
                    let totalWidth = CGFloat(barCount) * totalBarWidth - spacing
                    let startX = (size.width - totalWidth) / 2
                    
                    for index in 0..<barCount {
                        let normalizedIndex = Double(index) / Double(barCount)
                        
                        let wave1 = sin(normalizedIndex * .pi * 3 + phase) * 0.4
                        let wave2 = sin(normalizedIndex * .pi * 7 + phase * 0.7) * 0.3
                        let wave3 = sin(normalizedIndex * .pi * 11 + phase * 1.3) * 0.2
                        
                        let amplitude = (wave1 + wave2 + wave3 + 1.2) / 2.4
                        let activeHeight = CGFloat(amplitude) * (size.height * 0.8) + (size.height * 0.1)
                        let height = activeHeight
                        
                        let x = startX + CGFloat(index) * totalBarWidth
                        let y = (size.height - height) / 2
                        let path = Path(
                            roundedRect: CGRect(x: x, y: y, width: barWidth, height: height),
                            cornerRadius: barWidth / 2
                        )
                        
                        if normalizedIndex <= displayedProgress {
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
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            scrubProgress = progress(for: value.location.x, width: geometry.size.width)
                        }
                        .onEnded { value in
                            let updatedProgress = progress(for: value.location.x, width: geometry.size.width)
                            scrubProgress = nil
                            onSeek?(updatedProgress)
                        }
                )
            }
        }
        .frame(height: 60)
        .drawingGroup() // Offload to GPU
    }

    private var displayProgress: Double {
        scrubProgress ?? progress
    }

    private func progress(for x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        let normalized = x / width
        return min(max(Double(normalized), 0), 1)
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
