//
//  LibraryView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var showingFilePicker = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Search Bar Section
                    searchBarSection
                        .padding(.top, 16)
                    
                    // Tab Selector
                    if !library.songs.isEmpty && !library.isScanning {
                        tabSelector
                            .padding(.top, 20)
                    }
                    
                    // Content
                    Group {
                        if library.isScanning {
                            ScanningView(progress: library.scanProgress)
                                .frame(maxHeight: .infinity)
                        } else if library.songs.isEmpty {
                            emptyState
                                .frame(maxHeight: .infinity)
                        } else {
                            tabContent
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { urls in
                    library.importFiles(urls)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("Library")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(ModernTheme.textPrimary)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    AudioPlayerManager.shared.startAutoMix(songs: library.songs)
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.black) // Text contrast on bright accent
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [ModernTheme.accentYellow, ModernTheme.accentYellowSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: ModernTheme.accentYellow.opacity(0.4), radius: 8, x: 0, y: 0)
                }
                
                Button {
                    showingFilePicker = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(ModernTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
    
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 20) {
            Spacer()
            
            TabButton(icon: "music.note", isSelected: selectedTab == 0) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 0
                }
            }
            TabButton(icon: "clock", isSelected: selectedTab == 1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 1
                }
            }
            TabButton(icon: "person.2", isSelected: selectedTab == 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 2
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Tab Content
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                SongsListView(songs: library.songs, searchText: searchText)
            case 1:
                RecentlyPlayedView()
            case 2:
                ArtistsListView(searchText: searchText)
            default:
                SongsListView(songs: library.songs, searchText: searchText)
            }
        }
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ModernTheme.lightGray)
                .padding(.leading, 16)
            
            TextField("", text: $searchText, prompt: 
                Text("Search your library...")
                    .foregroundColor(ModernTheme.lightGray)
            )
            .font(ModernTheme.body())
            .foregroundColor(ModernTheme.textPrimary)
            .padding(.vertical, 12)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ModernTheme.lightGray)
                        .padding(.trailing, 16)
                }
            }
        }
        .background(ModernTheme.backgroundSecondary)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(ModernTheme.borderSubtle, lineWidth: 1)
        }
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 70))
                .foregroundColor(ModernTheme.mediumGray)
            
            Text("Your library is empty")
                .font(ModernTheme.title())
                .foregroundColor(ModernTheme.textPrimary)
            
            Text("Import your music files to get started")
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingFilePicker = true
            } label: {
                Text("Import Music")
                    .pillButtonStyle()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isSelected ? ModernTheme.pureBlack : ModernTheme.textPrimary)
                .frame(width: 50, height: 50)
                .background(isSelected ? ModernTheme.accentYellow : ModernTheme.backgroundSecondary)
                .overlay {
                    Circle()
                        .stroke(isSelected ? ModernTheme.borderStrong : ModernTheme.borderSubtle, lineWidth: 1)
                }
                .cornerRadius(25)
        }
    }
}

// MARK: - Supporting Views

struct RecentlyAddedCard: View {
    let song: Song
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // Artwork Container
                ZStack {
                    if let artworkData = song.artworkData,
                       let platformImage = PlatformImage.fromData(artworkData) {
                        Image(platformImage: platformImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ModernTheme.accentYellow.opacity(0.15)
                            .overlay(Image(systemName: "music.note").foregroundColor(ModernTheme.accentYellow.opacity(0.8)))
                    }
                }
                .frame(width: 170, height: 170)
                .cornerRadius(12)
                .shadow(radius: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title.normalizedForDisplay)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(song.artist.normalizedForDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(ModernTheme.lightGray)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SongRowView: View {
    let song: Song
    let action: () -> Void
    @StateObject private var player = AudioPlayerManager.shared
    
    var isCurrentSong: Bool {
        player.currentSong?.id == song.id
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Thumbnail
                ZStack {
                    if let artworkData = song.artworkData,
                       let platformImage = PlatformImage.fromData(artworkData) {
                        Image(platformImage: platformImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(Image(systemName: "music.note").font(.caption))
                    }
                    
                    if isCurrentSong {
                        Color.black.opacity(0.4)
                        Image(systemName: "waveform")
                            .foregroundColor(ModernTheme.accentYellow)
                            .font(.caption)
                    }
                }
                .frame(width: 48, height: 48)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title.normalizedForDisplay)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isCurrentSong ? ModernTheme.accentYellow : .white)
                        .lineLimit(1)
                    
                    Text("\(song.artist.normalizedForDisplay) • \(song.album.normalizedForDisplay)")
                        .font(.system(size: 12))
                        .foregroundColor(ModernTheme.lightGray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(formatDuration(song.duration))
                    .font(.system(size: 12))
                    .foregroundColor(ModernTheme.lightGray)
                
                Menu {
                    Button {
                        player.playNext(song: song)
                    } label: {
                        Label("Play Next", systemImage: "text.insert")
                    }
                    
                    Button {
                        FavoritesManager.shared.toggleFavorite(song: song)
                    } label: {
                        Label(
                            FavoritesManager.shared.isFavorite(song: song) ? "Remove from Favorites" : "Mark as Favorite",
                            systemImage: FavoritesManager.shared.isFavorite(song: song) ? "heart.fill" : "heart"
                        )
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        // Delete logic if needed
                    } label: {
                        Label("Delete from Library", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(ModernTheme.lightGray)
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isCurrentSong ? Color.white.opacity(0.05) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Scanning View
struct ScanningView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ModernTheme.mediumGray)
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(ModernTheme.accentYellow)
                    .frame(width: 300 * CGFloat(progress), height: 4)
            }
            .frame(width: 300)
            
            Text("Scanning Library... \(Int(progress * 100))%")
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.lightGray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recently Added Section Supporting Views

#Preview {
    LibraryView()
}
