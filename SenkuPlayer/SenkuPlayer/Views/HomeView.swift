//
//  HomeView.swift
//  SenkuPlayer
//
//  Browse-first landing screen inspired by Apple Music-style rails
//

import SwiftUI

struct HomeView: View {
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var favorites = FavoritesManager.shared
    @State private var showingFilePicker = false
    @State private var backgroundHeroColor: Color = ModernTheme.backgroundSecondary
    @State private var lastProcessedSongId: UUID? = nil
    
    @AppStorage("performanceProfile") private var performanceProfile: PerformanceProfile = .balanced

    private var recentSongs: [Song] {
        library.getRecentlyPlayed(limit: 12)
    }

    private var featuredSongs: [Song] {
        if !recentSongs.isEmpty {
            return Array(recentSongs.prefix(6))
        }
        return Array(library.songs.prefix(6))
    }

    private var favoriteSongs: [Song] {
        Array(favorites.getFavorites(from: library.songs).prefix(6))
    }

    private var featuredAlbums: [Album] {
        Array(library.albums.prefix(8))
    }

    private var featuredArtists: [Artist] {
        Array(library.artists.prefix(8))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        heroSection
                        quickLinksSection

                        if !featuredSongs.isEmpty {
                            songRailSection(
                                title: player.currentSong != nil ? "Continue Listening" : (recentSongs.isEmpty ? "Start Listening" : "Recently Played"),
                                subtitle: player.currentSong != nil ? "Pick up where you left off." : (recentSongs.isEmpty ? "Pick a song and start your session." : "Jump back into what you had on.")
                            )
                        }

                        if !featuredAlbums.isEmpty {
                            albumRailSection
                        }

                        if !featuredArtists.isEmpty {
                            artistRailSection
                        }

                        if !favoriteSongs.isEmpty {
                            favoriteMixSection
                        }
                    }
                    .padding(.horizontal, ModernTheme.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, player.currentSong != nil ? 120 : 40)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { urls in
                    library.importFiles(urls)
                }
            }
            .onAppear {
                updateHeroColor()
            }
            .onChange(of: heroSong) { _, _ in
                updateHeroColor()
            }
        }
    }

    private func updateHeroColor() {
        guard let song = heroSong, song.id != lastProcessedSongId else { return }
        lastProcessedSongId = song.id
        
        Task {
            let color = await DominantColorExtractor.shared.extractDominantColor(for: song)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.backgroundHeroColor = color
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Home")
                .font(ModernTheme.heroTitle())
                .foregroundColor(ModernTheme.textPrimary)

            Text(heroSubtitle)
                .font(ModernTheme.body())
                .foregroundColor(ModernTheme.textSecondary)

            if heroSong != nil {
                activeHeroCard
            } else {
                emptyHeroCard
            }
        }
    }

    private var activeHeroCard: some View {
        let cardHeight: CGFloat = 340

        return ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(ModernTheme.backgroundSecondary)
                .overlay {
                    HeroArtworkBackdrop(
                        song: heroSong,
                        accentColor: backgroundHeroColor
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.04),
                            backgroundHeroColor.opacity(0.12),
                            Color.black.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.05),
                            Color.black.opacity(0.28),
                            Color.black.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 16) {
                Text(heroEyebrow)
                    .font(.system(size: 11, weight: .black))
                    .kerning(2.2)
                    .foregroundColor(Color.white.opacity(0.7))

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(heroTitle)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(heroDescription)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.82))
                            .lineLimit(2)

                        Text(heroContextLine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.62))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    if let heroSong = heroSong {
                        SongArtworkThumbnail(song: heroSong, size: 120, cornerRadius: 24)
                            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14)
                    }
                }

                Spacer(minLength: 0)

                primaryHeroButton
                addMusicHeroButton
            }
            .padding(24)
        }
        .frame(height: cardHeight)
    }

    private var emptyHeroCard: some View {
        let cardHeight: CGFloat = 250

        return ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            ModernTheme.darkGray,
                            ModernTheme.backgroundSecondary,
                            ModernTheme.pureBlack
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(backgroundHeroColor.opacity(0.18))
                        .frame(width: 180, height: 180)
                        .blur(radius: 24)
                        .offset(x: 24, y: -24)
                }

            VStack(alignment: .leading, spacing: 16) {
                Text(heroEyebrow)
                    .font(.system(size: 11, weight: .black))
                    .kerning(2.2)
                    .foregroundColor(Color.white.opacity(0.7))

                Text(heroTitle)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(heroDescription)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.82))
                    .lineLimit(3)

                Spacer(minLength: 0)

                primaryHeroButton
                addMusicHeroButton
            }
            .padding(24)
        }
        .frame(height: cardHeight)
    }

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Browse")
                .font(ModernTheme.headline())
                .foregroundColor(ModernTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    quickLink(title: "Songs", systemImage: "music.note", destination: AnyView(LibraryView()))
                    quickLink(title: "Albums", systemImage: "square.stack.fill", destination: AnyView(AlbumsListView(searchText: "")))
                    quickLink(title: "Artists", systemImage: "music.mic", destination: AnyView(ArtistsListView(searchText: "")))
                    quickLink(title: "Playlists", systemImage: "music.note.list", destination: AnyView(PlaylistsListView(searchText: "")))
                    quickLink(title: "Recents", systemImage: "clock.arrow.circlepath", destination: AnyView(RecentlyPlayedView()))
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func songRailSection(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ModernTheme.headline())
                    .foregroundColor(ModernTheme.textPrimary)

                Text(subtitle)
                    .font(ModernTheme.caption())
                    .foregroundColor(ModernTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(featuredSongs) { song in
                        SongShelfCard(song: song) {
                            let queue = recentSongs.isEmpty ? library.songs : recentSongs
                            let index = queue.firstIndex(of: song) ?? 0
                            player.playSong(song, in: queue.isEmpty ? [song] : queue, at: index)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var albumRailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Top Albums", destination: AnyView(AlbumsListView(searchText: "")))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(featuredAlbums, id: \.id) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            HomeAlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var artistRailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Artists", destination: AnyView(ArtistsListView(searchText: "")))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(featuredArtists, id: \.id) { artist in
                        NavigationLink(destination: ArtistDetailView(artist: artist)) {
                            HomeArtistCard(artist: artist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var favoriteMixSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Favorite Mix", destination: AnyView(FavoritesDetailView()))

            VStack(spacing: 10) {
                ForEach(favoriteSongs) { song in
                    Button {
                        let queue = favoriteSongs
                        let index = queue.firstIndex(of: song) ?? 0
                        player.playSong(song, in: queue, at: index)
                    } label: {
                        HStack(spacing: 12) {
                            SongArtworkThumbnail(song: song, size: 52, cornerRadius: 10)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title.normalizedForDisplay)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(ModernTheme.textPrimary)
                                    .lineLimit(1)

                                Text(song.artist.normalizedForDisplay)
                                    .font(ModernTheme.caption())
                                    .foregroundColor(ModernTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "heart.fill")
                                .foregroundColor(ModernTheme.danger.opacity(0.9))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(ModernTheme.backgroundSecondary.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(ModernTheme.borderSubtle, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(title: String, destination: AnyView) -> some View {
        HStack {
            Text(title)
                .font(ModernTheme.headline())
                .foregroundColor(ModernTheme.textPrimary)

            Spacer()

            NavigationLink(destination: destination) {
                Text("See All")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ModernTheme.textSecondary)
            }
        }
    }

    private func overviewCard(value: String, label: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ModernTheme.accentYellow)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ModernTheme.textPrimary)

            Text(label)
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ModernTheme.backgroundSecondary.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(ModernTheme.borderSubtle, lineWidth: 1)
        }
    }

    private func quickLink(title: String, systemImage: String, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(ModernTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ModernTheme.backgroundSecondary.opacity(0.8), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(ModernTheme.borderSubtle, lineWidth: 1)
            }
        }
    }

    private var heroSubtitle: String {
        if library.songs.isEmpty {
            return "Build your collection and start listening."
        }
        return "Your library, mixes, and favorites in one place."
    }

    private var heroEyebrow: String {
        recentSongs.isEmpty ? "WELCOME BACK" : "JUMP RIGHT IN"
    }

    private var heroTitle: String {
        if let currentSong = player.currentSong {
            return currentSong.title.normalizedForDisplay
        }
        if let recentSong = recentSongs.first {
            return recentSong.title.normalizedForDisplay
        }
        return "Start Your Session"
    }

    private var heroDescription: String {
        if let currentSong = player.currentSong {
            return currentSong.artist.normalizedForDisplay
        }
        if let recentSong = recentSongs.first {
            return "Recently played • \(recentSong.artist.normalizedForDisplay)"
        }
        return "Import music, build playlists, and browse your collection from a proper home screen."
    }

    private var heroContextLine: String {
        guard let song = heroSong else { return "" }

        if !song.album.isEmpty, song.album != "Unknown Album" {
            return song.album.normalizedForDisplay
        }

        return song.artist.normalizedForDisplay
    }

    private var heroSong: Song? {
        player.currentSong ?? recentSongs.first ?? featuredSongs.first
    }

    private var primaryHeroLabel: String {
        library.songs.isEmpty ? "Import Music" : (player.currentSong == nil ? "Play Library" : "Now Playing")
    }

    private var primaryHeroIcon: String {
        library.songs.isEmpty ? "square.and.arrow.down" : (player.currentSong == nil ? "play.fill" : "waveform")
    }

    private var primaryHeroDisabled: Bool {
        false
    }

    private func primaryHeroAction() {
        if library.songs.isEmpty {
            showingFilePicker = true
        } else if player.currentSong == nil {
            if let firstSong = library.songs.first {
                player.playSong(firstSong, in: library.songs, at: 0)
            }
        } else {
            player.isNowPlayingPresented = true
        }
    }

    private var primaryHeroButton: some View {
        Button(action: primaryHeroAction) {
            Label(primaryHeroLabel, systemImage: primaryHeroIcon)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(!library.songs.isEmpty ? ModernTheme.accentYellow : ModernTheme.mediumGray, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
        }
        .disabled(primaryHeroDisabled)
        .opacity(primaryHeroDisabled ? 0.5 : 1)
    }

    private var addMusicHeroButton: some View {
        Button {
            showingFilePicker = true
        } label: {
            Label("Add Music", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var heroPrimaryButtonGradient: LinearGradient {
        let startColor = heroSong == nil ? ModernTheme.mediumGray : backgroundHeroColor.opacity(0.95)
        let endColor = heroSong == nil ? ModernTheme.darkGray : backgroundHeroColor.opacity(0.68)

        return LinearGradient(
            colors: [startColor, endColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct HeroArtworkBackdrop: View {
    let song: Song?
    let accentColor: Color
    @AppStorage("performanceProfile") private var performanceProfile: PerformanceProfile = .balanced
    
    @State private var cachedImage: PlatformImage? = nil
    @State private var lastSongId: UUID? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Base
                accentColor.opacity(0.8)
                
                if performanceProfile != .eco {
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.92),
                            accentColor.opacity(0.42),
                            ModernTheme.backgroundSecondary,
                            ModernTheme.pureBlack
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.5),
                            accentColor.opacity(0.12),
                            .clear
                        ],
                        center: .trailing,
                        startRadius: 20,
                        endRadius: geometry.size.width * 0.75
                    )
                    .offset(x: geometry.size.width * 0.18, y: -geometry.size.height * 0.1)
                }

                if let image = cachedImage {
                    Image(platformImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width * 1.15, height: geometry.size.height * 1.15)
                        .scaleEffect(1.25)
                        .blur(radius: performanceProfile == .eco ? 0 : (performanceProfile == .balanced ? 30 : 50))
                        .opacity(performanceProfile == .eco ? 0.3 : 0.7)
                }
            }
            .onAppear { updateImage() }
            .onChange(of: song?.id) { _, _ in updateImage() }
        }
    }
    
    private func updateImage() {
        guard let song = song, song.id != lastSongId else { return }
        lastSongId = song.id
        
        if let data = song.artworkData {
            Task.detached(priority: .userInitiated) {
                if let platformImage = PlatformImage.fromData(data) {
                    await MainActor.run {
                        self.cachedImage = platformImage
                    }
                }
            }
        } else {
            self.cachedImage = nil
        }
    }
}

private struct SongShelfCard: View {
    let song: Song
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                SongArtworkThumbnail(song: song, size: 160, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title.normalizedForDisplay)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ModernTheme.textPrimary)
                        .lineLimit(2)

                    Text(song.artist.normalizedForDisplay)
                        .font(ModernTheme.caption())
                        .foregroundColor(ModernTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeAlbumCard: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let artworkData = album.displayArtworkData,
                   let platformImage = PlatformImage.fromData(artworkData) {
                    Image(platformImage: platformImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.mediumGray, ModernTheme.darkGray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 42))
                                .foregroundColor(ModernTheme.textTertiary)
                        }
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(album.name.normalizedForDisplay)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ModernTheme.textPrimary)
                .lineLimit(2)

            Text(album.artist.normalizedForDisplay)
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
    }
}

private struct HomeArtistCard: View {
    let artist: Artist

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let firstSong = artist.songs.first {
                    SongArtworkThumbnail(song: firstSong, size: 124, cornerRadius: 62)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ModernTheme.mediumGray, ModernTheme.darkGray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 124, height: 124)
                        .overlay {
                            Text(artist.name.prefix(1).uppercased())
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(ModernTheme.textPrimary)
                        }
                }
            }

            Text(artist.name.normalizedForDisplay)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ModernTheme.textPrimary)
                .lineLimit(1)

            Text("\(artist.totalSongs) songs")
                .font(ModernTheme.caption())
                .foregroundColor(ModernTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 124, alignment: .leading)
    }
}

struct SongArtworkThumbnail: View {
    let song: Song
    let size: CGFloat
    let cornerRadius: CGFloat
    
    @State private var decodedImage: PlatformImage? = nil
    @State private var lastSongId: UUID? = nil

    var body: some View {
        ZStack {
            if let image = decodedImage {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [ModernTheme.mediumGray.opacity(0.5), ModernTheme.darkGray.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.28))
                            .foregroundColor(ModernTheme.textTertiary.opacity(0.5))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ModernTheme.borderSubtle, lineWidth: 1)
        }
        .onAppear { decodeImage() }
        .onChange(of: song.id) { _, _ in decodeImage() }
    }
    
    private func decodeImage() {
        guard song.id != lastSongId else { return }
        lastSongId = song.id
        
        if let data = song.artworkData {
            Task.detached(priority: .userInitiated) {
                if let platformImage = PlatformImage.fromData(data) {
                    await MainActor.run {
                        self.decodedImage = platformImage
                    }
                }
            }
        } else {
            self.decodedImage = nil
        }
    }
}

#Preview {
    HomeView()
}
