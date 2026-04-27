//
//  LyricEditorView.swift
//  SenkuPlayer
//
//  Manual lyric editor — supports plain text and .lrc format.
//

import SwiftUI

struct LyricEditorView: View {
    let song: Song
    @Environment(\.dismiss) var dismiss
    @State private var lrcText: String = ""
    @State private var isSynced: Bool = true
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Format Picker
                    Picker("Format", selection: $isSynced) {
                        Text("Synced (.lrc)").tag(true)
                        Text("Plain text").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Hint
                    Text(isSynced
                         ? "Synced format: [01:23.45] Lyric line here"
                         : "One lyric line per line, no timestamps needed.")
                        .font(ModernTheme.caption())
                        .foregroundColor(ModernTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    // Editor
                    TextEditor(text: $lrcText)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(ModernTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(ModernTheme.backgroundSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .frame(maxHeight: .infinity)

                    Spacer().frame(height: 16)
                }
            }
            .navigationTitle("Edit Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(ModernTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveLyrics) {
                        if isSaving {
                            ProgressView().tint(ModernTheme.accentYellow)
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(ModernTheme.accentYellow)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                isSynced = song.syncedLyrics != nil
                lrcText = song.syncedLyrics ?? song.plainLyrics ?? ""
            }
            .preferredColorScheme(.dark)
        }
    }

    private func saveLyrics() {
        isSaving = true
        let library = MusicLibraryManager.shared
        if let index = library.songs.firstIndex(where: { $0.id == song.id }) {
            if isSynced {
                library.songs[index].syncedLyrics = lrcText.isEmpty ? nil : lrcText
                library.songs[index].plainLyrics = nil
            } else {
                library.songs[index].plainLyrics = lrcText.isEmpty ? nil : lrcText
                library.songs[index].syncedLyrics = nil
            }
            library.saveSongs()

            // Update currently playing song too
            if AudioPlayerManager.shared.currentSong?.id == song.id {
                AudioPlayerManager.shared.currentSong?.syncedLyrics = isSynced ? lrcText : nil
                AudioPlayerManager.shared.currentSong?.plainLyrics = isSynced ? nil : lrcText
            }
        }
        isSaving = false
        dismiss()
    }
}
