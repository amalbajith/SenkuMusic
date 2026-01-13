//
//  PlatformExtensions.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import CoreImage

// MARK: - Cross-Platform Image & Color
#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#endif

extension PlatformColor {
    static var secondaryBackground: PlatformColor {
        #if os(macOS)
        return .windowBackgroundColor
        #else
        return .secondarySystemBackground
        #endif
    }
    
    static var tertiaryBackground: PlatformColor {
        #if os(macOS)
        return .controlBackgroundColor
        #else
        return .tertiarySystemBackground
        #endif
    }
}

// MARK: - Image View Extension
extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

// MARK: - Platform Utils
struct PlatformUtils {
    static var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #else
        return UIDevice.current.name
        #endif
    }
    
    static var screenWidth: CGFloat {
        #if os(macOS)
        return NSScreen.main?.frame.width ?? 800
        #else
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return windowScene?.screen.bounds.width ?? 375
        #endif
    }
    
    static var screenHeight: CGFloat {
        #if os(macOS)
        return NSScreen.main?.frame.height ?? 600
        #else
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return windowScene?.screen.bounds.height ?? 812
        #endif
    }
}

// MARK: - Color Extension
extension Color {
    init(platformColor: PlatformColor) {
        #if os(macOS)
        self.init(nsColor: platformColor)
        #else
        self.init(uiColor: platformColor)
        #endif
    }
}

// MARK: - PlatformImage Extensions
extension PlatformImage {
    static func fromData(_ data: Data) -> PlatformImage? {
        return PlatformImage(data: data)
    }
    
    var averageColor: PlatformColor? {
        #if os(macOS)
        guard let tiffData = tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmapRep) else { return nil }
        #else
        guard let ciImage = CIImage(image: self) else { return nil }
        #endif
        
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var pixelData = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &pixelData, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return PlatformColor(red: CGFloat(pixelData[0]) / 255, green: CGFloat(pixelData[1]) / 255, blue: CGFloat(pixelData[2]) / 255, alpha: CGFloat(pixelData[3]) / 255)
    }
}
