//
//  SpotifyDownloader.swift
//  SenkuPlayer
//
//  Created for SenkuMusic on macOS
//

import Foundation
import Combine

#if os(macOS)
class SpotifyDownloader: ObservableObject {
    static let shared = SpotifyDownloader()
    
    @Published var isDownloading = false
    @Published var logs: String = ""
    @Published var downloadProgress: Double = 0.0
    
    private var task: Process?
    private var outputPipe: Pipe?
    
    // Paths where spotdl might be located
    private let possiblePaths = [
        "/opt/homebrew/bin/spotdl",
        "/usr/local/bin/spotdl",
        "/usr/bin/spotdl",
        "/Users/\(NSUserName())/Library/Python/3.9/bin/spotdl", // Common pip install location
        "/Users/\(NSUserName())/Library/Python/3.8/bin/spotdl"
    ]
    
    func download(url: String) {
        guard !url.isEmpty else { return }
        
        // Find spotdl
        guard let executablePath = findSpotDL() else {
            appendLog("❌ Error: 'spotdl' not found.\nPlease install it using: pip install spotdl\nor: brew install spotdl")
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        logs = "🚀 Starting Download...\n"
        
        let musicDir = MusicLibraryManager.shared.getMusicDirectory()
        
        task = Process()
        outputPipe = Pipe()
        
        task?.executableURL = URL(fileURLWithPath: executablePath)
        task?.currentDirectoryURL = musicDir
        
        // Arguments: Download to music directory
        // --output "{artist} - {title}.{ext}" ensures clean filenames
        task?.arguments = [
            url,
            "--output", "{artist} - {title}.{ext}",
            "--simple-tui" // Simpler output for parsing
        ]
        
        task?.standardOutput = outputPipe
        task?.standardError = outputPipe
        
        let handle = outputPipe?.fileHandleForReading
        
        handle?.readabilityHandler = { [weak self] pipe in
            if let data = try? pipe.read(upToCount: 1024),
               let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.appendLog(str)
                }
            }
        }
        
        task?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isDownloading = false
                self?.appendLog("\n✅ Process Finished.")
                
                // Trigger Library Scan
                if process.terminationStatus == 0 {
                    self?.appendLog("📦 Importing to Library...")
                    // We scan the directory to pick up new files
                    let fileManager = FileManager.default
                    if let files = try? fileManager.contentsOfDirectory(at: musicDir, includingPropertiesForKeys: nil) {
                        MusicLibraryManager.shared.importFiles(files)
                    }
                }
                
                self?.task = nil
                self?.outputPipe = nil
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.task?.run()
            } catch {
                DispatchQueue.main.async {
                    self.appendLog("❌ Execution Error: \(error.localizedDescription)")
                    self.isDownloading = false
                }
            }
        }
    }
    
    private func findSpotDL() -> String? {
        // First check standard paths
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try 'which spotdl'
        let whichProcess = Process()
        let pipe = Pipe()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["spotdl"]
        whichProcess.standardOutput = pipe
        try? whichProcess.run()
        whichProcess.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            return path
        }
        
        return nil
    }
    
    private func appendLog(_ text: String) {
        // Filter out some spotdl progress bars if they look messy
        // For now, raw log
        logs += text
        
        // Auto-scroll logic could go here if using ScrollViewReader
    }
}
#endif
