//
//  ArtworkCacheManager.swift
//  SenkuPlayer
//
//  High-performance image cache for music artwork.
//  Provides background decoding and memory-efficient storage.
//

import SwiftUI
import Combine

@MainActor
final class ArtworkCacheManager: ObservableObject {
    static let shared = ArtworkCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private var inProgressTasks: [NSString: Task<UIImage?, Never>] = [:]
    
    private init() {
        cache.countLimit = 300 // Increased cache limit
        cache.totalCostLimit = 1024 * 1024 * 150 // 150MB limit
    }
    
    func getImage(for song: Song, size: CGFloat) async -> UIImage? {
        let cacheKey = "\(song.id.uuidString)-\(Int(size))" as NSString
        
        // 1. Check Memory Cache
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        // 2. Check if a task is already decoding this image
        if let task = inProgressTasks[cacheKey] {
            return await task.value
        }
        
        // 3. Start new background decoding task
        let task = Task<UIImage?, Never> {
            guard let data = song.artworkData else { return nil }
            
            // Decode in background thread
            return await Task.detached(priority: .userInitiated) {
                // High-performance decoding using ImageSource (more memory efficient than UIImage(data:))
                guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                    return nil
                }
                
                let originalImage = UIImage(cgImage: cgImage)
                
                // Downsample to target size to save VRAM
                let targetSize = CGSize(width: size, height: size)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let downsampled = renderer.image { _ in
                    originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                
                return downsampled
            }.value
        }
        
        inProgressTasks[cacheKey] = task
        let finalImage = await task.value
        inProgressTasks[cacheKey] = nil
        
        if let image = finalImage {
            cache.setObject(image, forKey: cacheKey, cost: Int(size * size * 4))
        }
        
        return finalImage
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

/// A highly optimized view for displaying song artwork with caching and background decoding.
struct CachedArtworkView: View {
    let song: Song
    let size: CGFloat
    var cornerRadius: CGFloat? = nil
    
    @State private var image: UIImage? = nil
    @State private var currentSongId: UUID? = nil
    
    private var effectiveCornerRadius: CGFloat {
        cornerRadius ?? size * 0.15
    }
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ModernTheme.backgroundSecondary
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.35))
                            .foregroundColor(ModernTheme.textTertiary.opacity(0.5))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
        .task(id: song.id) {
            // Only update if song changed or image is nil
            if currentSongId != song.id {
                currentSongId = song.id
                image = await ArtworkCacheManager.shared.getImage(for: song, size: size)
            }
        }
    }
}
