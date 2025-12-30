# Quick Start Guide

## 🚀 Get Your Music Player Running in 5 Minutes

### Step 1: Open the Project (30 seconds)
```bash
cd /Users/amal/SenkuMusic/SenkuPlayer
open SenkuPlayer.xcodeproj
```

### Step 2: Add Files to Xcode (2 minutes)

The Swift files are already created but need to be added to the Xcode project:

1. In Xcode, right-click on the **SenkuPlayer** folder (yellow folder icon)
2. Select **"Add Files to 'SenkuPlayer'..."**
3. Navigate to `/Users/amal/SenkuMusic/SenkuPlayer/SenkuPlayer/`
4. Select these folders:
   - ✅ Models
   - ✅ Managers
   - ✅ Views
   - ✅ DynamicIsland
5. **IMPORTANT**: Uncheck "Copy items if needed" (files are already in place)
6. Ensure "Create groups" is selected
7. Ensure "SenkuPlayer" target is checked
8. Click **Add**

### Step 3: Enable Background Audio (1 minute)

1. Select the **SenkuPlayer** target (blue icon at top of project navigator)
2. Click **Signing & Capabilities** tab
3. Click **+ Capability** button
4. Search for and add **"Background Modes"**
5. In the Background Modes section, check:
   - ✅ **Audio, AirPlay, and Picture in Picture**

### Step 4: Configure Info.plist (1 minute)

1. Still in the **SenkuPlayer** target
2. Click the **Info** tab
3. Hover over any row and click the **+** button
4. Add these keys (type the exact names):

| Key | Type | Value |
|-----|------|-------|
| `Privacy - Media Library Usage Description` | String | `We need access to your music library to play your songs` |
| `Supports opening documents in place` | Boolean | `YES` |
| `Application supports iTunes file sharing` | Boolean | `YES` |

**Quick tip**: Start typing the key name and Xcode will auto-suggest the correct key.

### Step 5: Configure Signing (30 seconds)

1. Still in **Signing & Capabilities** tab
2. Under **Signing** section:
   - ✅ Check "Automatically manage signing"
   - Select your **Team** (your Apple ID)
   - Xcode will auto-generate a bundle identifier

### Step 6: Build and Run! (30 seconds)

1. Select your iPhone from the device dropdown (or iOS Simulator)
2. Press **⌘R** or click the Play button
3. Wait for build to complete
4. App launches! 🎉

## 🎵 Adding Your First Songs

### Option 1: Using Files App (Recommended for Testing)

1. In the app, tap the **folder icon** (top right)
2. Navigate to a folder with MP3 files
3. Tap **Select** or the folder name
4. App will scan and import all MP3 files
5. Watch the progress bar
6. Songs appear in the library!

### Option 2: Using iTunes File Sharing

1. Connect your iPhone to your Mac
2. Open **Finder**
3. Select your iPhone in the sidebar
4. Click the **Files** tab
5. Find **SenkuPlayer** in the list
6. Drag MP3 files into the SenkuPlayer folder
7. In the app, use the folder picker to scan the imported files

### Option 3: Using Simulator (for Development)

For testing in Simulator, you can add sample MP3 files:

```bash
# Create a test music folder
mkdir -p ~/Desktop/TestMusic

# Add your MP3 files to ~/Desktop/TestMusic
# Then in the app, use the folder picker to select this folder
```

## 🎮 Using the App

### Playing Music
1. Go to **Songs** tab
2. Tap any song to play
3. Mini player appears at bottom
4. Tap mini player for full-screen view

### Creating Playlists
1. Go to **Playlists** tab
2. Tap **+** button
3. Enter playlist name
4. Go to **Songs** tab
5. Tap **Select**
6. Select songs
7. Tap **Add to Playlist**
8. Choose your playlist

### Background Playback
1. Start playing a song
2. Press Home button or lock device
3. Music continues playing! 🎵
4. Control from lock screen or Control Center

## ⚠️ Troubleshooting

### Build Errors

**"Cannot find type 'Song' in scope"**
- Solution: Files not added to target
- Fix: Right-click file → Show File Inspector → Check "SenkuPlayer" under Target Membership

**"No such module 'AVFoundation'"**
- Solution: Clean build folder
- Fix: Product → Clean Build Folder (⇧⌘K), then rebuild

### Runtime Issues

**App crashes on launch**
- Check Xcode console for error messages
- Verify all files are added to the target
- Ensure deployment target is iOS 17.0+

**Background audio doesn't work**
- Verify Background Modes capability is enabled
- Check "Audio, AirPlay, and Picture in Picture" is checked
- Test on a physical device (Simulator has limitations)

**Can't access files**
- Verify Info.plist permissions are set
- Check folder picker permissions were granted
- Try selecting a different folder

### Testing on Physical Device

**"Untrusted Developer"**
1. On iPhone: Settings → General → VPN & Device Management
2. Tap your developer profile
3. Tap "Trust [Your Name]"
4. Confirm

**"Failed to verify code signature"**
- Ensure you selected your Team in Signing & Capabilities
- Try toggling "Automatically manage signing" off and on

## 📱 Recommended Test Devices

- **Best**: iPhone 14 Pro or later (for Dynamic Island testing)
- **Good**: Any iPhone running iOS 17.0+
- **OK**: iOS Simulator (limited audio features)

## 🎯 Next Steps

Once the app is running:

1. ✅ Add some MP3 files
2. ✅ Test playback controls
3. ✅ Create a playlist
4. ✅ Test background playback
5. ✅ Test lock screen controls
6. ✅ Explore the beautiful UI!

## 📚 Additional Resources

- **Full Documentation**: See `README.md`
- **Configuration Details**: See `CONFIGURATION.md`
- **Implementation Details**: See `IMPLEMENTATION_SUMMARY.md`
- **Dynamic Island**: See `DynamicIsland/NowPlayingActivity.swift`

## 🆘 Need Help?

Common issues and solutions:

1. **Files not showing up**: Make sure they're MP3 format with .mp3 extension
2. **No artwork**: Some MP3s don't have embedded artwork (app shows gradient placeholder)
3. **Wrong metadata**: Use a tool like Mp3tag to edit ID3 tags
4. **Playback stops**: Check device isn't in Low Power Mode

## 🎉 You're All Set!

Your Apple Music clone is ready to use. Enjoy your local music with a beautiful, professional interface!

---

**Estimated Total Setup Time**: 5-10 minutes
**Difficulty**: Easy (just follow the steps)
**Result**: Production-quality music player! 🎵
