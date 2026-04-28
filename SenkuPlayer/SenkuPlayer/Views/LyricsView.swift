//
//  LyricsView.swift
//  SenkuPlayer
//
//  Premium Apple Music-style synced lyrics.
//
//  PERF notes:
//  - @ObservedObject player removed: body now re-renders only when activeIndex changes
//    (lyric line transition, ~once per second) not every 100ms timer tick.
//  - .blur removed from non-active lines: each blur forces an offscreen GPU pass.
//    With 8-10 visible lines that was 8-10 extra compositing layers per frame.
//

import SwiftUI

// MARK: - Lyric Line View

private struct LyricLineView: View {
    let text: String
    let isActive: Bool
    let isPast: Bool

    // Adaptive font size — longer lines get smaller text so they wrap gracefully
    private var fontSize: CGFloat {
        let len = text.count
        if len < 35  { return 22 }
        if len < 60  { return 18 }
        if len < 90  { return 15 }
        return 13
    }

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundColor(
                isActive ? .white :
                isPast   ? .white.opacity(0.28) :
                           .white.opacity(0.42)
            )
            .scaleEffect(isActive ? 1.06 : 1.0, anchor: .leading)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isActive)
            .animation(.easeInOut(duration: 0.2), value: isPast)
    }
}

// MARK: - Lyrics Content

// Separated struct: ForEach only re-evaluates when activeIndex or parsedLines change,
// not on every parent body re-render.
private struct LyricsContent: View {
    let parsedLines: [LyricLine]
    let activeIndex: Int?
    let geometry: GeometryProxy
    let syncOffset: TimeInterval
    let onTap: (LyricLine, TimeInterval) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: geometry.size.height * 0.18)

            ForEach(Array(parsedLines.enumerated()), id: \.element.id) { index, line in
                let isActive = index == activeIndex
                let isPast   = activeIndex.map { index < $0 } ?? false

                LyricLineView(
                    text: line.text.isEmpty ? "♪" : line.text,
                    isActive: isActive,
                    isPast: isPast
                )
                .id(line.id)
                .onTapGesture { onTap(line, syncOffset) }
            }

            Color.clear.frame(height: geometry.size.height * 0.45)
        }
    }
}

// MARK: - Main View

struct LyricsView: View {
    @Environment(\.dismiss) private var dismiss

    // PERF: No @ObservedObject player — body re-renders only when these @State values change.
    // currentTime arrives via onReceive but only triggers a body re-render when activeIndex
    // actually changes (i.e. when a new lyric line starts), not every 100ms.
    @State private var songTitle: String   = AudioPlayerManager.shared.currentSong?.title ?? ""
    @State private var plainLyrics: String? = AudioPlayerManager.shared.currentSong?.plainLyrics

    @State private var parsedLines: [LyricLine] = []
    @State private var activeIndex: Int?    = nil
    @State private var isFetchingLyrics     = false
    @State private var fetchFailed          = false
    @State private var showingEditor        = false
    @State private var syncOffset: TimeInterval = 0.0
    @State private var backdropColor: Color = ModernTheme.backgroundPrimary

    var body: some View {
        ZStack(alignment: .top) {

            // ── Background ──────────────────────────────────────
            ZStack {
                backdropColor.ignoresSafeArea()
                LinearGradient(
                    colors: [backdropColor.opacity(0.6), Color.black.opacity(0.92)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // ── Lyrics Body ─────────────────────────────────────
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
                                    AudioPlayerManager.shared.seek(to: max(0, line.time - offset))
                                }
                            )
                        }
                        .clipped()
                        .onChange(of: activeIndex) { _, newIndex in
                            guard let idx = newIndex, idx < parsedLines.count else { return }
                            withAnimation(.interpolatingSpring(stiffness: 40, damping: 10)) {
                                proxy.scrollTo(parsedLines[idx].id, anchor: .center)
                            }
                        }
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.82),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                } else if let plain = plainLyrics {
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

            // ── Header ──────────────────────────────────────────
            headerBar
        }
        .onAppear {
            parseLyrics()
            updateActiveIndex(for: AudioPlayerManager.shared.currentTime)
            extractBackdropColor()
            fetchLyricsIfNeeded()
        }
        // Song change → dismiss (rare, cheap)
        .onReceive(AudioPlayerManager.shared.$currentSong) { song in
            let newId = song?.id
            if newId != AudioPlayerManager.shared.currentSong?.id {
                dismiss()
            } else {
                // Same song but lyrics may have been fetched
                songTitle   = song?.title ?? ""
                plainLyrics = song?.plainLyrics
                parseLyrics()
            }
        }
        // Playback stop → dismiss
        .onReceive(AudioPlayerManager.shared.$isPlaying) { isPlaying in
            if !isPlaying && AudioPlayerManager.shared.currentTime == 0 { dismiss() }
        }
        // HIGH FREQUENCY: fires every 100ms but only writes @State when index changes
        .onReceive(AudioPlayerManager.shared.$currentTime) { time in
            updateActiveIndex(for: time)
        }
        .sheet(isPresented: $showingEditor) {
            if let song = AudioPlayerManager.shared.currentSong {
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
                .buttonStyle(PressEffect(scale: 0.90))

                Spacer()

                VStack(spacing: 2) {
                    Text("LYRICS")
                        .font(.system(size: 11, weight: .black))
                        .kerning(3)
                        .foregroundColor(.white.opacity(0.5))
                    Text(songTitle.normalizedForDisplay)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [backdropColor.opacity(0.9), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }

    // MARK: - Logic

    private func parseLyrics() {
        if let synced = AudioPlayerManager.shared.currentSong?.syncedLyrics, !synced.isEmpty {
            parsedLines = LRCParser.parse(lrc: synced)
        } else {
            parsedLines = []
        }
        updateActiveIndex(for: AudioPlayerManager.shared.currentTime)
    }

    /// O(log n) binary search — fast enough to call on every timer tick.
    /// Only writes @State when the index actually changes → no spurious re-renders.
    private func updateActiveIndex(for currentTime: TimeInterval) {
        guard !parsedLines.isEmpty else { activeIndex = nil; return }

        let time = currentTime + syncOffset
        var lo = 0, hi = parsedLines.count - 1, result = 0

        while lo <= hi {
            let mid = (lo + hi) / 2
            if parsedLines[mid].time <= time {
                result = mid; lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        if activeIndex != result { activeIndex = result }
    }

    private func fetchLyricsIfNeeded() {
        guard let song = AudioPlayerManager.shared.currentSong,
              song.syncedLyrics == nil, song.plainLyrics == nil else { return }
        isFetchingLyrics = true
        fetchFailed = false
        Task {
            await MusicLibraryManager.shared.fetchLyricsIfNeeded(for: song)
            await MainActor.run {
                isFetchingLyrics = false
                plainLyrics = AudioPlayerManager.shared.currentSong?.plainLyrics
                parseLyrics()
                if AudioPlayerManager.shared.currentSong?.plainLyrics == nil &&
                   AudioPlayerManager.shared.currentSong?.syncedLyrics == nil {
                    fetchFailed = true
                }
            }
        }
    }

    private func extractBackdropColor() {
        guard let song = AudioPlayerManager.shared.currentSong else {
            backdropColor = ModernTheme.backgroundPrimary
            return
        }
        Task.detached(priority: .userInitiated) {
            let color = await DominantColorExtractor.shared.extractDominantColor(for: song)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) { self.backdropColor = color }
            }
        }
    }
}
