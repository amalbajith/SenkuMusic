//
//  PlatformExtensions.swift
//  SenkuPlayer
//

import SwiftUI
import CoreImage

// MARK: - Cross-Platform Image & Color

import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor


extension PlatformColor {
    static var secondaryBackground: PlatformColor {
        
        return .secondarySystemBackground
        
    }
}

// MARK: - Image View Extension
extension Image {
    init(platformImage: PlatformImage) {
        
        self.init(uiImage: platformImage)
        
    }
}

// MARK: - Color Extension
extension Color {
    init(platformColor: PlatformColor) {
        
        self.init(uiColor: platformColor)
        
    }
}

// MARK: - PlatformImage Extensions
extension PlatformImage {
    nonisolated static func fromData(_ data: Data) -> PlatformImage? {
        return PlatformImage(data: data)
    }
}

// MARK: - Device Info
struct DeviceInfo {
    static var name: String {
        
        return UIDevice.current.name
        
    }
}

// MARK: - Numeric Helpers
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
