//
//  DocumentPicker.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    let onSelect: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio, .mp3], asCopy: false)
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
#elseif os(macOS)
import AppKit

struct DocumentPicker: View {
    let onSelect: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Color.clear
            .onAppear {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true
                panel.canChooseDirectories = false
                panel.allowedContentTypes = [.audio, .mp3]
                
                panel.begin { response in
                    if response == .OK {
                        onSelect(panel.urls)
                    }
                    dismiss()
                }
            }
    }
}
#endif
