//
//  NearbyShareView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import MultipeerConnectivity

struct NearbyShareView: View {
    let song: Song?
    @StateObject private var multipeer = MultipeerManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sentToPeers: Set<MCPeerID> = []
    
    var body: some View {
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
                
                Text(song != nil ? "Looking for nearby friends..." : "Discoverable to others")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 40)
            
            // List of Peers
            if multipeer.availablePeers.isEmpty {
                Spacer()
                Text("No one nearby found")
                    .foregroundColor(.secondary)
                Text("Make sure they have SenkuPlayer open")
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
                        
                        if let _ = song {
                            // Sending Mode
                            if sentToPeers.contains(peer) {
                                Text("Sent")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if multipeer.connectedPeers.contains(peer) {
                                Button("Send") {
                                    sendSong(to: peer)
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
                .listStyle(.insetGrouped)
            }
            
            // Sharing Info (Only if sending)
            if let song = song {
                VStack(spacing: 8) {
                    Text("Sharing:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if let artwork = song.artworkData, let uiImage = UIImage(data: artwork) {
                            Image(uiImage: uiImage)
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
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .navigationTitle("Nearby Share")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only show Cancel if presented modally with a song (heuristic)
            if song != nil {
                ToolbarItem(placement: .navigationBarLeading) {
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
    
    private func sendSong(to peer: MCPeerID) {
        guard let song = song else { return }
        multipeer.sendSong(song.url, to: peer)
        sentToPeers.insert(peer)
    }
}
