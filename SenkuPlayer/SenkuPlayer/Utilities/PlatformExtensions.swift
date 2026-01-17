//
//  PlatformExtensions.swift
//  SenkuPlayer
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
}

// MARK: - Device Info
struct DeviceInfo {
    static var name: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }
}
