//
//  DominantColorExtractor.swift
//  SenkuPlayer
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class DominantColorExtractor {
    static let shared = DominantColorExtractor()
    
    // Wrapper for caching
    private class ColorWrapper {
        let color: Color
        init(_ color: Color) { self.color = color }
    }
    
    private let cache = NSCache<NSString, ColorWrapper>()
    
    private init() {
        cache.countLimit = 50
    }
    
    /// Extract dominant color for a Song
    func extractDominantColor(for song: Song) -> Color {
        let cacheKey = song.id.uuidString as NSString
        
        if let cached = cache.object(forKey: cacheKey) {
            return cached.color
        }
        
        guard let data = song.artworkData else {
            return ModernTheme.pureBlack
        }
        
        #if os(iOS)
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return ModernTheme.pureBlack }
        #elseif os(macOS)
        guard let image = NSImage(data: data), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return ModernTheme.pureBlack }
        #endif
        
        let color = performExtraction(from: cgImage)
        cache.setObject(ColorWrapper(color), forKey: cacheKey)
        return color
    }
    
    private func performExtraction(from cgImage: CGImage) -> Color {
        let size = 40
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * size
        var pixelData = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return ModernTheme.pureBlack }
        
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        
        var r: Int = 0, g: Int = 0, b: Int = 0, count: Int = 0
        for i in 0..<(size * size) {
            let offset = i * bytesPerPixel
            r += Int(pixelData[offset])
            g += Int(pixelData[offset + 1])
            b += Int(pixelData[offset + 2])
            count += 1
        }
        
        let factor: Double = 255.0 * Double(count)
        // Adjusted for Neon Theme: Darker background allows Neon Accents to pop
        let brightnessFactor = 0.35
        
        return Color(
            red: (Double(r) / factor) * brightnessFactor,
            green: (Double(g) / factor) * brightnessFactor,
            blue: (Double(b) / factor) * brightnessFactor
        )
    }
}
