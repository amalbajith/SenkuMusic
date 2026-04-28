//
//  ArtworkCacheManager.swift
//  SenkuPlayer
//
//  Two-level artwork cache:
//    L1 – NSCache (in-memory, instant, cleared when app is killed)
//    L2 – Disk (persistent across launches, decoded once, never again)
//

import SwiftUI
import Combine

@MainActor
final class ArtworkCacheManager: ObservableObject {
    static let shared = ArtworkCacheManager()

    // L1 — memory cache (fast, ephemeral)
    private let memoryCache = NSCache<NSString, UIImage>()

    // L2 — disk cache directory (persistent)
    private let diskCacheURL: URL

    private var inProgressTasks: [NSString: Task<UIImage?, Never>] = [:]

    private init() {
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 1024 * 1024 * 150 // 150 MB

        // Use the system Caches directory — iOS automatically purges this under
        // disk pressure so we don't need manual size management.
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("SenkuArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func getImage(for song: Song, size: CGFloat) async -> UIImage? {
        let key = "\(song.id.uuidString)-\(Int(size))" as NSString

        // 1. L1 — memory hit (zero cost)
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // 2. L2 — disk hit (no decoding, just JPEG load)
        if let diskImage = await loadFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key, cost: Int(size * size * 4))
            return diskImage
        }

        // 3. Coalesce: don't decode the same image twice in parallel
        if let task = inProgressTasks[key] {
            return await task.value
        }

        // 4. Handle Remote vs Local decoding
        let task = Task<UIImage?, Never> {
            if song.isRemote, let thumbURL = song.thumbnailURL {
                // ── REMOTE CLOUD IMAGE ──────────────────────────
                do {
                    let (data, _) = try await URLSession.shared.data(from: thumbURL)
                    guard let original = UIImage(data: data) else { return nil }
                    
                    let targetSize = CGSize(width: size, height: size)
                    let renderer = UIGraphicsImageRenderer(size: targetSize)
                    let downsampled = renderer.image { _ in
                        original.draw(in: CGRect(origin: .zero, size: targetSize))
                    }
                    return downsampled
                } catch {
                    return nil
                }
            } else {
                // ── LOCAL EMBEDDED IMAGE ────────────────────────
                guard let data = song.artworkData else { return nil }
                return await Task.detached(priority: .userInitiated) {
                    guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                          let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { return nil }

                    let original = UIImage(cgImage: cgImage)
                    let targetSize = CGSize(width: size, height: size)
                    let renderer = UIGraphicsImageRenderer(size: targetSize)
                    let downsampled = renderer.image { _ in
                        original.draw(in: CGRect(origin: .zero, size: targetSize))
                    }
                    return downsampled
                }.value
            }
        }

        inProgressTasks[key] = task
        let image = await task.value
        inProgressTasks[key] = nil

        if let image {
            memoryCache.setObject(image, forKey: key, cost: Int(size * size * 4))
            // Persist to disk in the background — next launch loads this instead of decoding
            saveToDisk(image: image, key: key)
        }

        return image
    }

    // MARK: - Disk helpers

    private func diskURL(for key: NSString) -> URL {
        diskCacheURL.appendingPathComponent("\(key).jpg")
    }

    private func loadFromDisk(key: NSString) async -> UIImage? {
        let url = diskURL(for: key)
        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { return nil }
            return image
        }.value
    }

    private func saveToDisk(image: UIImage, key: NSString) {
        let url = diskURL(for: key)
        Task.detached(priority: .background) {
            // JPEG at 0.85 quality — visually lossless at thumbnail sizes, ~8–15 KB per file
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        // Also wipe disk cache (e.g. when user clears library)
        Task.detached(priority: .background) { [diskCacheURL] in
            try? FileManager.default.removeItem(at: diskCacheURL)
            try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Eager Pre-processing

    /// Call this after import or on launch. Runs entirely at .background priority —
    /// completely invisible to the UI — and skips any song already on disk.
    /// After this completes, every scroll is an instant disk/memory read, zero CPU decode.
    func preprocessArtwork(for songs: [Song]) {
        let cacheDir = diskCacheURL
        let thumbnailSize: CGFloat = 50

        // Only collect IDs on the main thread
        let songIDs = songs.map { $0.id }

        Task.detached(priority: .background) {
            for id in songIDs {
                let filename = "\(id.uuidString)-\(Int(thumbnailSize)).jpg"
                let fileURL = cacheDir.appendingPathComponent(filename)

                guard !FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                
                // Fetch data from disk on the background thread
                guard let data = ArtworkManager.shared.getArtwork(for: id),
                      let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { continue }

                let original = UIImage(cgImage: cgImage)
                let targetSize = CGSize(width: thumbnailSize, height: thumbnailSize)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let downsampled = renderer.image { _ in
                    original.draw(in: CGRect(origin: .zero, size: targetSize))
                }

                if let jpegData = downsampled.jpegData(compressionQuality: 0.85) {
                    try? jpegData.write(to: fileURL, options: .atomic)
                }

                await Task.yield()
            }
        }
    }
}


/// A highly optimized view for displaying song artwork with caching and background decoding.
struct CachedArtworkView: View {
    let song: Song?
    let size: CGFloat
    var cornerRadius: CGFloat? = nil

    @State private var image: UIImage? = nil
    @State private var currentSongId: UUID? = nil
    @State private var isLoaded = false

    private var effectiveCornerRadius: CGFloat {
        cornerRadius ?? size * 0.15
    }

    var body: some View {
        ZStack {
            // Placeholder — always present, fades out when image arrives
            ModernTheme.backgroundSecondary
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.35))
                        .foregroundColor(ModernTheme.textTertiary.opacity(0.5))
                )
                .opacity(isLoaded ? 0 : 1)

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(isLoaded ? 1 : 0)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
        .task(id: song?.id) {
            guard let song else {
                image = nil
                currentSongId = nil
                isLoaded = false
                return
            }
            if currentSongId != song.id {
                isLoaded = false
                currentSongId = song.id
                let loaded = await ArtworkCacheManager.shared.getImage(for: song, size: size)
                image = loaded
                if loaded != nil {
                    withAnimation(.easeInOut(duration: 0.2)) { isLoaded = true }
                }
            }
        }
    }
}
