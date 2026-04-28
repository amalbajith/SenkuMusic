//
//  EqualizerView.swift
//  SenkuPlayer
//

import SwiftUI

struct EqualizerView: View {
    @StateObject private var eqManager = EqualizerManager.shared
    @Environment(\.dismiss) private var dismiss

    private let freqLabels = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // ── Header ──────────────────────────────
                        VStack(spacing: 4) {
                            Text("Equalizer")
                                .font(ModernTheme.title())
                                .foregroundColor(.white)
                            Text("Fine-tune your audio experience")
                                .font(ModernTheme.caption())
                                .foregroundColor(ModernTheme.textSecondary)
                        }
                        .padding(.top, 8)

                        // ── Enable toggle ────────────────────────
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
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ModernTheme.backgroundSecondary.opacity(0.7))
                        )
                        .padding(.horizontal)

                        // ── Presets ──────────────────────────────
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(EqualizerManager.Preset.allCases, id: \.self) { preset in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            eqManager.applyPreset(preset)
                                        }
                                    } label: {
                                        Text(preset.rawValue)
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(isPresetActive(preset)
                                                          ? ModernTheme.accentYellow
                                                          : ModernTheme.backgroundSecondary)
                                            )
                                            .foregroundColor(isPresetActive(preset) ? .black : .white)
                                    }
                                    .buttonStyle(PressEffect(scale: 0.93))
                                }
                            }
                            .padding(.horizontal)
                        }

                        // ── Curve ────────────────────────────────
                        ZStack {
                            // Zero line
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)

                            EQCurveView(gains: eqManager.gains)
                                .stroke(
                                    LinearGradient(
                                        colors: [ModernTheme.accentYellow, ModernTheme.accentYellow.opacity(0.4)],
                                        startPoint: .top, endPoint: .bottom
                                    ),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                                )
                                .animation(.easeOut(duration: 0.15), value: eqManager.gains)
                        }
                        .frame(height: 100)
                        .padding(.horizontal)
                        .opacity(eqManager.isEnabled ? 1 : 0.3)

                        // ── Sliders ──────────────────────────────
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(0..<10, id: \.self) { index in
                                VStack(spacing: 10) {
                                    // dB readout
                                    Text(gainLabel(eqManager.gains[index]))
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundColor(eqManager.gains[index] == 0
                                                         ? ModernTheme.textSecondary
                                                         : ModernTheme.accentYellow)
                                        .frame(height: 14)

                                    EQSlider(value: $eqManager.gains[index])

                                    Text(freqLabels[index])
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(ModernTheme.textSecondary)
                                        .frame(height: 14)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 8)
                        .opacity(eqManager.isEnabled ? 1 : 0.35)
                        .disabled(!eqManager.isEnabled)

                        // ── Reset ────────────────────────────────
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                for i in eqManager.gains.indices { eqManager.gains[i] = 0 }
                            }
                        } label: {
                            Label("Reset to Flat", systemImage: "arrow.counterclockwise")
                                .font(ModernTheme.body())
                                .foregroundColor(ModernTheme.textSecondary)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(PressEffect(scale: 0.95))

                        Spacer(minLength: 40)
                    }
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
        eqManager.gains == preset.gains
    }

    private func gainLabel(_ gain: Float) -> String {
        gain == 0 ? "0" : String(format: "%+.0f", gain)
    }
}

// MARK: - EQ Slider

struct EQSlider: View {
    @Binding var value: Float

    private let trackHeight: CGFloat = 150
    private let trackWidth: CGFloat  = 4
    private let thumbDiameter: CGFloat = 16
    private let range: ClosedRange<Float> = -12...12

    // Fraction 0→bottom, 1→top
    private var normalized: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    // Thumb offset from center (negative = up)
    private var thumbOffset: CGFloat {
        (trackHeight / 2) * (1 - 2 * normalized)
    }

    var body: some View {
        ZStack {
            // Background track
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(width: trackWidth, height: trackHeight)

            // Center reference line
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: trackWidth + 4, height: 1)

            // Active fill — from centre to thumb
            if abs(thumbOffset) > 2 {
                Capsule()
                    .fill(ModernTheme.accentYellow.opacity(0.65))
                    .frame(width: trackWidth, height: abs(thumbOffset))
                    .offset(y: thumbOffset / 2)
            }

            // Thumb
            Circle()
                .fill(value == 0 ? Color.white.opacity(0.7) : ModernTheme.accentYellow)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .shadow(color: ModernTheme.accentYellow.opacity(value == 0 ? 0 : 0.5), radius: 5)
                .offset(y: thumbOffset)
        }
        .frame(width: 34, height: trackHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    let pct = 1.0 - min(max(gesture.location.y / trackHeight, 0), 1)
                    let raw = Float(pct) * (range.upperBound - range.lowerBound) + range.lowerBound
                    value = min(max(raw, range.lowerBound), range.upperBound)
                }
        )
    }
}

// MARK: - EQ Curve

struct EQCurveView: Shape {
    var gains: [Float]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard gains.count >= 2 else { return path }

        let midY    = rect.height / 2
        let scaleY  = rect.height / 28.0  // -12…+12 = 24 range, with padding
        let stepX   = rect.width / CGFloat(gains.count - 1)

        let pts = gains.enumerated().map { i, g -> CGPoint in
            CGPoint(
                x: CGFloat(i) * stepX,
                y: midY - CGFloat(g) * scaleY
            )
        }

        path.move(to: pts[0])

        // Catmull-Rom → cubic Bézier approximation for a smooth curve
        for i in 1..<pts.count {
            let prev = pts[max(i - 2, 0)]
            let p0   = pts[i - 1]
            let p1   = pts[i]
            let next = pts[min(i + 1, pts.count - 1)]

            let cp1 = CGPoint(
                x: p0.x + (p1.x - prev.x) / 6,
                y: p0.y + (p1.y - prev.y) / 6
            )
            let cp2 = CGPoint(
                x: p1.x - (next.x - p0.x) / 6,
                y: p1.y - (next.y - p0.y) / 6
            )
            path.addCurve(to: p1, control1: cp1, control2: cp2)
        }

        return path
    }
}
