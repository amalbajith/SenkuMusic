# Xcode Project Configuration Guide

## Required Configuration Steps

### 1. Background Audio Capability

**Steps:**
1. Open `SenkuPlayer.xcodeproj` in Xcode
2. Select the **SenkuPlayer** target in the project navigator
3. Click on the **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Search for and add **Background Modes**
6. In the Background Modes section, check:
   - ✅ **Audio, AirPlay, and Picture in Picture**

### 2. Info.plist Configuration

**Steps:**
1. Select the **SenkuPlayer** target
2. Click on the **Info** tab
3. Add the following custom iOS target properties:

#### Required Keys:

| Key | Type | Value |
|-----|------|-------|
| Privacy - Media Library Usage Description | String | "We need access to your music library to play your songs" |
| Supports opening documents in place | Boolean | YES |
| Application supports iTunes file sharing | Boolean | YES |

#### Raw Info.plist XML (if editing directly):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Background Audio -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
    
    <!-- File Access -->
    <key>NSAppleMusicUsageDescription</key>
    <string>We need access to your music library to play your songs</string>
    
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>
    
    <key>UIFileSharingEnabled</key>
    <true/>
    
    <key>UISupportsDocumentBrowser</key>
    <true/>
    
    <!-- Existing keys will be here -->
</dict>
</plist>
```

### 3. Deployment Target

Ensure your deployment target is set correctly:
- **Minimum iOS Version**: 17.0
- **Target Device**: iPhone

**Steps:**
1. Select the **SenkuPlayer** target
2. Go to **General** tab
3. Under **Deployment Info**, set:
   - **Minimum Deployments**: iOS 17.0
   - **Supported Destinations**: iPhone

### 4. File Organization in Xcode

Add all the created files to the Xcode project:

**Steps:**
1. Right-click on the **SenkuPlayer** folder in Xcode
2. Select **Add Files to "SenkuPlayer"...**
3. Navigate to the project directory
4. Select all the new folders (Models, Managers, Views)
5. Ensure **"Copy items if needed"** is unchecked (files are already in place)
6. Ensure **"Create groups"** is selected
7. Click **Add**

### 5. Build Settings

Verify these build settings:

**Steps:**
1. Select the **SenkuPlayer** target
2. Go to **Build Settings** tab
3. Search for and verify:
   - **Swift Language Version**: Swift 5
   - **Enable Bitcode**: No (for iOS 14+)

### 6. Signing

Configure code signing:

**Steps:**
1. Select the **SenkuPlayer** target
2. Go to **Signing & Capabilities** tab
3. Under **Signing**:
   - Check **Automatically manage signing**
   - Select your **Team**
   - Xcode will generate a bundle identifier (e.g., `com.yourname.SenkuPlayer`)

## Verification Checklist

Before running the app, verify:

- [ ] Background Modes capability added with Audio enabled
- [ ] Info.plist has all required privacy descriptions
- [ ] Deployment target is iOS 17.0+
- [ ] All source files are added to the target
- [ ] Code signing is configured
- [ ] Build succeeds without errors

## Testing Background Audio

1. Build and run the app on a physical device (Simulator has limited audio capabilities)
2. Add some MP3 files to the library
3. Start playing a song
4. Press the Home button or lock the device
5. Verify music continues playing
6. Check lock screen shows Now Playing info
7. Test playback controls from lock screen

## Troubleshooting

### Build Errors

**"Cannot find type 'Song' in scope"**
- Solution: Ensure all files are added to the target
- Right-click file → Show File Inspector → Target Membership → Check SenkuPlayer

**"Module 'AVFoundation' not found"**
- Solution: This shouldn't happen as AVFoundation is a system framework
- Clean build folder: Product → Clean Build Folder (⇧⌘K)

### Runtime Issues

**"App crashes on launch"**
- Check console for error messages
- Verify audio session setup in SenkuPlayerApp.swift

**"Background audio stops"**
- Verify Background Modes capability is enabled
- Check device is not in Low Power Mode
- Ensure audio session category is `.playback`

**"Cannot access files"**
- Verify Info.plist permissions are set
- Check file URLs are valid
- Ensure security-scoped resource access

## Dynamic Island Integration (Advanced)

For Dynamic Island support on iPhone 14 Pro and later:

### Additional Steps Required:

1. **Add ActivityKit Framework**
   - Target → General → Frameworks, Libraries, and Embedded Content
   - Add ActivityKit.framework

2. **Create Live Activity**
   - Create a new Swift file: `NowPlayingActivity.swift`
   - Define ActivityAttributes for Now Playing info
   - Update AudioPlayerManager to start/update/end activities

3. **Configure Info.plist**
   ```xml
   <key>NSSupportsLiveActivities</key>
   <true/>
   ```

4. **Request Permission**
   - Add ActivityKit permission request in app

**Note**: Dynamic Island implementation is complex and requires iOS 16.1+. The current implementation provides full background audio support and lock screen integration, which works on all iOS 17+ devices.

## Additional Resources

- [Apple Documentation: Background Execution](https://developer.apple.com/documentation/avfoundation/media_playback/creating_a_basic_video_player_ios_and_tvos/enabling_background_audio)
- [Apple Documentation: Now Playing Info](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- [Apple Documentation: Remote Command Center](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter)
- [Apple Documentation: Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
