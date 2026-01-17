import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI

class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var queue: [Song] = []
    @Published var currentIndex: Int = 0
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffled = false
    @Published var isNowPlayingPresented = false

    
    @Published var activeEqualizerProfile: EqualizerProfile = EqualizerProfile.defaultProfile()
    @Published var isAutoMixEnabled: Bool = false
    
    // MARK: - Settings
    @AppStorage("crossfadeDuration") private var crossfadeDuration: Double = 0.0
    @AppStorage("gaplessPlayback") private var gaplessPlayback: Bool = true
    
    // MARK: - Audio Engine Properties
    private let engine = AVAudioEngine()
    private let playerA = AVAudioPlayerNode()
    private let playerB = AVAudioPlayerNode()
    private let inputsMixer = AVAudioMixerNode() // Mixes A and B before EQ
    private let equalizerNode = AVAudioUnitEQ(numberOfBands: 10)
    
    // Playback State
    private var activePlayer: AVAudioPlayerNode { activePlayerIndex == 0 ? playerA : playerB }
    private var inactivePlayer: AVAudioPlayerNode { activePlayerIndex == 0 ? playerB : playerA }
    private var activePlayerIndex = 0 // 0 for A, 1 for B
    
    private var currentFile: AVAudioFile?
    private var nextFile: AVAudioFile?
    
    private var seekFrame: AVAudioFramePosition = 0
    private var sampleRate: Double = 44100
    private var playbackTimer: Timer?
    private var crossfadeTimer: Timer?
    
    // Queue Management
    private var originalQueue: [Song] = []
    private var isSeeking = false
    private var isCrossfading = false
    private var nextSongScheduled = false
    private var playbackToken = UUID()
    
    enum RepeatMode { case off, one, all }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupEngine()
        setupRemoteCommandCenter()
        setupNotifications()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
        #endif
    }
    
    private func setupEngine() {
        // Attach
        engine.attach(playerA)
        engine.attach(playerB)
        engine.attach(inputsMixer)
        engine.attach(equalizerNode)
        
        // Connect: [A, B] -> Mixer -> EQ -> Main
        let format = engine.outputNode.inputFormat(forBus: 0)
        
        engine.connect(playerA, to: inputsMixer, format: format)
        engine.connect(playerB, to: inputsMixer, format: format)
        engine.connect(inputsMixer, to: equalizerNode, format: format)
        engine.connect(equalizerNode, to: engine.mainMixerNode, format: format)
        
        engine.prepare()
        
        try? engine.start()
        
        // Initial State
        playerA.volume = 1.0
        playerB.volume = 0.0 // Silent initially
        
        applyEqualizer(activeEqualizerProfile)
    }
    
    // MARK: - Playback Control
    func playSong(_ song: Song, in queue: [Song], at index: Int) {
        self.queue = queue
        self.originalQueue = queue
        self.currentIndex = index
        

        
        startPlayback(with: song)
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
        
        let allSongs = songs
        var pool = allSongs
        var mixQueue: [Song] = []
        
        // 1. Pick a random start
        guard let first = pool.randomElement() else { return }
        mixQueue.append(first)
        pool.removeAll { $0.id == first.id }
        
        var current = first
        
        // 2. Build the chain
        while !pool.isEmpty {
            // Find candidates that match Genre or Artist
            let candidates = pool.filter { candidate in
                let sameGenre = (candidate.genre != nil && candidate.genre == current.genre)
                let sameArtist = candidate.artist == current.artist
                return sameGenre || sameArtist
            }
            
            if let nextMatch = candidates.randomElement() {
                // Found a cohesive track
                mixQueue.append(nextMatch)
                pool.removeAll { $0.id == nextMatch.id }
                current = nextMatch
            } else {
                // No match found, pick random to shift vibe
                if let randomNext = pool.randomElement() {
                    mixQueue.append(randomNext)
                    pool.removeAll { $0.id == randomNext.id }
                    current = randomNext
                }
            }
        }
        
        // 3. Start Playback
        print("✨ AI Auto Mix Generated with \(mixQueue.count) songs")
        playSong(mixQueue[0], in: mixQueue, at: 0)
        self.isAutoMixEnabled = true
    }
    
    func playNext(song: Song) {
        if queue.isEmpty {
            play(song: song, in: [song])
            return
        }
        
        // Remove if already in queue to avoid duplicates
        queue.removeAll { $0.id == song.id }
        originalQueue.removeAll { $0.id == song.id }
        
        let insertIndex = Swift.min(currentIndex + 1, queue.count)
        queue.insert(song, at: insertIndex)
        originalQueue.append(song) // Keep original queue updated
        
        print("⏭️ Scheduled next: \(song.title)")
    }
    
    private func startPlayback(with song: Song) {
        self.currentSong = song
        
        // Record Playback History
        MusicLibraryManager.shared.recordPlay(for: song)
        
        // Reset State
        stopCrossfade()
        playerA.stop()
        playerB.stop()
        activePlayerIndex = 0
        playerA.volume = 1.0
        playerB.volume = 0.0
        
        do {
            currentFile = try AVAudioFile(forReading: song.url)
            guard let file = currentFile else { return }
            
            sampleRate = file.processingFormat.sampleRate
            duration = Double(file.length) / sampleRate
            
            // Ensure engine is running
            if !engine.isRunning {
                try engine.start()
            }
            
            // Generate Playback Token
            let token = UUID()
            self.playbackToken = token
            
            // Reset node
            playerA.reset()
            playerA.scheduleFile(file, at: nil) { [weak self] in
                guard let self = self, self.playbackToken == token else { return }
                self.handlePlaybackFinished()
            }
            
            playerA.play()
            isPlaying = true
            seekFrame = 0
            
            startTimers()
            updateNowPlayingInfo()
            
            // Preload next if gapless
            scheduleNextSong()
            
        } catch {
            print("❌ Error loading song: \(error)")
            // Try restart engine if crashed
            if !engine.isRunning {
                try? engine.start()
            }
        }
    }
    
    // MARK: - Crossfade & Scheduling
    private func scheduleNextSong() {
        guard !nextSongScheduled else { return }
        guard let nextIndex = getNextIndex(), nextIndex < queue.count else { return }
        
        let nextSong = queue[nextIndex]
        
        do {
            nextFile = try AVAudioFile(forReading: nextSong.url)
            guard nextFile != nil else { return }
            
            // Schedule on inactive player pre-load...
            
            nextSongScheduled = true
            print("✅ Next song prepped: \(nextSong.title)")
            
        } catch {
            print("❌ Error prepping next song: \(error)")
        }
    }
    
    private func checkCrossfadeTrigger() {
        guard isPlaying, !isCrossfading,
              let nextIndex = getNextIndex() else { return }
        
        let remaining = duration - currentTime
        let effectiveCrossfade = gaplessPlayback ? max(crossfadeDuration, 0.5) : crossfadeDuration
        
        // If we are within crossfade window
        if remaining <= effectiveCrossfade && effectiveCrossfade > 0 {
            performCrossfade(to: queue[nextIndex])
        }
    }
    
    private func performCrossfade(to nextSong: Song) {
        guard !isCrossfading else { return }
        isCrossfading = true
        
        print("🔀 Starting Crossfade to \(nextSong.title)")
        
        let outgoingPlayer = activePlayer
        let incomingPlayer = inactivePlayer
        
        // Determine file to play
        let fileToPlay: AVAudioFile
        if let existing = nextFile {
            fileToPlay = existing
        } else {
            do {
                fileToPlay = try AVAudioFile(forReading: nextSong.url)
            } catch {
                print("❌ Failed to load file for crossfade: \(error)")
                return
            }
        }
        
        // Start incoming player at volume 0
        let token = UUID()
        self.playbackToken = token // Take over token for the new primary song
        
        incomingPlayer.volume = 0
        incomingPlayer.scheduleFile(fileToPlay, at: nil) { [weak self] in
            guard let self = self, self.playbackToken == token else { return }
            self.handlePlaybackFinished()
        }
        incomingPlayer.play()
        
        // Update UI
        DispatchQueue.main.async {
            self.currentIndex = self.getNextIndex() ?? 0
            self.currentSong = nextSong
            self.duration = Double(fileToPlay.length) / fileToPlay.processingFormat.sampleRate
            self.currentFile = fileToPlay
            self.nextFile = nil // Consumed
            self.nextSongScheduled = false
            self.updateNowPlayingInfo()
        }
        
        // Animate Volumes
        let fadeDuration = gaplessPlayback ? crossfadeDuration : 0.5
        let steps = 20
        let stepDuration = fadeDuration / Double(steps)
        var currentStep = 0
        
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            
            outgoingPlayer.volume = 1.0 - progress
            incomingPlayer.volume = progress
            
            if currentStep >= steps {
                timer.invalidate()
                self.finishCrossfade()
            }
        }
    }
    
    private func finishCrossfade() {
        let outgoingPlayer = activePlayer
        
        // Swap indices
        activePlayerIndex = activePlayerIndex == 0 ? 1 : 0
        
        let newActivePlayer = activePlayer
        newActivePlayer.volume = 1.0
        
        outgoingPlayer.stop()
        outgoingPlayer.volume = 0
        
        stopCrossfade()
        seekFrame = 0
        
        scheduleNextSong()
    }
    
    private func stopCrossfade() {
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        isCrossfading = false
    }

    // MARK: - Normal Playback Handlers
    private func handlePlaybackFinished() {
        DispatchQueue.main.async {
             if !self.isCrossfading {
                 // Check if actually near end (Safety Guard)
                 if self.duration - self.currentTime < 2.0 {
                     self.playNext()
                 }
             }
        }
    }
    
    // MARK: - Controls
    func play() {
        if !engine.isRunning { try? engine.start() }
        activePlayer.play()
        isPlaying = true
        startTimers()
    }
    
    func pause() {
        activePlayer.pause()
        inactivePlayer.pause()
        isPlaying = false
        playbackTimer?.invalidate()
    }
    
    func togglePlayPause() { isPlaying ? pause() : play() }
    
    func stop() {
        playerA.stop()
        playerB.stop()
        engine.stop()
        isPlaying = false
        playbackTimer?.invalidate()
        stopCrossfade()
    }
    
    func playNext() {
        if isCrossfading {
            stopCrossfade()
            finishCrossfade()
            return
        }
        
        // Manual skip logic:
        // 1. Always advance, ignoring Repeat One
        // 2. Wrap if Repeat All
        // 3. Stop if Repeat Off and at end (or wrap if you prefer loose behavior, but strict is safer)
        
        let nextIndex = currentIndex + 1
        
        if nextIndex < queue.count {
            currentIndex = nextIndex
            startPlayback(with: queue[currentIndex])
        } else if repeatMode == .all {
            currentIndex = 0
            startPlayback(with: queue[0])
        } else {
            // End of queue and no repeat - do nothing or stop
            print("End of queue reached")
        }
    }
    
    func playNext(_ song: Song) {
        if queue.isEmpty {
            playSong(song, in: [song], at: 0)
        } else {
            let insertIndex = currentIndex + 1
            if insertIndex <= queue.count {
                queue.insert(song, at: insertIndex)
            } else {
                queue.append(song)
            }
        }
    }
    
    func playLater(_ song: Song) {
        if queue.isEmpty {
            playSong(song, in: [song], at: 0)
        } else {
            queue.append(song)
        }
    }
    
    func playPrevious() {
        if currentTime > 3 {
             seek(to: 0)
        } else {
             currentIndex = (currentIndex - 1 + queue.count) % queue.count
             startPlayback(with: queue[currentIndex])
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let file = currentFile else { return }
        let position = AVAudioFramePosition(time * sampleRate)
        
        // Update Token to invalidate current playback's completion handler
        let newToken = UUID()
        self.playbackToken = newToken
        
        activePlayer.stop()
        
        if position < file.length {
            let frameCount = AVAudioFrameCount(file.length - position)
            activePlayer.scheduleSegment(
                file,
                startingFrame: position,
                frameCount: frameCount,
                at: nil
            ) { [weak self] in
                // Add completion for this new segment
                guard let self = self, self.playbackToken == newToken else { return }
                self.handlePlaybackFinished()
            }
        }
        
        if isPlaying { activePlayer.play() }
        
        seekFrame = position
        currentTime = time
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
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackLoop()
        }
    }
    
    private func updatePlaybackLoop() {
        guard isPlaying else { return }
        
        // 1. Update Time
        if let nodeTime = activePlayer.lastRenderTime,
           let playerTime = activePlayer.playerTime(forNodeTime: nodeTime) {
            let currentFrame = seekFrame + playerTime.sampleTime
            currentTime = Double(currentFrame) / sampleRate
        }
        
        // 2. Check Triggers
        if !isSeeking {
             checkCrossfadeTrigger()
        }
        
        // 3. Auto-load next if getting close (gapless prep)
        if (duration - currentTime) < 5.0 && !nextSongScheduled {
            scheduleNextSong()
        }
        
    }
    
    // MARK: - EQ & Info
    func applyEqualizer(_ profile: EqualizerProfile) {
        self.activeEqualizerProfile = profile
        guard equalizerNode.bands.count == 10 && profile.bands.count == 10 else { return }
        
        for (index, band) in profile.bands.enumerated() {
            equalizerNode.bands[index].frequency = band.frequency
            equalizerNode.bands[index].filterType = .parametric
            equalizerNode.bands[index].bandwidth = 1.0
            equalizerNode.bands[index].gain = band.gain
            equalizerNode.bands[index].bypass = false
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if let data = song.artworkData, let img = PlatformImage.fromData(data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Notification Handlers
    private func setupNotifications() {
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

