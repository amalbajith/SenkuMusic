//
//  EqualizerManager.swift
//  SenkuPlayer
//
//  Professional 10-band equalizer manager.
//  Integrates with AudioPlayerManager to provide high-quality audio shaping.
//

import Foundation
import AVFoundation
import Combine

class EqualizerManager: ObservableObject {
    static let shared = EqualizerManager()
    
    @Published var isEnabled = false {
        didSet { applySettings() }
    }
    
    // 10 bands (32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz)
    @Published var gains: [Float] = Array(repeating: 0.0, count: 10) {
        didSet { applySettings() }
    }
    
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var audioManager: AudioPlayerManager?
    
    private init() {
        setupBands()
    }
    
    func attach(to manager: AudioPlayerManager) {
        self.audioManager = manager
        manager.attach(eqNode)
    }
    
    private func setupBands() {
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for i in 0..<frequencies.count {
            let band = eqNode.bands[i]
            band.filterType = .parametric
            band.frequency = frequencies[i]
            band.bandwidth = 1.0
            band.bypass = false
            band.gain = 0.0
        }
    }
    
    private func applySettings() {
        for i in 0..<gains.count {
            eqNode.bands[i].gain = isEnabled ? gains[i] : 0.0
        }
    }
    
    // MARK: - Presets
    enum Preset: String, CaseIterable {
        case flat = "Flat"
        case bassBoost = "Bass Boost"
        case acoustic = "Acoustic"
        case electronic = "Electronic"
        case vocal = "Vocal Enhancer"
        
        var gains: [Float] {
            switch self {
            case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            case .bassBoost: return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
            case .acoustic: return [3, 2, 0, 1, 2, 2, 4, 3, 2, 1]
            case .electronic: return [4, 3, 1, 0, -2, -1, 1, 3, 4, 5]
            case .vocal: return [-2, -2, -1, 1, 3, 4, 4, 3, 1, 0]
            }
        }
    }
    
    func applyPreset(_ preset: Preset) {
        gains = preset.gains
    }
}
