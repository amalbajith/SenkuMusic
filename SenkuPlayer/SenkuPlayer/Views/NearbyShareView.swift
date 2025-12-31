//
//  NearbyShareView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import MultipeerConnectivity

struct NearbyShareView: View {
    let songs: [Song]
    @StateObject private var multipeer = MultipeerManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sentToPeers: Set<MCPeerID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Legal Warning Banner
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Personal Use Only • Transfer music you own or have rights to share")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.orange.opacity(0.3)),
                alignment: .bottom
            )
            
            // Main Content
            VStack {
            // Header / Animation
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(multipeer.availablePeers.isEmpty ? 1.0 : 1.2)
                        .opacity(multipeer.availablePeers.isEmpty ? 0.3 : 0)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: multipeer.availablePeers.isEmpty)
                    
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "wave.3.backward.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
                
                Text(!songs.isEmpty ? "Looking for your devices..." : "Discoverable to your devices")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 40)
            
            // List of Peers
            if multipeer.availablePeers.isEmpty {
                Spacer()
                Text("No devices found")
                    .foregroundColor(.secondary)
                Text("Make sure your other device has SenkuPlayer open")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(multipeer.availablePeers, id: \.self) { peer in
                    HStack {
                        Image(systemName: "iphone")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text(peer.displayName)
                            .font(.body)
                        
                        Spacer()
                        
                        if !songs.isEmpty {
                            // Sending Mode
                            if sentToPeers.contains(peer) {
                                Text("Sent")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if multipeer.connectedPeers.contains(peer) {
                                Button("Send") {
                                    sendSongs(to: peer)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .cornerRadius(20)
                            } else {
                                Button("Connect") {
                                    multipeer.invite(peer: peer)
                                }
                                .buttonStyle(.bordered)
                                .cornerRadius(20)
                            }
                        } else {
                            // Receiving/Browse Mode
                            if multipeer.connectedPeers.contains(peer) {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Button("Connect") {
                                    multipeer.invite(peer: peer)
                                }
                                .buttonStyle(.bordered)
                                .cornerRadius(20)
                            }
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            }
            
            // Sharing Info (Only if sending)
            if !songs.isEmpty {
                VStack(spacing: 8) {
                    Text("Transferring \(songs.count) song\(songs.count == 1 ? "" : "s"):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if songs.count == 1, let song = songs.first {
                        HStack {
                            if let artwork = song.artworkData, 
                               let platformImage = PlatformImage.fromData(artwork) {
                                Image(platformImage: platformImage)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .cornerRadius(4)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(song.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(12)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(songs) { song in
                                    VStack(alignment: .center, spacing: 4) {
                                        if let artwork = song.artworkData, 
                                           let platformImage = PlatformImage.fromData(artwork) {
                                            Image(platformImage: platformImage)
                                                .resizable()
                                                .frame(width: 40, height: 40)
                                                .cornerRadius(6)
                                        } else {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                                .overlay {
                                                    Image(systemName: "music.note")
                                                        .font(.caption)
                                                }
                                        }
                                        
                                        Text(song.title)
                                            .font(.system(size: 10))
                                            .lineLimit(1)
                                            .frame(width: 50)
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            } // End Main Content VStack
        } // End Outer VStack
        .navigationTitle("Device Transfer")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !songs.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            multipeer.startBrowsing()
        }
        .onDisappear {
            multipeer.stopBrowsing()
        }
    }
    
    private func sendSongs(to peer: MCPeerID) {
        for song in songs {
            multipeer.sendSong(song.url, to: peer)
        }
        sentToPeers.insert(peer)
    }
}
