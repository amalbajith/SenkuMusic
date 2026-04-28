import Foundation
import Combine
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI
import Combine

class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var queue: [Song] = []
    @Published var currentIndex: Int = 0
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffled = false
    @Published var isNowPlayingPresented = false

    
    @Published var isAutoMixEnabled: Bool = false
    
    // MARK: - Settings
    @AppStorage("crossfadeDuration") private var crossfadeDuration: Double = 0.0
    @AppStorage("gaplessPlayback") private var gaplessPlayback: Bool = true
    @AppStorage("volumeNormalization") private var volumeNormalization: Bool = true

    // Sleep Timer
    private var sleepTimerRef: Timer?
    @Published var sleepTimerRemaining: TimeInterval = 0

    // Artwork cache — avoids decoding JPEG/PNG on every 100ms tick
    private var cachedNowPlayingArtwork: MPMediaItemArtwork?
    private var cachedArtworkSongId: UUID?
    
    // MARK: - Audio Engine Properties
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var streamingPlayer: AVPlayer?
    private var streamingObserver: Any?
    private var streamingStatusObserver: NSKeyValueObservation?
    private var streamingTimeObserver: Any?
    
    // Playback State
    private var currentFile: AVAudioFile?
    
    private var seekFrame: AVAudioFramePosition = 0
    private var sampleRate: Double = 44100
    private var playbackTimer: Timer?
    
    
    // Queue Management
    private var originalQueue: [Song] = []
    private var isSeeking = false
    
    
    private var playbackToken = UUID()
    
    enum RepeatMode { case off, one, all }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupEngine()
        setupRemoteCommandCenter()
        setupNotifications()
        observeAppLifecycle()
        
        // Connect EQ Manager
        EqualizerManager.shared.attach(to: self)
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // USE: .playback solo (no mix) to ensure interruptions (calls) work correctly
            try audioSession.setCategory(.playback, mode: .default, options: [])
            
            // FIX: Increase buffer duration to 100ms to prevent pops during screenshots/CPU spikes
            try audioSession.setPreferredIOBufferDuration(0.1)
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        
        let format = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        engine.prepare()
        try? engine.start()
        
        playerNode.volume = 1.0
    }
    
    /// Helper for external managers to inject nodes into the chain
    func attach(_ node: AVAudioNode) {
        engine.attach(node)
        
        // Re-route player -> node -> mixer
        let format = engine.outputNode.inputFormat(forBus: 0)
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.connect(playerNode, to: node, format: format)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    
    // MARK: - Playback Control
    func playSong(_ song: Song, in queue: [Song], at index: Int) {
        self.queue = queue
        self.originalQueue = queue
        self.currentIndex = index

        startPlayback(with: song)

        // Automatically open Now Playing when a song is tapped
        DispatchQueue.main.async {
            self.isNowPlayingPresented = true
        }
    }
    
    func play(song: Song, in queue: [Song]) {
        let index = queue.firstIndex(of: song) ?? 0
        playSong(song, in: queue, at: index)
    }
    
    func shuffleAndPlay(songs: [Song]) {
        var shuffledSongs = songs
        shuffledSongs.shuffle()
        if let first = shuffledSongs.first {
            playSong(first, in: shuffledSongs, at: 0)
            self.isShuffled = true
        }
    }
    
    // MARK: - AI Auto Mix
    func startAutoMix(songs: [Song]) {
        guard !songs.isEmpty else { return }
        // O(n) via Set instead of O(n²) removeAll inside loop
        var remaining = Set(songs.map(\.id))
        let byId = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        guard let firstId = remaining.randomElement() else { return }
        var mixQueue = [byId[firstId]!]
        remaining.remove(firstId)
        var current = byId[firstId]!

        while !remaining.isEmpty {
            let nextId = remaining.first(where: {
                let c = byId[$0]!
                return (c.genre != nil && c.genre == current.genre) || c.artist == current.artist
            }) ?? remaining.randomElement()
            guard let id = nextId else { break }
            mixQueue.append(byId[id]!)
            remaining.remove(id)
            current = byId[id]!
        }

        #if DEBUG
        print("✨ AI Auto Mix Generated with \(mixQueue.count) songs")
        #endif
        playSong(mixQueue[0], in: mixQueue, at: 0)
        isAutoMixEnabled = true
    }
    
    // MARK: - Mood-Based Smart Mix
    func startMoodMix(mood: Mood, from songs: [Song]) {
        guard !songs.isEmpty else { return }
        
        // Filter songs primarily by physical audio energy if available, fallback to keywords
        let keywords = mood.keywords
        var filteredSongs = songs.filter { song in
            if let energy = song.energy {
                switch mood {
                case .chill, .focus:
                    return energy < 0.4
                case .workout, .upbeat:
                    return energy >= 0.4
                }
            }
            
            let searchString = [song.genre, song.title, song.artist]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return keywords.contains(where: { searchString.contains($0) })
        }
        
        // Fallback: if we didn't find enough, grab a few random ones to pad the list
        if filteredSongs.count < 5 {
            let pool = Set(songs.map(\.id)).subtracting(filteredSongs.map(\.id))
            let randomAdditions = pool.shuffled().prefix(15 - filteredSongs.count).compactMap { id in songs.first(where: { $0.id == id }) }
            filteredSongs.append(contentsOf: randomAdditions)
        }
        
        // Shuffle the result for a dynamic mix
        filteredSongs.shuffle()
        
        // Start Playback
        if let first = filteredSongs.first {
            #if DEBUG
            print("✨ AI Mood Mix [\(mood.rawValue)] Generated with \(filteredSongs.count) songs")
            #endif
            playSong(first, in: filteredSongs, at: 0)
        }
    }
    
    // MARK: - More Like This
    /// Builds a queue of the 25 most similar songs using energy proximity,
    /// artist match, and genre match scoring.
    func playMoreLikeThis(song: Song, from library: [Song]) {
        let candidates = library.filter { $0.id != song.id }
        guard !candidates.isEmpty else { return }
        
        let scored: [(song: Song, score: Float)] = candidates.map { candidate in
            var score: Float = 0
            
            // Artist match: strongest signal
            if candidate.artist == song.artist { score += 40 }
            
            // Genre match: secondary signal
            if let g1 = candidate.genre, let g2 = song.genre, g1 == g2 { score += 30 }
            
            // Energy proximity: the closer the energy, the higher the score
            if let e1 = candidate.energy, let e2 = song.energy {
                let diff = abs(e1 - e2)
                score += max(0, 30 - diff * 100) // up to 30 points
            }
            
            return (candidate, score)
        }
        
        // Take top 25 by score, shuffle slightly for variety
        let top = scored.sorted { $0.score > $1.score }.prefix(25).map(\.song)
        var queue = Array(top)
        queue.shuffle()
        
        // Put seed song first
        queue.insert(song, at: 0)
        playSong(song, in: queue, at: 0)
        
        #if DEBUG
        print("✨ More Like This: \(queue.count) songs similar to \(song.title)")
        #endif
    }
    
    func playNext(song: Song) { playNextTrack(song) }

    private func playNextTrack(_ song: Song) {
        if queue.isEmpty { playSong(song, in: [song], at: 0); return }
        queue.removeAll { $0.id == song.id }
        let insertIndex = Swift.min(currentIndex + 1, queue.count)
        queue.insert(song, at: insertIndex)
        #if DEBUG
        print("⏭️ Scheduled next: \(song.title)")
        #endif
    }

    private func startPlayback(with song: Song) {
        self.currentSong = song
        MusicLibraryManager.shared.recordPlay(for: song)
        
        let token = UUID()
        self.playbackToken = token
        
        // Stop both engines first to ensure no overlap
        playerNode.stop()
        streamingPlayer?.pause()
        streamingPlayer = nil
        if let observer = streamingObserver {
            NotificationCenter.default.removeObserver(observer)
            streamingObserver = nil
        }

        if song.isRemote {
            // ── REMOTE STREAMING PATH ────────────────────────
            // Stream URL is fetched lazily here (not at tap time)
            // This ensures we always have a fresh, non-expired URL
            isBuffering = true
            duration = song.duration // Use metadata duration; will update from AVPlayer
            
            Task {
                do {
                    // Extract videoId from the song's source URL
                    let videoId = song.url.lastPathComponent
                    let streamURL = try await CloudDiscoveryService.shared.getStreamURL(for: videoId)
                    
                    await MainActor.run { [weak self] in
                        guard let self = self, self.playbackToken == token else { return }
                        self.startStreamingPlayer(streamURL: streamURL, song: song, token: token)
                    }
                } catch {
                    await MainActor.run { [weak self] in
                        guard let self = self, self.playbackToken == token else { return }
                        self.isBuffering = false
                        self.isPlaying = false
                        #if DEBUG
                        print("❌ Cloud stream error: \(error.localizedDescription)")
                        #endif
                    }
                }
            }
        } else {
            // ── LOCAL FILE PATH (AVAudioEngine) ──────────────
            applyReplayGain(for: song)
            do {
                currentFile = try AVAudioFile(forReading: song.url)
                guard let file = currentFile else { return }
                
                sampleRate = file.processingFormat.sampleRate
                duration = Double(file.length) / sampleRate
                
                if !engine.isRunning { try engine.start() }
                
                playerNode.scheduleFile(file, at: nil) { [weak self] in
                    guard let self = self, self.playbackToken == token else { return }
                    self.handlePlaybackFinished()
                }

                playerNode.play()
                isPlaying = true
                seekFrame = 0

                startTimers()
                updateNowPlayingInfo(rebuildArtwork: true)
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.playNext()
                }
            }
        }
    }
    
    /// Starts AVPlayer for a resolved stream URL
    private func startStreamingPlayer(streamURL: URL, song: Song, token: UUID) {
        // ── Stop AVAudioEngine so it doesn't hold the audio hardware ──
        if engine.isRunning { engine.stop() }

        // ── Re-activate the audio session for AVPlayer ────────────────
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Audio session re-activation failed: \(error.localizedDescription)")
        }

        let playerItem = AVPlayerItem(url: streamURL)

        // ── Create player first ───────────────────────────────────────
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        streamingPlayer = player

        // ── End-of-track notification ─────────────────────────────────
        streamingObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.playbackToken == token else { return }
            self.handlePlaybackFinished()
        }

        // ── KVO: status (readyToPlay / failed) ────────────────────────
        streamingStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.isBuffering = false
                    let avDuration = item.duration.seconds
                    if avDuration.isFinite && avDuration > 0 { self.duration = avDuration }
                case .failed:
                    let errMsg = item.error?.localizedDescription ?? "unknown"
                    print("❌ AVPlayerItem failed: \(errMsg)")
                    self.isBuffering = false
                    self.isPlaying  = false
                    Task { await CloudDiscoveryService.shared.invalidateStream(for: song.url.lastPathComponent) }
                default: break
                }
            }
        }

        // ── Periodic observer: buffer-stall / currentTime ─────────────
        streamingTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self, self.currentSong?.isRemote == true else { return }
            self.currentTime = time.seconds
            let stalled = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            if self.isBuffering != stalled { self.isBuffering = stalled }
        }

        player.play()
        isPlaying   = true
        isBuffering = true   // stays true until .readyToPlay KVO fires
        currentTime = 0
        updateNowPlayingInfo(rebuildArtwork: true)
        // NOTE: Do NOT call startTimers() here — the periodic observer above
        // handles currentTime updates for streaming. startTimers() uses AVAudioEngine frames.
    }

        private func handlePlaybackFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if let next = self.getNextIndex() {
                self.currentIndex = next
                self.startPlayback(with: self.queue[next])
            } else {
                self.isPlaying = false
                self.currentTime = 0
            }
        }
    }

    
    // MARK: - Controls
    func play() {
        guard currentSong != nil else { return }
        if currentSong?.isRemote == true {
            streamingPlayer?.play()
        } else {
            if !engine.isRunning { try? engine.start() }
            playerNode.play()
        }
        isPlaying = true
        startTimers()
    }
    
    func pause() {
        if currentSong?.isRemote == true {
            streamingPlayer?.pause()
        } else {
            playerNode.pause()
        }
        isPlaying = false
        playbackTimer?.invalidate()
    }
    
    func togglePlayPause() { isPlaying ? pause() : play() }
    
    func stop() {
        self.playbackToken = UUID()
        playerNode.stop()
        engine.stop()
        
        // Clean up streaming player fully
        streamingPlayer?.pause()
        streamingStatusObserver?.invalidate()
        streamingStatusObserver = nil
        if let t = streamingTimeObserver { streamingPlayer?.removeTimeObserver(t) }
        streamingTimeObserver = nil
        if let obs = streamingObserver { NotificationCenter.default.removeObserver(obs) }
        streamingObserver = nil
        streamingPlayer = nil
        
        isPlaying = false
        isBuffering = false
        playbackTimer?.invalidate()
        currentSong = nil
        currentTime = 0
        duration = 0
        currentFile = nil
        seekFrame = 0
        isNowPlayingPresented = false
    }
    
        func playNext() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        startPlayback(with: queue[currentIndex])
    }

    
    func playNext(_ song: Song) {
        playNextTrack(song)
    }
    
    func playLater(_ song: Song) {
        if queue.isEmpty {
            playSong(song, in: [song], at: 0)
        } else {
            queue.append(song)
        }
    }
    
    func playPrevious() {
        guard !queue.isEmpty else { return }
        
        if currentTime > 3 {
             seek(to: 0)
        } else {
             currentIndex = (currentIndex - 1 + queue.count) % queue.count
             startPlayback(with: queue[currentIndex])
        }
    }
    
    func seek(to time: TimeInterval) {
        let newToken = UUID()
        self.playbackToken = newToken
        
        if currentSong?.isRemote == true {
            let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
            streamingPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = time
        } else {
            guard let file = currentFile else { return }
            let position = AVAudioFramePosition(time * sampleRate)
            
            playerNode.stop()
            
            if position < file.length {
                let frameCount = AVAudioFrameCount(file.length - position)
                playerNode.scheduleSegment(
                    file,
                    startingFrame: position,
                    frameCount: frameCount,
                    at: nil
                ) { [weak self] in
                    guard let self = self, self.playbackToken == newToken else { return }
                    self.handlePlaybackFinished()
                }
            }

            playerNode.prepare(withFrameCount: 4096)
            if isPlaying { playerNode.play() }
            seekFrame = position
            currentTime = time
        }
        updateNowPlayingInfo()
    }
    
    // MARK: - Helpers
    private func getNextIndex() -> Int? {
        guard !queue.isEmpty else { return nil }
        
        switch repeatMode {
        case .one: return currentIndex // Repeat One repeats same song
        case .all, .off:
             let next = currentIndex + 1
             if next < queue.count { return next }
             return repeatMode == .all ? 0 : nil
        }
    }
    
    // MARK: - Timers
    private func startTimers() {
        playbackTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackLoop()
        }
        timer.tolerance = 0.05 // Allow coalescing for battery savings
        playbackTimer = timer
    }
    
        private func updatePlaybackLoop() {
        guard isPlaying else { return }
        
        if currentSong?.isRemote == true {
            if let time = streamingPlayer?.currentTime().seconds, !time.isNaN {
                currentTime = time
            }
        } else {
            if let nodeTime = playerNode.lastRenderTime,
               let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
                
                let timePlayedByNode = Double(playerTime.sampleTime) / playerTime.sampleRate
                let baseTime = Double(seekFrame) / sampleRate
                
                currentTime = baseTime + timePlayedByNode
            }
        }
    }

    
    // MARK: - EQ & Info
    // Removed applyEqualizer as it's now handled by EqualizerManager.shared
    
    private func updateNowPlayingInfo(rebuildArtwork: Bool = false) {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        // OPT-02: only decode artwork when song changes, not every 100ms tick
        if rebuildArtwork || cachedArtworkSongId != song.id {
            if let data = song.artworkData, let img = PlatformImage.fromData(data) {
                cachedNowPlayingArtwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            } else {
                cachedNowPlayingArtwork = nil
            }
            cachedArtworkSongId = song.id
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:                    song.title,
            MPMediaItemPropertyArtist:                   song.artist,
            MPMediaItemPropertyPlaybackDuration:         duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate:        isPlaying ? 1.0 : 0.0
        ]
        if let art = cachedNowPlayingArtwork { info[MPMediaItemPropertyArtwork] = art }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Notification Handlers (OPT-01)
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleEngineConfigChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
              
        var shouldPause = true
        if #available(iOS 14.5, *) {
            if let reasonValue = info[AVAudioSessionInterruptionReasonKey] as? UInt,
               let _ = AVAudioSession.InterruptionReason(rawValue: reasonValue) {
                
                // appWasSuspended (raw value 1) is deprecated in iOS 16+ 
                // We use the raw value to avoid compiler warnings while maintaining legacy support
                if #available(iOS 16.0, *) {
                    // Ignored on iOS 16+
                } else {
                    let suspendedRaw: UInt = 1
                    if reasonValue == suspendedRaw { shouldPause = false }
                }
            }
        }
              
        switch type {
        case .began:
            #if DEBUG
            print("🔊 Audio interrupted (began)")
            #endif
            if shouldPause {
                DispatchQueue.main.async {
                    self.playerNode.pause()
                    self.isPlaying = false
                    self.playbackTimer?.invalidate()
                }
            }
        case .ended:
            let optsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let opts = AVAudioSession.InterruptionOptions(rawValue: optsValue)
            
            #if DEBUG
            print("🔊 Audio interruption ended (options: \(opts))")
            #endif
            
            if opts.contains(.shouldResume) {
                DispatchQueue.main.async {
                    self.play() 
                }
            }
        @unknown default: break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .oldDeviceUnavailable:
            // Apple HIG: pause when headphones/BT disconnects
            DispatchQueue.main.async { self.pause() }

        case .newDeviceAvailable:
            // Auto-play on Bluetooth car stereo connect
            guard UserDefaults.standard.bool(forKey: "autoPlayOnBluetooth") else { return }
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            let savedName = UserDefaults.standard.string(forKey: "bluetoothCarName") ?? ""

            let matchingOutput = currentRoute.outputs.first {
                guard [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains($0.portType) else { return false }
                // If no device name saved → match any BT audio device
                // If name saved → case-insensitive contains match (handles capitalisation variants)
                if savedName.isEmpty { return true }
                return $0.portName.localizedCaseInsensitiveContains(savedName)
                    || savedName.localizedCaseInsensitiveContains($0.portName)
            }
            guard matchingOutput != nil else { return }

            // Small delay: gives the BT audio stack time to negotiate codec/sample rate
            // before we push audio through — avoids the silent-first-second glitch on
            // car stereos.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self, !self.isPlaying else { return }
                if self.currentSong != nil {
                    self.play()
                } else if !MusicLibraryManager.shared.songs.isEmpty {
                    // Nothing was queued — start from the beginning of the library
                    let songs = MusicLibraryManager.shared.songs
                    self.playSong(songs[0], in: songs, at: 0)
                }
            }

        default: break
        }
    }

    @objc private func handleEngineConfigChange() {
        // Fires on Bluetooth reconnect or sample-rate change — rebuild engine graph
        DispatchQueue.main.async {
            self.setupEngine()
            if self.isPlaying { try? self.engine.start() }
        }
    }

    // MARK: - Sleep Timer
    func setSleepTimer(minutes: Double) {
        sleepTimerRef?.invalidate()
        sleepTimerRemaining = minutes * 60
        sleepTimerRef = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            sleepTimerRemaining -= 1
            if sleepTimerRemaining <= 0 { pause(); cancelSleepTimer() }
        }
        RunLoop.main.add(sleepTimerRef!, forMode: .common)
    }

    func cancelSleepTimer() {
        sleepTimerRef?.invalidate(); sleepTimerRef = nil; sleepTimerRemaining = 0
    }
    
    // MARK: - Volume Normalisation (Replay Gain)
    /// Adjusts the main mixer output gain so every song plays at roughly the same
    /// perceived loudness. Uses the pre-computed RMS energy score as a proxy for
    /// loudness (range 0.0–1.0, target ≈ 0.25 which corresponds to ~−14 LUFS).
    private func applyReplayGain(for song: Song) {
        guard volumeNormalization else {
            engine.mainMixerNode.outputVolume = 1.0
            return
        }
        
        let targetRMS: Float = 0.25
        
        if let energy = song.energy, energy > 0 {
            // Gain = target / measured RMS, clamped to ±12 dB (0.25 – 4.0 linear)
            let gain = (targetRMS / energy).clamped(to: 0.25...4.0)
            engine.mainMixerNode.outputVolume = gain
        } else {
            // No energy data yet — use unity gain
            engine.mainMixerNode.outputVolume = 1.0
        }
    }
    

    // MARK: - App Lifecycle
    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.reduceTimerFrequency()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying {
                self.startTimers()
                if !self.engine.isRunning {
                    try? self.engine.start()
                    self.playerNode.play()
                }
            }
        }
    }
    
    private func reduceTimerFrequency() {
        playbackTimer?.invalidate()
        guard isPlaying else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
        timer.tolerance = 0.5
        playbackTimer = timer
    }
    
    private func setupRemoteCommandCenter() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { [weak self] _ in self?.playNext(); return .success }
        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { [weak self] _ in self?.playPrevious(); return .success }
        
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }
    
    // MARK: - Toggles
    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            let current = currentSong
            originalQueue = queue
            queue.shuffle()
            if let song = current, let idx = queue.firstIndex(of: song) {
                queue.swapAt(0, idx)
                currentIndex = 0
            }
        } else {
            queue = originalQueue
            if let song = currentSong, let idx = queue.firstIndex(of: song) {
                currentIndex = idx
            }
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    func toggleAutoMix() {
        isAutoMixEnabled.toggle()
    }
    
}
