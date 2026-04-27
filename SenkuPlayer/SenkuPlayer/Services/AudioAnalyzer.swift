//
//  AudioAnalyzer.swift
//  SenkuPlayer
//
//  Created for Audio Energy Analysis
//

import Foundation
import AVFoundation

class AudioAnalyzer {
    static let shared = AudioAnalyzer()
    
    private init() {}
    
    /// Analyzes the RMS (Root Mean Square) energy of the first 10 seconds of the song.
    /// Returns a normalized Float between 0.0 and 1.0 representing the energy.
    func analyzeEnergy(for url: URL) async -> Float? {
        return await Task.detached(priority: .background) {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                
                let durationToAnalyze: TimeInterval = 10.0
                let sampleRate = format.sampleRate
                let frameCount = AVAudioFrameCount(min(Double(file.length), durationToAnalyze * sampleRate))
                
                guard frameCount > 0 else { return nil }
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
                
                try file.read(into: buffer, frameCount: frameCount)
                
                guard let channelData = buffer.floatChannelData else { return nil }
                let channelCount = Int(format.channelCount)
                let actualFrameCount = Int(buffer.frameLength)
                
                var totalRMS: Float = 0.0
                
                for channel in 0..<channelCount {
                    let data = channelData[channel]
                    var sumSquares: Float = 0.0
                    for i in 0..<actualFrameCount {
                        let sample = data[i]
                        sumSquares += sample * sample
                    }
                    let rms = sqrt(sumSquares / Float(actualFrameCount))
                    totalRMS += rms
                }
                
                let averageRMS = totalRMS / Float(channelCount)
                
                // Normalize the RMS (typically RMS of music is around 0.1 to 0.3)
                let normalizedEnergy = min(max(averageRMS * 3.5, 0.0), 1.0)
                return normalizedEnergy
            } catch {
                print("Failed to analyze energy for \(url.lastPathComponent): \(error.localizedDescription)")
                return nil
            }
        }.value
    }
}
