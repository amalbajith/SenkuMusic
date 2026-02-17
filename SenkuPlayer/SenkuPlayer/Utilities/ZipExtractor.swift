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
        
        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "The file is not a valid zip archive."
            case .unsupportedCompression(let method): return "Unsupported compression method: \(method)."
            case .decompressionFailed: return "Failed to decompress a file in the archive."
            case .readError: return "Failed to read the archive."
            }
        }
    }
    
    /// Extracts a zip archive to the given destination directory.
    /// Returns the list of extracted file URLs.
    static func extract(zipURL: URL, to destination: URL) throws -> [URL] {
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
            let signature = data.readUInt32(at: offset)
            guard signature == localHeaderSignature else { break }
            
            // Parse local file header
            let compressionMethod = data.readUInt16(at: offset + 8)
            let compressedSize = Int(data.readUInt32(at: offset + 18))
            let uncompressedSize = Int(data.readUInt32(at: offset + 22))
            let fileNameLength = Int(data.readUInt16(at: offset + 26))
            let extraFieldLength = Int(data.readUInt16(at: offset + 28))
            
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
                // Sanitize path — use only the last component to avoid directory traversal
                let sanitizedName = URL(fileURLWithPath: fileName).lastPathComponent
                let outputURL = destination.appendingPathComponent(sanitizedName)
                
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
    private static func decompress(data: Data, expectedSize: Int) -> Data? {
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
}

// MARK: - Data Helpers for Reading Little-Endian Values

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return self.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }
    
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return self.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
}
