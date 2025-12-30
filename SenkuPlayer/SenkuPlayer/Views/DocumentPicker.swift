//
//  DocumentPicker.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    let onSelect: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Allow selecting MP3 files directly
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio, .mp3], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true // Enable multiple file selection
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: ([URL]) -> Void
        
        init(onSelect: @escaping ([URL]) -> Void) {
            self.onSelect = onSelect
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Start accessing security-scoped resources
            var accessedURLs: [URL] = []
            
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    accessedURLs.append(url)
                }
            }
            
            // Pass all selected URLs
            if !accessedURLs.isEmpty {
                onSelect(accessedURLs)
            }
            
            // Stop accessing after a delay to allow processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            }
        }
    }
}

