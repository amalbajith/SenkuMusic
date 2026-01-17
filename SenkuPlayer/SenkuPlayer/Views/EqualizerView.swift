//
//  EqualizerView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct EqualizerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    // Spotify Colors
    let accentColor = Color.green
    let gridColor = Color.white.opacity(0.1)
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Spacer()
                        Text("Equalizer")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top)
                    .overlay(
                        Button(action: { dismiss() }) {
                            Text("Close").foregroundColor(.white)
                        }
                        .padding(.leading),
                        alignment: .leading
                    )
                    
                    // Presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(EqualizerProfile.allPresets, id: \.id) { preset in
                                Button(action: {
                                    withAnimation(.spring()) {
                                        player.applyEqualizer(preset)
                                    }
                                }) {
                                    Text(preset.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(player.activeEqualizerProfile.id == preset.id ? accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 50)
                    
                    Spacer()
                    
                    // Visualization Graph Area
                    ZStack {
                        // Grid Lines
                        VStack {
                            Divider().background(gridColor)
                            Spacer()
                            Divider().background(gridColor)
                            Spacer()
                            Divider().background(gridColor)
                        }
                        
                        // Bezier Curve
                        EqualizerCurve(bands: player.activeEqualizerProfile.bands)
                            .stroke(LinearGradient(colors: [accentColor, accentColor.opacity(0.5)], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                            .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 5)
                            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: player.activeEqualizerProfile.bands)
                    }
                    .frame(height: 120)
                    .padding(.horizontal)
                    
                    // Sliders
                    HStack(spacing: 8) {
                        ForEach(0..<player.activeEqualizerProfile.bands.count, id: \.self) { index in
                            VStack {
                                CustomVerticalSlider(
                                    value: $player.activeEqualizerProfile.bands[index].gain,
                                    range: -12...12,
                                    accentColor: accentColor
                                ) {
                                    player.applyEqualizer(player.activeEqualizerProfile)
                                }
                                
                                Text(formatFrequency(player.activeEqualizerProfile.bands[index].frequency))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.gray)
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 30)
                                    .fixedSize()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    Spacer()
                }
            }
           // .navigationBarHidden(true)
        }
    }
    
    func formatFrequency(_ val: Float) -> String {
        if val >= 1000 {
            return "\(Int(val/1000))k"
        } else {
            return "\(Int(val))"
        }
    }
}

// MARK: - Components

struct EqualizerCurve: Shape {
    var bands: [EqualizerBand]
    
    // Animatable data so the curve morphs smoothly
    var animatableData: [Double] {
        get { bands.map { Double($0.gain) } }
        set {
            for i in 0..<min(newValue.count, bands.count) {
                bands[i].gain = Float(newValue[i])
            }
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !bands.isEmpty else { return path }
        
        let width = rect.width
        let height = rect.height
        // Map gain (-12...12) to Y (height...0)
        let midY = height / 2
        let scaleY = height / 24 // 24dB range
        
        let stepX = width / CGFloat(bands.count - 1)
        
        // Calculate points
        let points = bands.enumerated().map { index, band -> CGPoint in
            let x = CGFloat(index) * stepX
            // -12 -> height (bottom), +12 -> 0 (top)
            let y = midY - (CGFloat(band.gain) * scaleY)
            return CGPoint(x: x, y: y)
        }
        
        // Smooth curve using Quad Curves
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let p0 = points[i-1]
            let p1 = points[i]
            let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            
            // For the first point, just draw quad to mid
            if i == 1 {
                path.addQuadCurve(to: mid, control: p0)
            } else {
                path.addQuadCurve(to: mid, control: p0)
            }
            // Actually standard smooth algorithm with quad curves:
            // Curve from prevMid to currentMid using currentPoint as control
        }
        
        // Let's use a simpler known smooth algorithm
        // Re-start for valid path
        return Path { p in
            guard points.count > 1 else { return }
            p.move(to: points.first!)
            for i in 1..<points.count {
                let current = points[i]
                let previous = points[i-1]
                let control1 = CGPoint(x: previous.x + (current.x - previous.x)/2, y: previous.y)
                let control2 = CGPoint(x: previous.x + (current.x - previous.x)/2, y: current.y)
                p.addCurve(to: current, control1: control1, control2: control2)
            }
        }
    }
}

struct CustomVerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var accentColor: Color
    var onEditingChanged: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let sliderRange = CGFloat(range.upperBound - range.lowerBound)
            let normalizedValue = CGFloat(value - range.lowerBound) / sliderRange
            let thumbyPosition = height - (normalizedValue * height)
            
            ZStack(alignment: .bottom) {
                // Track Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 4, height: height)
                
                // Active Track (Fill from bottom?) - Usually EQ sliders are just knobs on a track
                
                // Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 2)
                    .position(x: geo.size.width / 2, y: thumbyPosition)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let locationY = v.location.y
                        // Invert: Y=0 is max value (top)
                        // normalized = 1.0 - (y / height)
                        let percentage = 1.0 - (locationY / height)
                        let rawValue = Float(percentage) * Float(sliderRange) + range.lowerBound
                        let clamped = min(max(rawValue, range.lowerBound), range.upperBound)
                        value = clamped
                        onEditingChanged()
                    }
            )
        }
        .frame(width: 30) // Touch area
    }
}
