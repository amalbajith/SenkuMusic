//
//  AudioPlayerManager.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

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
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var originalQueue: [Song] = []
    private var cancellables = Set<AnyCancellable>()
    private var isSeeking = false
    
    enum RepeatMode {
        case off, one, all
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupNotifications()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("✅ Audio session configured for background playback")
        } catch {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
        #else
        print("✅ macOS Audio Session uses default system configuration")
        #endif
    }
    
    // MARK: - Remote Command Center
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Next track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        // Previous track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        // Seek
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }
    
    @objc private func playerDidFinishPlaying() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            play()
        case .all:
            playNext()
        case .off:
            if currentIndex < queue.count - 1 {
                playNext()
            } else {
                pause()
                seek(to: 0)
            }
        }
    }
    
    #if os(iOS)
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged - pause playback
            pause()
        default:
            break
        }
    }
    #endif
    
    // MARK: - Playback Control
    func playSong(_ song: Song, in queue: [Song], at index: Int) {
        self.queue = queue
        self.originalQueue = queue
        self.currentIndex = index
        self.currentSong = song
        
        setupPlayer(with: song)
        play()
    }
    
    private func setupPlayer(with song: Song) {
        // Remove existing time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        // Create new player
        let playerItem = AVPlayerItem(url: song.url)
        player = AVPlayer(playerItem: playerItem)
        
        // Update duration
        duration = song.duration
        
        // Reset seeking state
        isSeeking = false
        
        // Add time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            self.currentTime = time.seconds
        }
        
        // Reset current time
        currentTime = 0
        
        // Update Now Playing Info
        updateNowPlayingInfo()
        
        // Update Widget
        WidgetUpdateManager.shared.update(currentSong: currentSong, isPlaying: isPlaying)
    }
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        WidgetUpdateManager.shared.update(currentSong: currentSong, isPlaying: isPlaying)
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        WidgetUpdateManager.shared.update(currentSong: currentSong, isPlaying: isPlaying)
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentSong = nil
        currentTime = 0
        duration = 0
        queue = []
        originalQueue = []
        currentIndex = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        WidgetUpdateManager.shared.update(currentSong: nil, isPlaying: false)
    }
    
    func playNext() {
        guard !queue.isEmpty else { return }
        
        currentIndex = (currentIndex + 1) % queue.count
        currentSong = queue[currentIndex]
        
        if let song = currentSong {
            setupPlayer(with: song)
            play()
        }
    }
    
    func playNext(_ song: Song) {
        if queue.isEmpty {
            playSong(song, in: [song], at: 0)
        } else {
            queue.insert(song, at: min(currentIndex + 1, queue.count))
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
        guard !queue.isEmpty else { return }
        
        // If more than 3 seconds played, restart current song
        if currentTime > 3 {
            seek(to: 0)
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
            currentSong = queue[currentIndex]
            
            if let song = currentSong {
                setupPlayer(with: song)
                play()
            }
        }
    }
    
    func seek(to time: TimeInterval) {
        isSeeking = true
        
        // Optimistically update current time for UI responsiveness
        currentTime = time
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSeeking = false
                self?.updateNowPlayingInfo()
            }
        }
    }
    
    func toggleShuffle() {
        isShuffled.toggle()
        
        if isShuffled {
            // Save current song
            let currentSong = self.currentSong
            
            // Shuffle queue
            var shuffled = queue
            shuffled.shuffle()
            
            // Move current song to front if it exists
            if let song = currentSong, let index = shuffled.firstIndex(of: song) {
                shuffled.remove(at: index)
                shuffled.insert(song, at: 0)
                currentIndex = 0
            }
            
            queue = shuffled
        } else {
            // Restore original queue
            queue = originalQueue
            
            // Find current song in original queue
            if let song = currentSong, let index = queue.firstIndex(of: song) {
                currentIndex = index
            }
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Add artwork if available
        if let artworkData = song.artworkData,
           let image = PlatformImage.fromData(artworkData) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Cleanup
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
}
