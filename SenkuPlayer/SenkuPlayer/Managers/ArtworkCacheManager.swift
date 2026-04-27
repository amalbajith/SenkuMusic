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
    
    @Published private var _cacheToken = UUID() // Dummy to ensure protocol compliance
    
    private let cache = NSCache<NSString, UIImage>()
    private var inProgressTasks: [UUID: Task<UIImage?, Never>] = [:]
    
    private init() {
        cache.countLimit = 200 // Cache up to 200 decoded images
        cache.totalCostLimit = 1024 * 1024 * 100 // 100MB limit
    }
    
    func getImage(for song: Song, size: CGFloat = 100) async -> UIImage? {
        let cacheKey = "\(song.id.uuidString)-\(Int(size))" as NSString
        
        // 1. Check Memory Cache
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        // 2. Check if a task is already decoding this image
        if let task = inProgressTasks[song.id] {
            return await task.value
        }
        
        // 3. Start new background decoding task
        let task = Task<UIImage?, Never> {
            guard let data = song.artworkData else { return nil }
            
            // Decode in background thread
            return await Task.detached(priority: .userInitiated) {
                guard let image = UIImage(data: data) else { return nil }
                
                // Downsample for performance if needed
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                let downsampled = renderer.image { _ in
                    image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
                }
                
                return downsampled
            }.value
        }
        
        inProgressTasks[song.id] = task
        let finalImage = await task.value
        inProgressTasks[song.id] = nil
        
        if let image = finalImage {
            cache.setObject(image, forKey: cacheKey, cost: Int(size * size * 4))
        }
        
        return finalImage
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

struct CachedArtworkView: View {
    let song: Song
    let size: CGFloat
    @State private var image: UIImage?
    
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
                            .font(.system(size: size * 0.4))
                            .foregroundColor(ModernTheme.lightGray)
                    )
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(size * 0.15)
        .task(id: song.id) {
            image = await ArtworkCacheManager.shared.getImage(for: song, size: size)
        }
    }
}
