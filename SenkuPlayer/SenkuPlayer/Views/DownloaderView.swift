//
//  DownloaderView.swift
//  SenkuPlayer
//
//  Created for SenkuMusic on macOS
//

import SwiftUI

#if os(macOS)
struct DownloaderView: View {
    @StateObject private var downloader = SpotifyDownloader.shared
    @State private var inputURL: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(ModernTheme.accentYellow)
                
                Text("Spotify Downloader")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Enter a Spotify Track, Album, or Playlist URL")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // Input
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.gray)
                
                TextField("https://open.spotify.com/track/...", text: $inputURL)
                    .textFieldStyle(.plain)
                    .font(.title3)
                
                if !inputURL.isEmpty {
                    Button {
                        inputURL = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 40)
            
            // Action
            Button {
                downloader.download(url: inputURL)
            } label: {
                HStack {
                    if downloader.isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.black)
                    } else {
                        Image(systemName: "arrow.down")
                    }
                    Text(downloader.isDownloading ? "Downloading..." : "Download")
                        .fontWeight(.bold)
                }
                .foregroundColor(.black)
                .frame(width: 200, height: 44)
                .background(inputURL.isEmpty ? Color.gray : ModernTheme.accentYellow)
                .cornerRadius(22)
            }
            .buttonStyle(.plain)
            .disabled(inputURL.isEmpty || downloader.isDownloading)
            
            // Logs Terminal
            VStack(alignment: .leading) {
                HStack {
                    Text("Terminal Output")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    Spacer()
                }
                .padding(.top, 8)
                
                ScrollView {
                    Text(downloader.logs.isEmpty ? "Ready..." : downloader.logs)
                        .font(.custom("Menlo", size: 11))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color.black)
                .cornerRadius(8)
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    DownloaderView()
        .preferredColorScheme(.dark)
}
#endif
