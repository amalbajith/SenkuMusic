//
//  ZipExtractor.swift
//  SenkuPlayer
//
//  Lightweight zip extraction using Apple's Compression framework.
//  Supports Stored (no compression) and Deflate methods — covers virtually all zip files.
//

import Foundation
import Compression

struct ZipExtractor {
    
    enum ZipError: Error, LocalizedError {
        case invalidArchive
        case unsupportedCompression(UInt16)
        case decompressionFailed
        case readError
        case securityLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "The file is not a valid zip archive."
            case .unsupportedCompression(let method): return "Unsupported compression method: \(method)."
            case .decompressionFailed: return "Failed to decompress a file in the archive."
            case .readError: return "Failed to read the archive."
            case .securityLimitExceeded: return "Security limit exceeded: file is too large to decompress."
            }
        }
    }
    
    private static let MAX_DECOMPRESSION_SIZE = 200 * 1024 * 1024 // 200MB limit for security
    
    /// Extracts a zip archive to the given destination directory.
    /// Returns the list of extracted file URLs.
    nonisolated static func extract(zipURL: URL, to destination: URL) throws -> [URL] {
        let fileManager = FileManager.default
        
        // Create destination if needed
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }
        
        guard let data = try? Data(contentsOf: zipURL) else {
            throw ZipError.readError
        }
        
        var extractedFiles: [URL] = []
        var offset = 0
        
        // Local file header signature = 0x04034b50
        let localHeaderSignature: UInt32 = 0x04034b50
        
        while offset + 30 <= data.count {
            // Read signature
            let signature = Self.readUInt32(from: data, at: offset)
            guard signature == localHeaderSignature else { break }
            
            // Parse local file header
            let compressionMethod = Self.readUInt16(from: data, at: offset + 8)
            let compressedSize = Int(Self.readUInt32(from: data, at: offset + 18))
            let uncompressedSize = Int(Self.readUInt32(from: data, at: offset + 22))
            let fileNameLength = Int(Self.readUInt16(from: data, at: offset + 26))
            let extraFieldLength = Int(Self.readUInt16(from: data, at: offset + 28))
            
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + fileNameLength
            
            guard fileNameEnd <= data.count else { break }
            
            let fileNameData = data[fileNameStart..<fileNameEnd]
            let fileName = String(data: fileNameData, encoding: .utf8) ?? ""
            
            let dataStart = fileNameEnd + extraFieldLength
            let dataEnd = dataStart + compressedSize
            
            guard dataEnd <= data.count else { break }
            
            // Skip directories and hidden/metadata files
            if !fileName.hasSuffix("/") && !fileName.hasPrefix("__MACOSX") && !fileName.contains("/.") {
                // Security: Prevent Zip Bomb
                guard uncompressedSize <= MAX_DECOMPRESSION_SIZE else {
                    throw ZipError.securityLimitExceeded
                }
                
                // Security & Bug Fix: Sanitize path and support subdirectories
                // 1. Remove any leading slashes or ".." components
                let sanitizedPath = fileName.components(separatedBy: "/")
                    .filter { !$0.isEmpty && $0 != ".." && $0 != "." }
                    .joined(separator: "/")
                
                let outputURL = destination.appendingPathComponent(sanitizedPath)
                
                // 2. Ensure the resulting path is still within the destination
                guard outputURL.path.hasPrefix(destination.path) else {
                    offset = dataEnd
                    continue
                }
                
                // Create parent directories if needed
                let parentDir = outputURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: parentDir.path) {
                    try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                }
                
                let compressedData = data[dataStart..<dataEnd]
                
                switch compressionMethod {
                case 0: // Stored (no compression)
                    try Data(compressedData).write(to: outputURL)
                    extractedFiles.append(outputURL)
                    
                case 8: // Deflate
                    if let decompressed = decompress(data: Data(compressedData), expectedSize: uncompressedSize) {
                        try decompressed.write(to: outputURL)
                        extractedFiles.append(outputURL)
                    } else {
                        print("⚠️ ZipExtractor: Failed to decompress \(fileName)")
                    }
                    
                default:
                    print("⚠️ ZipExtractor: Skipping \(fileName) — unsupported compression method \(compressionMethod)")
                }
            }
            
            offset = dataEnd
        }
        
        return extractedFiles
    }
    
    /// Decompress deflate data using Apple's Compression framework.
    /// We use the raw DEFLATE algorithm (COMPRESSION_ZLIB with raw flag handling).
    nonisolated private static func decompress(data: Data, expectedSize: Int) -> Data? {
        // Security: Prevent extremely large buffers
        guard expectedSize <= MAX_DECOMPRESSION_SIZE else { return nil }
        
        // Use a reasonable buffer size — at least expectedSize, with a minimum
        let bufferSize = max(expectedSize, 65536)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        let result = data.withUnsafeBytes { (srcPointer: UnsafeRawBufferPointer) -> Int in
            guard let srcBase = srcPointer.baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer, bufferSize,
                srcBase.assumingMemoryBound(to: UInt8.self), data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard result > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: result)
    }
    
    /// Creates a ZIP archive (Stored/no-compression) from all files in a directory.
    nonisolated static func compress(directory: URL, to destination: URL) throws {
        var zipData = Data()
        let fm = FileManager.default
        var centralDir = Data()
        var localHeaders: [(offset: UInt32, name: Data, size: UInt32)] = []
        
        let allFiles = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        
        for fileURL in allFiles {
            guard !fileURL.hasDirectoryPath else { continue }
            let fileData = (try? Data(contentsOf: fileURL)) ?? Data()
            let nameData = Data(fileURL.lastPathComponent.utf8)
            let offset = UInt32(zipData.count)
            
            // Local file header
            var local = Data()
            Self.appendUInt32(to: &local, 0x04034b50) // signature
            Self.appendUInt16(to: &local, 20)          // version needed
            Self.appendUInt16(to: &local, 0)           // flags
            Self.appendUInt16(to: &local, 0)           // compression: Stored
            Self.appendUInt16(to: &local, 0)           // mod time
            Self.appendUInt16(to: &local, 0)           // mod date
            Self.appendUInt32(to: &local, 0)           // CRC32 (skip for simplicity)
            Self.appendUInt32(to: &local, UInt32(fileData.count)) // compressed size
            Self.appendUInt32(to: &local, UInt32(fileData.count)) // uncompressed size
            Self.appendUInt16(to: &local, UInt16(nameData.count))
            Self.appendUInt16(to: &local, 0)           // extra field length
            local.append(nameData)
            local.append(fileData)
            zipData.append(local)
            
            localHeaders.append((offset: offset, name: nameData, size: UInt32(fileData.count)))
        }
        
        let centralDirOffset = UInt32(zipData.count)
        for h in localHeaders {
            var entry = Data()
            Self.appendUInt32(to: &entry, 0x02014b50)  // central dir signature
            Self.appendUInt16(to: &entry, 20)           // version made by
            Self.appendUInt16(to: &entry, 20)           // version needed
            Self.appendUInt16(to: &entry, 0); Self.appendUInt16(to: &entry, 0); Self.appendUInt16(to: &entry, 0); Self.appendUInt16(to: &entry, 0)
            Self.appendUInt32(to: &entry, 0)            // CRC32
            Self.appendUInt32(to: &entry, h.size); Self.appendUInt32(to: &entry, h.size)
            Self.appendUInt16(to: &entry, UInt16(h.name.count))
            Self.appendUInt16(to: &entry, 0); Self.appendUInt16(to: &entry, 0); Self.appendUInt16(to: &entry, 0); Self.appendUInt16(to: &entry, 0)
            Self.appendUInt32(to: &entry, 0); Self.appendUInt32(to: &entry, h.offset)
            entry.append(h.name)
            centralDir.append(entry)
        }
        
        zipData.append(centralDir)
        
        // End of central directory
        var eocd = Data()
        Self.appendUInt32(to: &eocd, 0x06054b50)
        Self.appendUInt16(to: &eocd, 0); Self.appendUInt16(to: &eocd, 0)
        Self.appendUInt16(to: &eocd, UInt16(localHeaders.count)); Self.appendUInt16(to: &eocd, UInt16(localHeaders.count))
        Self.appendUInt32(to: &eocd, UInt32(centralDir.count)); Self.appendUInt32(to: &eocd, centralDirOffset)
        Self.appendUInt16(to: &eocd, 0)
        zipData.append(eocd)
        
        try zipData.write(to: destination)
    }
    
    nonisolated private static func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        var value: UInt16 = 0
        let _ = withUnsafeMutableBytes(of: &value) { bytes in
            data.copyBytes(to: bytes, from: offset..<offset+2)
        }
        return value.littleEndian
    }
    
    nonisolated private static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        var value: UInt32 = 0
        let _ = withUnsafeMutableBytes(of: &value) { bytes in
            data.copyBytes(to: bytes, from: offset..<offset+4)
        }
        return value.littleEndian
    }
    
    nonisolated private static func appendUInt16(to data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }
    
    nonisolated private static func appendUInt32(to data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 4))
    }
}
