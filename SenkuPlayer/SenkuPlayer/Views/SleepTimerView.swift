//
//  SleepTimerView.swift
//  SenkuPlayer
//

import SwiftUI

struct SleepTimerView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss

    private let presets: [(label: String, minutes: Double)] = [
        ("5 min",   5),
        ("10 min",  10),
        ("15 min",  15),
        ("20 min",  20),
        ("30 min",  30),
        ("45 min",  45),
        ("1 hour",  60),
        ("90 min",  90),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // ── Active Timer Display ──────────────────────
                        if player.sleepTimerRemaining > 0 {
                            activeTimerCard
                        }

                        // ── Presets ───────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Set Timer")
                                .font(ModernTheme.headline())
                                .foregroundColor(ModernTheme.textPrimary)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(presets, id: \.minutes) { preset in
                                    presetButton(label: preset.label, minutes: preset.minutes)
                                }
                            }
                        }

                        // ── Cancel ────────────────────────────────────
                        if player.sleepTimerRemaining > 0 {
                            Button {
                                player.cancelSleepTimer()
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Cancel Timer")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ModernTheme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(ModernTheme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ModernTheme.danger.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(ModernTheme.accentYellow)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Active Timer Card
    private var activeTimerCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 36))
                .foregroundColor(ModernTheme.accentYellow)

            Text(formatTime(player.sleepTimerRemaining))
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            Text("Music will stop when the timer ends")
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(ModernTheme.accentYellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(ModernTheme.accentYellow.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Preset Button
    private func presetButton(label: String, minutes: Double) -> some View {
        let isActive = player.sleepTimerRemaining > 0 &&
                       abs(player.sleepTimerRemaining - minutes * 60) < 60

        return Button {
            player.setSleepTimer(minutes: minutes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dismiss() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isActive ? ModernTheme.backgroundPrimary : ModernTheme.accentYellow)
                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? ModernTheme.backgroundPrimary : ModernTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isActive
                ? AnyShapeStyle(ModernTheme.accentGradient)
                : AnyShapeStyle(ModernTheme.backgroundSecondary.opacity(0.9))
            , in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isActive ? Color.clear : ModernTheme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }
}
