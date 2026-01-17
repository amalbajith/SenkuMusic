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
    // MARK: - Colors (Cyberpunk Acid Palette)
    
    /// Primary accent color - Acid Yellow
    static let accentYellow = Color(hex: "#CCFF00")
    
    /// Pure black for deep background
    static let pureBlack = Color(hex: "#000000")
    
    /// Primary background - Void Black
    static let backgroundPrimary = Color(hex: "#000000")
    
    /// Secondary background - Deep Carbon (for lists/surfaces)
    static let backgroundSecondary = Color(hex: "#0A0A0A")
    
    /// Card background - Matte Black
    static let darkGray = Color(hex: "#111111")
    
    /// Medium gray for secondary elements/borders
    static let mediumGray = Color(hex: "#1A1A1A")
    
    /// Light gray for secondary text
    static let lightGray = Color(hex: "#9E9E9E")
    
    /// Subtle border color
    static let borderSubtle = Color.white.opacity(0.15)
    
    // MARK: - Gradients
    
    static let cardGradient = LinearGradient(
        colors: [Color(hex: "#111111"), Color(hex: "#1A1A1A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#CCFF00"), Color(hex: "#E0FF4F")], // Acid Yellow to Bright Lime
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "#000000"), Color(hex: "#0A0A0A")],
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
            .foregroundColor(.white)
            .padding(.horizontal, 24)
    }
}

struct CardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ModernTheme.backgroundSecondary)
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
