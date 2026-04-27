//
//  DocumentPicker.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    let onSelect: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio, .mp3, .zip], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: ([URL]) -> Void
        init(onSelect: @escaping ([URL]) -> Void) { self.onSelect = onSelect }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let accessedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
            if !accessedURLs.isEmpty {
                onSelect(accessedURLs)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            }
        }
    }
}
