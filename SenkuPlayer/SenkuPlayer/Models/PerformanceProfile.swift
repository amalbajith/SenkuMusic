//
//  PerformanceProfile.swift
//  SenkuPlayer
//
//  Created for Eco Mode
//

import Foundation

enum PerformanceProfile: String, CaseIterable, Identifiable {
    case eco = "Eco"
    case balanced = "Balanced"
    case ultra = "Ultra"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .eco: return "Disables heavy blur effects and background analysis to save battery."
        case .balanced: return "Standard glassmorphic blur and animations."
        case .ultra: return "Maximum animations and real-time dominant color extraction."
        }
    }
}
