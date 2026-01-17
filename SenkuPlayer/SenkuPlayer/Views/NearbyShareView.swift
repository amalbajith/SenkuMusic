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
    @State private var radarAnimation = false
    @State private var beamRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            ModernTheme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "x")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("SHARE RADAR")
                        .font(.system(size: 16, weight: .black))
                        .kerning(4)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        // Settings action
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // MARK: - Selected Song Card
                if let song = songs.first {
                    HStack(spacing: 16) {
                        // Artwork
                        ZStack {
                            if let artworkData = song.artworkData,
                               let platformImage = PlatformImage.fromData(artworkData) {
                                Image(platformImage: platformImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title.normalizedForDisplay)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(song.artist.normalizedForDisplay)
                                .font(.system(size: 14))
                                .foregroundColor(ModernTheme.accentYellow.opacity(0.6))
                            
                            if songs.count > 1 {
                                Text("+ \(songs.count - 1) more")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ModernTheme.accentYellow.opacity(0.2))
                                    .foregroundColor(ModernTheme.accentYellow)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Spacer()
                        
                        // Visualizer Icon
                        Image(systemName: "waveform")
                            .font(.system(size: 18))
                            .foregroundColor(ModernTheme.accentYellow)
                            .padding(.trailing, 8)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                }
                
                Spacer()
                
                // MARK: - Radar Visualization
                ZStack {
                    // Particle Background
                    ForEach(0..<15) { i in
                        Circle()
                            .fill(ModernTheme.accentYellow.opacity(Double.random(in: 0.1...0.3)))
                            .frame(width: 2, height: 2)
                            .offset(
                                x: CGFloat.random(in: -200...200),
                                y: CGFloat.random(in: -200...200)
                            )
                            .opacity(radarAnimation ? 1 : 0)
                            .animation(.easeInOut(duration: Double.random(in: 2...4)).repeatForever(), value: radarAnimation)
                    }

                    // Concentric Rings
                    ForEach(0..<4) { i in
                        Circle()
                            .stroke(ModernTheme.accentYellow.opacity(0.05), lineWidth: 1)
                            .frame(width: CGFloat(100 + (i * 100)), height: CGFloat(100 + (i * 100)))
                    }
                    
                    // Expanding Scan Rings
                    ForEach(0..<2) { i in
                        Circle()
                            .stroke(ModernTheme.accentYellow.opacity(0.15), lineWidth: 1)
                            .frame(width: radarAnimation ? 400 : 0, height: radarAnimation ? 400 : 0)
                            .opacity(radarAnimation ? 0 : 1)
                            .animation(
                                .easeOut(duration: 3)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 1.5),
                                value: radarAnimation
                            )
                    }
                    
                    // Rotating Beam
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [ModernTheme.accentYellow.opacity(0.4), .clear]),
                                center: .center
                            )
                        )
                        .frame(width: 400, height: 400)
                        .rotationEffect(.degrees(beamRotation))
                    
                    // Center Beacon
                    ZStack {
                        Circle()
                            .fill(ModernTheme.accentYellow.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .blur(radius: 10)
                        
                        Circle()
                            .stroke(
                                LinearGradient(colors: [ModernTheme.accentYellow, .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 30))
                            .foregroundColor(ModernTheme.accentYellow)
                            .symbolEffect(.variableColor.iterative.reversing, options: .repeat(.continuous))
                    }
                    
                    // Discovered Peers
                    ForEach(Array(multipeer.availablePeers.enumerated()), id: \.element) { index, peer in
                        RadarPeerItem(
                            peer: peer,
                            index: index,
                            beamRotation: beamRotation,
                            status: getPeerStatus(peer),
                            onTap: {
                                handlePeerTap(peer)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .onAppear { radarAnimation = true }
                
                Spacer()
                
                // MARK: - Bottom Status
                VStack(spacing: 12) {
                    if songs.isEmpty {
                        Text("SELECT SONGS FROM LIBRARY TO SHARE")
                            .font(.system(size: 10, weight: .black))
                            .kerning(2)
                            .foregroundColor(ModernTheme.lightGray.opacity(0.6))
                            .padding(.bottom, 4)
                    }
                    
                    Text(radarStatusText)
                        .font(.system(size: 14, weight: .black))
                        .kerning(4)
                        .foregroundColor(ModernTheme.accentYellow.opacity(0.6))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(ModernTheme.accentYellow.opacity(0.05))
                                .overlay(
                                    Capsule()
                                        .stroke(ModernTheme.accentYellow.opacity(0.15), lineWidth: 1)
                                )
                        )
                    
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text("\(multipeer.availablePeers.count) Active Devices Nearby")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Connect Request", isPresented: $multipeer.showingInvitationAlert) {
            Button("Decline", role: .cancel) { multipeer.declineInvitation() }
            Button("Accept") { multipeer.acceptInvitation() }
        } message: {
            Text("'\(multipeer.invitationSenderName)' wants to connect for device transfer.")
        }
        .onAppear {
            multipeer.startBrowsing()
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                beamRotation = 360
            }
        }
        .onDisappear {
            multipeer.stopBrowsing()
        }
    }
    
    // MARK: - Helper Logic
    
    private var radarStatusText: String {
        if multipeer.isReceiving {
            return "RECEIVING INCOMING FILE..."
        } else if multipeer.isSending {
            return "SENDING FILE..."
        } else if !multipeer.connectedPeers.isEmpty {
            return "READY TO BROADCAST"
        } else {
            return "SCANNING FOR LISTENERS..."
        }
    }
    
    private func getPeerStatus(_ peer: MCPeerID) -> PeerStatus {
        if multipeer.isSending && multipeer.connectedPeers.contains(peer) {
            return .sending
        }
        if multipeer.connectedPeers.contains(peer) {
            return .connected
        }
        if multipeer.connectingPeers.contains(peer) {
            return .connecting
        }
        return .available
    }
    
    private func handlePeerTap(_ peer: MCPeerID) {
        if multipeer.connectedPeers.contains(peer) {
            // Already connected, send songs if any
            if !songs.isEmpty {
                for song in songs {
                    multipeer.sendSong(song.url, to: peer)
                }
            }
        } else {
            // Not connected, invite first
            multipeer.invite(peer: peer)
        }
    }
}

enum PeerStatus {
    case available
    case connecting
    case connected
    case sending
}

struct RadarPeerItem: View {
    let peer: MCPeerID
    let index: Int
    let beamRotation: Double
    let status: PeerStatus
    let onTap: () -> Void
    
    @State private var isAnimating = false
    @State private var hasAppeared = false
    
    // Calculate if the beam is currently "hitting" this item
    private var isHit: Bool {
        let angle = Double(index) * (360.0 / 6.0) - 45
        let normalizedBeam = beamRotation.truncatingRemainder(dividingBy: 360)
        let diff = abs(normalizedBeam - angle)
        return diff < 20 || diff > 340
    }
    
    var body: some View {
        let angle = Double(index) * (360.0 / 6.0) - 45
        let distance: CGFloat = 130 + CGFloat(index % 2 * 60)
        
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(ModernTheme.accentYellow.opacity(status == .connected ? 1.0 : (isHit ? 0.8 : 0.2)), lineWidth: 2)
                        .frame(width: 74, height: 74)
                    
                    Circle()
                        .fill(ModernTheme.mediumGray)
                        .frame(width: 66, height: 66)
                        .overlay(
                            Group {
                                if status == .connected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(ModernTheme.accentYellow)
                                } else if status == .connecting {
                                    ProgressView()
                                        .tint(ModernTheme.accentYellow)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(ModernTheme.accentYellow.opacity(isHit ? 0.8 : 0.5))
                                }
                            }
                        )
                    
                    // Ping ring when beam hits or connected
                    Circle()
                        .stroke(ModernTheme.accentYellow.opacity(status == .connected ? 0.4 : 0.8), lineWidth: 2)
                        .frame(width: 74, height: 74)
                        .scaleEffect(status == .connected ? 1.1 : (isHit ? 1.4 : 1.0))
                        .opacity(status == .connected ? 0.5 : (isHit ? 0 : (isAnimating ? 0 : 0.5)))
                }
                .shadow(color: ModernTheme.accentYellow.opacity(status == .connected ? 0.6 : (isHit ? 0.4 : 0)), radius: 10)
                
                Text(peer.displayName.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .kerning(1)
                    .foregroundColor(status == .connected ? ModernTheme.accentYellow : (isHit ? ModernTheme.accentYellow : .white))
                    .scaleEffect(isHit || status == .connected ? 1.1 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(hasAppeared ? 1.0 : 0.0)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .offset(x: cos(angle * .pi / 180) * distance, y: sin(angle * .pi / 180) * distance)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1)) {
                hasAppeared = true
            }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHit)
    }
}

#Preview {
    NearbyShareView(songs: [])
}
