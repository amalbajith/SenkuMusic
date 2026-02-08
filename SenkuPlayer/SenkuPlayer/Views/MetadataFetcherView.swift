//
//  MetadataFetcherView.swift
//  SenkuPlayer
//
//  UI for automatically fetching album artwork and metadata
//

import Combine
import SwiftUI

struct MetadataFetcherView: View {
    @StateObject private var fetcher = MetadataFetcher.shared
    @StateObject private var library = MusicLibraryManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedScope: FetchScope = .missingArtwork
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var showingResults = false
    @State private var resultsMessage = ""
    
    enum FetchScope: Equatable {
        case missingArtwork
        case allSongs
        case selectedSongs([Song])
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Scope Selection
                        scopeSection
                        
                        // Stats
                        statsSection
                        
                        // Action Button
                        if !isProcessing {
                            actionButton
                        } else {
                            progressSection
                        }
                        
                        // Info
                        infoSection
                    }
                    .padding(.horizontal, ModernTheme.screenPadding)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Fetch Metadata")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Results", isPresented: $showingResults) {
                Button("OK") { }
            } message: {
                Text(resultsMessage)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(ModernTheme.accentYellow)
            
            Text("Auto-Fetch Metadata")
                .font(ModernTheme.title())
                .foregroundColor(.white)
            
            Text("Automatically download album artwork and update song information")
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.lightGray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What to fetch")
                .font(ModernTheme.headline())
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ScopeOption(
                    title: "Songs Missing Artwork",
                    subtitle: "\(songsWithoutArtwork.count) songs",
                    icon: "photo.badge.plus",
                    isSelected: selectedScope == .missingArtwork
                ) {
                    selectedScope = .missingArtwork
                }
                
                ScopeOption(
                    title: "All Songs",
                    subtitle: "\(library.songs.count) songs",
                    icon: "music.note.list",
                    isSelected: selectedScope == .allSongs
                ) {
                    selectedScope = .allSongs
                }
            }
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatBox(
                title: "Total Songs",
                value: "\(library.songs.count)",
                icon: "music.note"
            )
            
            StatBox(
                title: "Missing Art",
                value: "\(songsWithoutArtwork.count)",
                icon: "photo.badge.plus"
            )
        }
    }
    
    private var actionButton: some View {
        Button {
            startFetching()
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                Text("Start Fetching")
                    .font(ModernTheme.body())
                    .fontWeight(.bold)
            }
            .foregroundColor(ModernTheme.pureBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ModernTheme.accentYellow)
            .cornerRadius(16)
        }
        .disabled(songsToFetch.isEmpty)
        .opacity(songsToFetch.isEmpty ? 0.5 : 1.0)
    }
    
    private var progressSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Fetching metadata...")
                    .font(ModernTheme.headline())
                    .foregroundColor(.white)
                
                if !fetcher.currentSong.isEmpty {
                    Text(fetcher.currentSong)
                        .font(ModernTheme.caption())
                        .foregroundColor(ModernTheme.lightGray)
                        .lineLimit(1)
                }
            }
            
            VStack(spacing: 8) {
                ProgressView(value: fetcher.progress)
                    .tint(ModernTheme.accentYellow)
                
                Text("\(Int(fetcher.progress * 100))% • \(processedCount) of \(totalCount)")
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.lightGray)
            }
        }
        .padding(ModernTheme.screenPadding)
        .cardBackground()
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How it works")
                    .font(ModernTheme.body())
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(text: "Searches MusicBrainz database for song info")
                InfoRow(text: "Downloads high-quality album artwork")
                InfoRow(text: "Updates metadata automatically")
                InfoRow(text: "Respects API rate limits (1 song/second)")
            }
        }
        .padding(20)
        .cardBackground()
    }
    
    // MARK: - Computed Properties
    
    private var songsWithoutArtwork: [Song] {
        library.songs.filter { !$0.hasArtwork }
    }
    
    private var songsToFetch: [Song] {
        switch selectedScope {
        case .missingArtwork:
            return songsWithoutArtwork
        case .allSongs:
            return library.songs
        case .selectedSongs(let songs):
            return songs
        }
    }
    
    // MARK: - Actions
    
    private func startFetching() {
        isProcessing = true
        totalCount = songsToFetch.count
        processedCount = 0
        
        Task {
            let results = await fetcher.fetchMetadataForSongs(songsToFetch)
            
            await MainActor.run {
                var successCount = 0
                
                for result in results {
                    // Save artwork to disk
                    if let artwork = result.artwork {
                        ArtworkManager.shared.saveArtwork(artwork, for: result.songId)
                        successCount += 1
                    }
                    
                    // Update song metadata in library
                    if let index = library.songs.firstIndex(where: { $0.id == result.songId }) {
                        var updatedSong = library.songs[index]
                        
                        // Update metadata if available
                        if let metadata = result.metadata {
                            updatedSong.title = metadata.title
                            updatedSong.artist = metadata.artist
                            updatedSong.album = metadata.album
                            updatedSong.year = metadata.year
                            updatedSong.genre = metadata.genre
                        }
                        
                        // Mark as having artwork
                        if result.artwork != nil {
                            updatedSong.hasArtwork = true
                        }
                        
                        library.songs[index] = updatedSong
                    }
                    
                    processedCount += 1
                }
                
                // Save changes to disk and reorganize
                library.saveSongs()
                library.organizeLibrary()
                
                // Force UI refresh
                library.objectWillChange.send()
                
                isProcessing = false
                resultsMessage = "Successfully fetched metadata for \(successCount) of \(totalCount) songs."
                showingResults = true
            }
        }
    }
}

// MARK: - Supporting Views

struct ScopeOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? ModernTheme.accentYellow : .white)
                    .frame(width: 44, height: 44)
                    .background(ModernTheme.mediumGray)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ModernTheme.body())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(ModernTheme.caption())
                        .foregroundColor(ModernTheme.lightGray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ModernTheme.accentYellow)
                }
            }
            .padding(16)
            .cardBackground()
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ModernTheme.accentYellow)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.lightGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardBackground()
    }
}

struct InfoRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text(text)
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.lightGray)
        }
    }
}

#Preview {
    MetadataFetcherView()
}
