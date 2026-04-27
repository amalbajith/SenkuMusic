//
//  LyricsView.swift
//  SenkuPlayer
//
//  Premium Apple Music-style synced lyrics with optimized time tracking.
//

import SwiftUI

// MARK: - Active Line Index computation is separated so ForEach doesn't recompute it per-cell
private struct LyricsContent: View {
    let parsedLines: [LyricLine]
    let activeIndex: Int?
    let geometry: GeometryProxy
    let syncOffset: TimeInterval
    let onTap: (LyricLine, TimeInterval) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            // Top spacer so first line starts in the middle of the screen
            Color.clear.frame(height: geometry.size.height * 0.38)

            ForEach(Array(parsedLines.enumerated()), id: \.element.id) { index, line in
                let isActive = index == activeIndex
                let isPast = activeIndex.map { index < $0 } ?? false

                LyricLineView(
                    text: line.text.isEmpty ? "♪" : line.text,
                    isActive: isActive,
                    isPast: isPast
                )
                .id(line.id)
                .onTapGesture { onTap(line, syncOffset) }
            }

            // Bottom breathing room
            Color.clear.frame(height: geometry.size.height * 0.45)
        }
    }
}

private struct LyricLineView: View {
    let text: String
    let isActive: Bool
    let isPast: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(
                isActive ? .white :
                isPast  ? .white.opacity(0.3) :
                           .white.opacity(0.5)
            )
            .blur(radius: isActive ? 0 : 0.8)
            .scaleEffect(isActive ? 1.18 : 1.0, anchor: .leading)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isActive)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPast)
    }
}

// MARK: - Main View

struct LyricsView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var parsedLines: [LyricLine] = []
    @State private var activeIndex: Int? = nil
    @State private var isFetchingLyrics = false
    @State private var fetchFailed = false
    @State private var showingEditor = false
    @State private var syncOffset: TimeInterval = 0.0

    // Artwork dominant color for the background tint
    @State private var backdropColor: Color = ModernTheme.backgroundPrimary

    var body: some View {
        ZStack(alignment: .top) {
            // ── Background ────────────────────────────────────
            ZStack {
                backdropColor
                    .ignoresSafeArea()
                LinearGradient(
                    colors: [backdropColor.opacity(0.6), Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // ── Lyrics Body ───────────────────────────────────
            GeometryReader { geometry in
                if !parsedLines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LyricsContent(
                                parsedLines: parsedLines,
                                activeIndex: activeIndex,
                                geometry: geometry,
                                syncOffset: syncOffset,
                                onTap: { line, offset in
                                    player.seek(to: max(0, line.time - offset))
                                }
                            )
                        }
                        // Sync scroll to active line with a slight debounce
                        .onChange(of: activeIndex) { _, newIndex in
                            guard let idx = newIndex, idx < parsedLines.count else { return }
                            withAnimation(.interpolatingSpring(stiffness: 40, damping: 10)) {
                                proxy.scrollTo(parsedLines[idx].id, anchor: .center)
                            }
                        }
                    }
                    .mask(
                        // Fade out top & bottom edges
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.82),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                } else if let plain = player.currentSong?.plainLyrics {
                    // Plain text fallback
                    ScrollView(showsIndicators: false) {
                        Text(plain)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(28)
                            .padding(.top, 100)
                            .padding(.bottom, 120)
                    }
                } else {
                    // Loading / not found state
                    VStack(spacing: 20) {
                        Spacer()
                        if isFetchingLyrics {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(ModernTheme.accentYellow)
                                    .scaleEffect(1.4)
                                Text("Looking up lyrics…")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: fetchFailed ? "text.badge.xmark" : "music.quarternote.3")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.3))
                                Text(fetchFailed ? "No lyrics found" : "No lyrics available")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        Spacer()
                    }
                }
            }


            // ── Header Overlay ────────────────────────────────
            headerBar
        }
        .onAppear {
            parseLyrics()
            updateActiveIndex()
            extractBackdropColor()
            fetchLyricsIfNeeded()
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            dismiss()
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if !isPlaying && player.currentTime == 0 {
                dismiss() // Auto-dismiss when queue finishes
            }
        }
        .onChange(of: player.currentSong?.syncedLyrics) { _, _ in
            parseLyrics()
        }
        // High-frequency time observation
        .onChange(of: player.currentTime) { _, _ in
            updateActiveIndex()
        }
        .sheet(isPresented: $showingEditor) {
            if let song = player.currentSong {
                LyricEditorView(song: song)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("LYRICS")
                        .font(.system(size: 11, weight: .black))
                        .kerning(3)
                        .foregroundColor(.white.opacity(0.5))
                    Text((player.currentSong?.title ?? "").normalizedForDisplay)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                // Mirrored spacer to keep title centered
                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [backdropColor.opacity(0.9), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            
        }
    }

    // MARK: - Logic

    private func parseLyrics() {
        if let synced = player.currentSong?.syncedLyrics, !synced.isEmpty {
            parsedLines = LRCParser.parse(lrc: synced)
        } else {
            parsedLines = []
        }
        updateActiveIndex()
    }

    /// Binary search for the active lyric line – O(log n), safe to call every timer tick
    private func updateActiveIndex() {
        guard !parsedLines.isEmpty else {
            activeIndex = nil
            return
        }

        // Apply manual sync offset
        let time = player.currentTime + syncOffset
        var lo = 0
        var hi = parsedLines.count - 1
        var result = 0

        while lo <= hi {
            let mid = (lo + hi) / 2
            if parsedLines[mid].time <= time {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        if activeIndex != result {
            activeIndex = result
        }
    }

    private func fetchLyricsIfNeeded() {
        guard let song = player.currentSong,
              song.syncedLyrics == nil, song.plainLyrics == nil else { return }
        isFetchingLyrics = true
        fetchFailed = false
        Task {
            await MusicLibraryManager.shared.fetchLyricsIfNeeded(for: song)
            await MainActor.run {
                isFetchingLyrics = false
                parseLyrics()
                // If still no lyrics after fetch, mark as failed
                if player.currentSong?.plainLyrics == nil && player.currentSong?.syncedLyrics == nil {
                    fetchFailed = true
                }
            }
        }
    }

    private func extractBackdropColor() {
        guard let song = player.currentSong else {
            backdropColor = ModernTheme.backgroundPrimary
            return
        }
        Task.detached(priority: .userInitiated) {
            let color = await DominantColorExtractor.shared.extractDominantColor(for: song)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.backdropColor = color
                }
            }
        }
    }
}

