//
//  EqualizerView.swift
//  SenkuPlayer
//
//  Professional Equalizer UI for audio shaping.
//  Provides interactive sliders and real-time visualization.
//

import SwiftUI
import Combine

struct EqualizerView: View {
    @StateObject private var eqManager = EqualizerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 4) {
                        Text("Equalizer")
                            .font(ModernTheme.title())
                            .foregroundColor(.white)
                        
                        Text("Fine-tune your audio experience")
                            .font(ModernTheme.caption())
                            .foregroundColor(ModernTheme.textSecondary)
                    }
                    .padding(.top)
                    
                    // Toggle
                    HStack {
                        Text("Enable Equalizer")
                            .font(ModernTheme.body())
                            .foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $eqManager.isEnabled)
                            .tint(ModernTheme.accentYellow)
                            .labelsHidden()
                    }
                    .padding(.horizontal, ModernTheme.screenPadding)
                    .padding(.vertical, 12)
                    .background(ModernTheme.backgroundSecondary.opacity(0.5))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(EqualizerManager.Preset.allCases, id: \.self) { preset in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        eqManager.applyPreset(preset)
                                    }
                                } label: {
                                    Text(preset.rawValue)
                                        .font(ModernTheme.caption().bold())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(isPresetActive(preset) ? ModernTheme.accentYellow : ModernTheme.backgroundSecondary)
                                        .foregroundColor(isPresetActive(preset) ? .black : .white)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Visualization Curve
                    ZStack {
                        EqualizerCurve(gains: eqManager.gains)
                            .stroke(
                                LinearGradient(colors: [ModernTheme.accentYellow, ModernTheme.accentYellow.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                                lineWidth: 3
                            )
                            .shadow(color: ModernTheme.accentYellow.opacity(0.2), radius: 10, x: 0, y: 5)
                            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: eqManager.gains)
                    }
                    .frame(height: 120)
                    .padding(.horizontal)
                    
                    // Sliders
                    HStack(spacing: 8) {
                        ForEach(0..<10, id: \.self) { index in
                            VStack(spacing: 12) {
                                CustomVerticalSlider(
                                    value: $eqManager.gains[index],
                                    range: -12...12
                                )
                                
                                Text(getFreqLabel(index))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(ModernTheme.textSecondary)
                                    .frame(width: 30)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .opacity(eqManager.isEnabled ? 1.0 : 0.4)
                    .disabled(!eqManager.isEnabled)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ModernTheme.accentYellow)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func isPresetActive(_ preset: EqualizerManager.Preset) -> Bool {
        return eqManager.gains == preset.gains
    }
    
    private func getFreqLabel(_ index: Int) -> String {
        let labels = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
        return labels[index]
    }
}

struct EqualizerCurve: Shape {
    var gains: [Float]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard gains.count >= 2 else { return path }
        
        let width = rect.width
        let height = rect.height
        let midY = height / 2
        let scaleY = height / 28 // Range is -12 to 12 (+ padding)
        
        let stepX = width / CGFloat(gains.count - 1)
        
        let points = gains.enumerated().map { index, gain -> CGPoint in
            let x = CGFloat(index) * stepX
            let y = midY - (CGFloat(gain) * scaleY)
            return CGPoint(x: x, y: y)
        }
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let p1 = points[i-1]
            let p2 = points[i]
            let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            
            if i == 1 {
                path.addQuadCurve(to: mid, control: p1)
            } else {
                path.addQuadCurve(to: mid, control: p1)
            }
            
            if i == points.count - 1 {
                path.addQuadCurve(to: p2, control: p2)
            }
        }
        
        return path
    }
}

struct CustomVerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let sliderRange = CGFloat(range.upperBound - range.lowerBound)
            let normalizedValue = CGFloat(value - range.lowerBound) / sliderRange
            let thumbPosition = height - (normalizedValue * height)
            
            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(ModernTheme.backgroundSecondary)
                    .frame(width: 6, height: height)
                
                // Active Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(ModernTheme.accentYellow.opacity(0.3))
                    .frame(width: 6, height: height - thumbPosition)
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .position(x: geo.size.width / 2, y: thumbPosition)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let percentage = 1.0 - (gesture.location.y / height)
                        let rawValue = Float(percentage) * Float(sliderRange) + range.lowerBound
                        value = min(max(rawValue, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(width: 34)
    }
}
