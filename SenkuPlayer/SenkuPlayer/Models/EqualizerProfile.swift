
import Foundation
import AVFoundation

struct EqualizerBand: Codable, Equatable, Identifiable {
    var id: Int { index }
    let index: Int
    let frequency: Float
    var gain: Float // In decibels (-12 to +12)
    
    var label: String {
        if frequency >= 1000 {
            return "\(Int(frequency / 1000))k"
        } else {
            return "\(Int(frequency))"
        }
    }
}

struct EqualizerProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var bands: [EqualizerBand]
    var isSystemPreset: Bool = false
    
    static let frequencies: [Float] = [32, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    
    static func defaultProfile() -> EqualizerProfile {
        let bands = frequencies.enumerated().map { index, freq in
            EqualizerBand(index: index, frequency: freq, gain: 0)
        }
        return EqualizerProfile(name: "Flat", bands: bands, isSystemPreset: true)
    }
    
    static var allPresets: [EqualizerProfile] {
        return [
            defaultProfile(),
            createPreset(name: "Bass Boost", gains: [9, 7, 5, 2, 0, 0, 0, 0, 0, 0]),
            createPreset(name: "Bass Reducer", gains: [-9, -7, -5, -2, 0, 0, 0, 0, 0, 0]),
            createPreset(name: "Treble Boost", gains: [0, 0, 0, 0, 0, 2, 4, 6, 8, 9]),
            createPreset(name: "Vocal Booster", gains: [-2, -2, -1, 3, 5, 5, 4, 3, 0, -1]),
            createPreset(name: "Electronic", gains: [5, 4, 2, 0, -2, 2, 1, 3, 5, 6]),
            createPreset(name: "Rock", gains: [5, 4, 3, 1, -1, -1, 0, 2, 4, 5]),
            createPreset(name: "Pop", gains: [-2, -1, 2, 4, 5, 4, 2, -1, -2, -2]),
            createPreset(name: "Jazz", gains: [3, 2, 1, 2, -2, -2, 0, 1, 3, 4])
        ]
    }
    
    private static func createPreset(name: String, gains: [Float]) -> EqualizerProfile {
        let bands = zip(frequencies, gains).enumerated().map { index, pair in
            EqualizerBand(index: index, frequency: pair.0, gain: pair.1)
        }
        return EqualizerProfile(name: name, bands: bands, isSystemPreset: true)
    }
}
