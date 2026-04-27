//
//  Mood.swift
//  SenkuPlayer
//
//  Created for Mood-Based Smart Player
//

import SwiftUI
import Combine

enum Mood: String, CaseIterable, Identifiable {
    case chill = "Chill"
    case workout = "Workout"
    case focus = "Focus"
    case upbeat = "Upbeat"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chill: return "moon.stars.fill"
        case .workout: return "bolt.fill"
        case .focus: return "brain.head.profile"
        case .upbeat: return "sparkles"
        }
    }
    
    var color: Color {
        // Uniform polished glassmorphic color (frost/ice)
        return Color(white: 0.25)
    }
    
    var keywords: [String] {
        switch self {
        case .chill:
            return ["chill", "lo-fi", "lofi", "acoustic", "ambient", "classical", "jazz", "sleep", "relax", "slow", "piano"]
        case .workout:
            return ["workout", "edm", "house", "drum & bass", "dubstep", "metal", "hard rock", "mix", "hard", "bass", "intense", "gym", "trap"]
        case .focus:
            return ["focus", "study", "instrumental", "soundtrack", "synthwave", "beats", "code", "work"]
        case .upbeat:
            return ["upbeat", "party", "pop", "hip-hop", "dance", "rock", "happy", "k-pop", "summer", "groove"]
        }
    }
}
