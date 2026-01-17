//
//  AudioWaveformAnalyzer.swift
//  SenkuPlayer
//

import Foundation
import AVFoundation

class AudioWaveformAnalyzer {
    static let shared = AudioWaveformAnalyzer()
    
    private let cache = NSCache<NSURL, NSArray>()
    
    private init() {
        cache.countLimit = 30 // Cache waveforms for last 30 songs
    }
    
    func extractWaveform(from url: URL, sampleCount: Int = 50, completion: @escaping ([Float]) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) as? [Float] {
            completion(cached)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let samples = self?.extractStreamingSamples(from: url, targetCount: sampleCount) else {
                DispatchQueue.main.async { completion(self?.generateFallback(count: sampleCount) ?? []) }
                return
            }
            
            self?.cache.setObject(samples as NSArray, forKey: url as NSURL)
            DispatchQueue.main.async { completion(samples) }
        }
    }
    
    /// Optimized sample extraction using buffered reading to minimize memory usage
    private func extractStreamingSamples(from url: URL, targetCount: Int) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        
        let totalFrames = AVAudioFrameCount(file.length)
        let framesPerSample = totalFrames / AVAudioFrameCount(targetCount)
        let bufferSize = min(framesPerSample, 32768) // Max 32k frames at once
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: bufferSize) else { return nil }
        
        var samples: [Float] = []
        
        for i in 0..<targetCount {
            let startFrame = Int64(i) * Int64(framesPerSample)
            file.framePosition = startFrame
            
            do {
                try file.read(into: buffer)
                if let channelData = buffer.floatChannelData?.pointee {
                    var sum: Float = 0
                    for j in 0..<Int(buffer.frameLength) {
                        sum += channelData[j] * channelData[j]
                    }
                    samples.append(sqrt(sum / Float(buffer.frameLength)))
                } else {
                    samples.append(0)
                }
            } catch {
                samples.append(0)
            }
        }
        
        // Normalize
        if let maxVal = samples.max(), maxVal > 0 {
            return samples.map { $0 / maxVal }
        }
        return samples
    }
    
    private func generateFallback(count: Int) -> [Float] {
        return (0..<count).map { Float($0) / Float(count) }
    }
}
