//
//  NowPlayingActivity.swift
//  SenkuPlayer
//
//  Dynamic Island Live Activity Implementation
//  This file demonstrates how to implement Dynamic Island integration
//  Requires iOS 16.1+ and iPhone 14 Pro or later
//
//  ⚠️ IMPORTANT: This is a REFERENCE IMnPLEMENTATION
//  To use this code:
//  1. Create a Widget Extension target in Xcode
//  2. Move this file to the Widget Extension target
//  3. Enable Live Activities in Info.plist
//  4. Import required frameworks in the Widget Extension
//
//  This file is currently disabled to prevent build errors in the main app.
//

#if false // Enable this when you create a Widget Extension target

import ActivityKit
import SwiftUI
import AppIntents

// MARK: - Activity Attributes
@available(iOS 16.1, *)
struct NowPlayingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var songTitle: String
        var artist: String
        var isPlaying: Bool
        var progress: Double
        var duration: Double
    }
    
    var albumArtwork: String? // Base64 encoded image or URL
}

// MARK: - Live Activity Widget
@available(iOS 16.1, *)
struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    albumArtworkView(context: context)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    playbackControlsView(context: context)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    songInfoView(context: context)
                    progressView(context: context)
                }
            } compactLeading: {
                // Compact leading (left side of Dynamic Island)
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundColor(.white)
            } compactTrailing: {
                // Compact trailing (right side of Dynamic Island)
                Text(formatTime(context.state.progress))
                    .font(.caption2)
                    .foregroundColor(.white)
            } minimal: {
                // Minimal UI (when multiple activities are active)
                Image(systemName: "music.note")
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func albumArtworkView(context: ActivityViewContext<NowPlayingAttributes>) -> some View {
        if let artworkString = context.attributes.albumArtwork,
           let imageData = Data(base64Encoded: artworkString),
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundColor(.white)
                }
        }
    }
    
    @ViewBuilder
    private func playbackControlsView(context: ActivityViewContext<NowPlayingAttributes>) -> some View {
        HStack(spacing: 12) {
            Button(intent: PreviousTrackIntent()) {
                Image(systemName: "backward.fill")
                    .foregroundColor(.white)
            }
            
            Button(intent: PlayPauseIntent()) {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.white)
            }
            
            Button(intent: NextTrackIntent()) {
                Image(systemName: "forward.fill")
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private func songInfoView(context: ActivityViewContext<NowPlayingAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(context.state.songTitle)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(context.state.artist)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func progressView(context: ActivityViewContext<NowPlayingAttributes>) -> some View {
        VStack(spacing: 4) {
            ProgressView(value: context.state.progress, total: context.state.duration)
                .tint(.white)
            
            HStack {
                Text(formatTime(context.state.progress))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text(formatTime(context.state.duration))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Lock Screen View
@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<NowPlayingAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // Album Artwork
            if let artworkString = context.attributes.albumArtwork,
               let imageData = Data(base64Encoded: artworkString),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray)
                    .frame(width: 50, height: 50)
            }
            
            // Song Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.songTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(context.state.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                ProgressView(value: context.state.progress, total: context.state.duration)
                    .tint(.blue)
            }
            
            Spacer()
            
            // Play/Pause
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.title3)
        }
        .padding()
    }
}

// MARK: - App Intents for Interactive Controls
@available(iOS 16.1, *)
struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause"
    
    func perform() async throws -> some IntentResult {
        AudioPlayerManager.shared.togglePlayPause()
        return .result()
    }
}

@available(iOS 16.1, *)
struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    
    func perform() async throws -> some IntentResult {
        AudioPlayerManager.shared.playNext()
        return .result()
    }
}

@available(iOS 16.1, *)
struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    
    func perform() async throws -> some IntentResult {
        AudioPlayerManager.shared.playPrevious()
        return .result()
    }
}

// MARK: - Activity Manager Extension
@available(iOS 16.1, *)
extension AudioPlayerManager {
    private var currentActivity: Activity<NowPlayingAttributes>? {
        Activity<NowPlayingAttributes>.activities.first
    }
    
    func startLiveActivity() {
        guard let song = currentSong else { return }
        
        // Convert artwork to base64 if available
        var artworkBase64: String?
        if let artworkData = song.artworkData {
            artworkBase64 = artworkData.base64EncodedString()
        }
        
        let attributes = NowPlayingAttributes(albumArtwork: artworkBase64)
        let contentState = NowPlayingAttributes.ContentState(
            songTitle: song.title,
            artist: song.artist,
            isPlaying: isPlaying,
            progress: currentTime,
            duration: duration
        )
        
        do {
            let activity = try Activity<NowPlayingAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            print("✅ Live Activity started: \(activity.id)")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    func updateLiveActivity() {
        guard let song = currentSong else { return }
        
        let contentState = NowPlayingAttributes.ContentState(
            songTitle: song.title,
            artist: song.artist,
            isPlaying: isPlaying,
            progress: currentTime,
            duration: duration
        )
        
        Task {
            await currentActivity?.update(using: contentState)
        }
    }
    
    func endLiveActivity() {
        Task {
            await currentActivity?.end(dismissalPolicy: .immediate)
        }
    }
}

/*
 IMPLEMENTATION GUIDE:
 
 1. Enable Live Activities in Info.plist:
    <key>NSSupportsLiveActivities</key>
    <true/>
 
 2. Create a Widget Extension:
    - File → New → Target → Widget Extension
    - Name it "SenkuPlayerWidget"
    - Include Live Activity
 
 3. Add this file to the Widget Extension target
 
 4. Update AudioPlayerManager to call Live Activity methods:
    - Call startLiveActivity() when playback starts
    - Call updateLiveActivity() periodically (every 1-2 seconds)
    - Call endLiveActivity() when playback stops
 
 5. Add periodic updates in AudioPlayerManager:
    
    private var activityUpdateTimer: Timer?
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        
        if #available(iOS 16.1, *) {
            if currentActivity == nil {
                startLiveActivity()
            }
            
            // Update every 2 seconds
            activityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.updateLiveActivity()
            }
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        
        if #available(iOS 16.1, *) {
            updateLiveActivity()
            activityUpdateTimer?.invalidate()
        }
    }
 
 6. Test on iPhone 14 Pro or later with iOS 16.1+
 
 NOTES:
 - Live Activities have a maximum duration (default 8 hours)
 - They can be dismissed by the user
 - Background updates are limited to preserve battery
 - Consider using push notifications for updates when app is terminated
 */

#endif // End of Dynamic Island reference implementation
