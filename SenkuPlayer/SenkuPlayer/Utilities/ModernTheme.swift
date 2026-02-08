//
//  ModernTheme.swift
//  SenkuPlayer
//
//  Premium Cyberpunk Acid Design System
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ModernTheme {
    // MARK: - Colors (Refined Neon Graphite Palette)
    
    /// Primary accent color - Electric Lime
    static let accentYellow = Color(hex: "#C6F806")
    static let accentYellowSoft = Color(hex: "#E2FF70")
    static let accentYellowMuted = Color(hex: "#7A962A")
    
    static let pureBlack = Color(hex: "#000000")
    static let backgroundPrimary = Color(hex: "#070909")
    static let backgroundSecondary = Color(hex: "#101414")
    static let darkGray = Color(hex: "#151A1A")
    static let mediumGray = Color(hex: "#212828")
    static let lightGray = Color(hex: "#A8B3AF")
    static let textPrimary = Color(hex: "#F2F4F3")
    static let textSecondary = Color(hex: "#A8B3AF")
    static let textTertiary = Color(hex: "#6F7A76")
    static let success = Color(hex: "#42D58A")
    static let danger = Color(hex: "#FF5D6E")
    static let borderSubtle = Color.white.opacity(0.15)
    static let borderStrong = accentYellow.opacity(0.35)
    
    // MARK: - Gradients
    
    static let cardGradient = LinearGradient(
        colors: [Color(hex: "#121818"), Color(hex: "#1D2424")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [accentYellow, accentYellowSoft],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [backgroundPrimary, Color(hex: "#0D1111")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let pillRadius: CGFloat = 22
    static let cardRadius: CGFloat = 20
    static let smallRadius: CGFloat = 12
    
    // MARK: - Shadows
    
    static let cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
        Color.white.opacity(0.05), 20, 0, 10
    )
    
    static let buttonShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
        Color.black.opacity(0.5), 10, 0, 5
    )
    
    // MARK: - Spacing
    
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    
    // MARK: - Layout Constants (Production Polish)
    
    /// Standard horizontal padding for main screen content
    static let screenPadding: CGFloat = 24
    
    /// Standard padding inside cards and sections
    static let cardPadding: CGFloat = 16
    
    /// Standard padding for list items and nested content
    static let itemPadding: CGFloat = 12
    
    /// Minimal padding for small elements (icons, compact layouts)
    static let miniPadding: CGFloat = 8
    
    // MARK: - Typography
    
    static func heroTitle() -> Font {
        .system(size: 34, weight: .bold)
    }
    
    static func title() -> Font {
        .system(size: 28, weight: .bold)
    }
    
    static func headline() -> Font {
        .system(size: 20, weight: .bold)
    }
    
    static func body() -> Font {
        .system(size: 16, weight: .semibold)
    }
    
    static func caption() -> Font {
        .system(size: 13, weight: .regular)
    }
    
    static func labelMuted() -> Font {
        .system(size: 12, weight: .medium)
    }
}

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glassmorphism & Common UI Modifiers

struct GlassmorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.1
    
    func body(content: Content) -> some View {
        content
            .background(.white.opacity(opacity))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ModernTheme.borderSubtle, lineWidth: 1)
            }
            .cornerRadius(cornerRadius)
    }
}

struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ModernTheme.headline())
            .foregroundColor(ModernTheme.textPrimary)
            .padding(.horizontal, 24)
    }
}

struct CardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ModernTheme.cardGradient)
            .cornerRadius(ModernTheme.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ModernTheme.cardRadius)
                    .stroke(ModernTheme.borderSubtle, lineWidth: 1)
            )
    }
}

struct PillButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ModernTheme.body())
            .foregroundColor(ModernTheme.pureBlack)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(ModernTheme.accentGradient)
            .cornerRadius(ModernTheme.pillRadius)
            .shadow(
                color: Color.white.opacity(0.2),
                radius: 10,
                x: 0,
                y: 5
            )
    }
}

extension View {
    func glassmorphism(cornerRadius: CGFloat = 20, opacity: Double = 0.1) -> some View {
        modifier(GlassmorphismModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderModifier())
    }
    
    func cardBackground() -> some View {
        modifier(CardBackgroundModifier())
    }
    
    func pillButtonStyle() -> some View {
        modifier(PillButtonModifier())
    }
}

// MARK: - String Extension for Text Normalization

extension String {
    var normalizedForDisplay: String {
        let isAllCaps = self == self.uppercased()
        let isAllLower = self == self.lowercased()
        
        if isAllCaps || isAllLower {
            return self.localizedCapitalized
        }
        
        return self
    }
}
