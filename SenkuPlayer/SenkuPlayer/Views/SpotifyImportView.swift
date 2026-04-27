//
//  SpotifyImportView.swift
//  SenkuPlayer
//

import SwiftUI

struct SpotifyImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var library = MusicLibraryManager.shared
    
    @State private var embedCode: String = ""
    @State private var isProcessing = false
    @State private var importResult: ImportResult?
    @State private var errorMessage: String?
    
    struct ImportResult {
        let playlistName: String
        let totalFound: Int
        let matchedCount: Int
        let matchedIDs: [UUID]
        let trackNamesFound: [String]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let result = importResult {
                    if result.totalFound == 0 {
                        noTracksFoundOnSpotifyView
                    } else if result.matchedCount == 0 {
                        noMatchesFoundInLibraryView(result: result)
                    } else {
                        successView(result: result)
                    }
                } else {
                    inputView
                }
            }
            .padding(ModernTheme.screenPadding)
            .navigationTitle("Spotify Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(ModernTheme.textSecondary)
                }
            }
            .alert("Import Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = errorMessage {
                    Text(msg)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste Spotify Embed Code")
                    .font(.headline)
                
                Text("Paste the <iframe ...> code or the playlist URL from Spotify.")
                    .font(.caption)
                    .foregroundColor(ModernTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            TextEditor(text: $embedCode)
                .frame(height: 150)
                .padding(8)
                .background(ModernTheme.backgroundSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ModernTheme.mediumGray, lineWidth: 1)
                )
            
            Button {
                processImport()
            } label: {
                if isProcessing {
                    ProgressView()
                        .tint(ModernTheme.pureBlack)
                } else {
                    Text("Analyze Playlist")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(embedCode.isEmpty ? ModernTheme.mediumGray : ModernTheme.accentYellow)
            .foregroundColor(ModernTheme.pureBlack)
            .cornerRadius(12)
            .disabled(embedCode.isEmpty || isProcessing)
            
            Spacer()
        }
    }
    
    private var noTracksFoundOnSpotifyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(ModernTheme.textTertiary)
            
            Text("No Tracks Found")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("We couldn't find any track names in the link you provided. Please make sure it's a valid Spotify playlist link.")
                .font(.subheadline)
                .foregroundColor(ModernTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                importResult = nil
                embedCode = ""
            }
            .padding()
            .background(ModernTheme.mediumGray)
            .cornerRadius(12)
        }
    }
    
    private func noMatchesFoundInLibraryView(result: ImportResult) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ModernTheme.textTertiary)
            
            Text("No Matches Found")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("We found \(result.totalFound) tracks on \"\(result.playlistName)\", but none of them matched the music in your local library.")
                .font(.subheadline)
                .foregroundColor(ModernTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracks found on Spotify:")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    ForEach(result.trackNamesFound.prefix(10), id: \.self) { name in
                        Text("• \(name)")
                            .font(.caption2)
                            .foregroundColor(ModernTheme.textSecondary)
                    }
                    if result.trackNamesFound.count > 10 {
                        Text("...and \(result.trackNamesFound.count - 10) more")
                            .font(.caption2)
                            .italic()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ModernTheme.backgroundSecondary)
                .cornerRadius(12)
            }
            .frame(maxHeight: 200)
            
            Button("Try Another Link") {
                importResult = nil
                embedCode = ""
            }
            .padding()
            .background(ModernTheme.mediumGray)
            .cornerRadius(12)
        }
    }
    
    private func successView(result: ImportResult) -> some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ModernTheme.accentYellow)
                
                Text(result.playlistName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("We matched \(result.matchedCount) of \(result.totalFound) tracks.")
                    .font(.subheadline)
                    .foregroundColor(ModernTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Import Summary")
                    .font(.headline)
                
                HStack {
                    Text("Total Spotify Tracks")
                    Spacer()
                    Text("\(result.totalFound)")
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Matched in Library")
                    Spacer()
                    Text("\(result.matchedCount)")
                        .fontWeight(.bold)
                        .foregroundColor(ModernTheme.accentYellow)
                }
            }
            .padding()
            .background(ModernTheme.backgroundSecondary)
            .cornerRadius(12)
            
            Button {
                createPlaylist(result: result)
            } label: {
                Text("Create Playlist")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ModernTheme.accentYellow)
            .foregroundColor(ModernTheme.pureBlack)
            .cornerRadius(12)
            
            Button {
                importResult = nil
            } label: {
                Text("Change Link")
                    .foregroundColor(ModernTheme.textSecondary)
            }
        }
    }
    
    private func processImport() {
        guard let playlistID = SpotifyImportService.shared.extractPlaylistID(from: embedCode) else {
            errorMessage = "Could not find a Spotify playlist ID. Please paste a valid URL or iframe code."
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let info = try await SpotifyImportService.shared.fetchPlaylistInfo(playlistID: playlistID)
                let matchedIDs = SpotifyImportService.shared.matchTracksWithLibrary(spotifyTracks: info.tracks, librarySongs: library.songs)
                
                await MainActor.run {
                    self.importResult = ImportResult(
                        playlistName: info.name,
                        totalFound: info.tracks.count,
                        matchedCount: matchedIDs.count,
                        matchedIDs: matchedIDs,
                        trackNamesFound: info.tracks.map { "\($0.title) - \($0.artist)" }
                    )
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Failed to fetch playlist data: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func createPlaylist(result: ImportResult) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Extract the playlist ID from the embed code again or store it in result
        let spotifyID = SpotifyImportService.shared.extractPlaylistID(from: embedCode)
        
        library.createPlaylist(name: result.playlistName, songIDs: result.matchedIDs, spotifyPlaylistID: spotifyID)
        dismiss()
    }
}
