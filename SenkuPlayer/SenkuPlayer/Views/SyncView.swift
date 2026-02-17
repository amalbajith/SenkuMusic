//
//  SyncView.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import SwiftUI
import MultipeerConnectivity

struct SyncView: View {
    @StateObject private var multipeer = MultipeerManager.shared
    @State private var isBrowsing = false
    
    private var isSyncActive: Bool {
        multipeer.isSyncingCatalog || multipeer.isSending || multipeer.isReceiving
    }
    
    private var statusText: String {
        if !isBrowsing { return "Offline" }
        if !multipeer.syncDetails.isEmpty && isSyncActive {
            return multipeer.syncDetails
        }
        return multipeer.syncStatus
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header Status
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(isSyncActive ? ModernTheme.accentYellow.opacity(0.1) : (isBrowsing ? ModernTheme.backgroundSecondary : ModernTheme.backgroundSecondary.opacity(0.5)))
                                .frame(width: 160, height: 160)
                            
                            Circle()
                                .stroke(isSyncActive ? ModernTheme.accentYellow : (isBrowsing ? ModernTheme.borderSubtle : ModernTheme.borderSubtle.opacity(0.4)), lineWidth: 2)
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Circle()
                                        .trim(from: 0, to: isSyncActive ? 0.75 : 0)
                                        .stroke(ModernTheme.accentYellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                        .frame(width: 160, height: 160)
                                        .rotationEffect(.degrees(isSyncActive ? 360 : 0))
                                        .animation(isSyncActive ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default, value: isSyncActive)
                                )
                            
                            Image(systemName: !isBrowsing ? "wifi.slash" : (multipeer.isReceiving ? "arrow.down.circle" : (multipeer.isSending ? "arrow.up.circle" : (multipeer.isSyncingCatalog ? "clock.arrow.circlepath" : "arrow.triangle.2.circlepath"))))
                                .font(.system(size: 60))
                                .foregroundColor(isSyncActive ? ModernTheme.accentYellow : (isBrowsing ? ModernTheme.textTertiary : ModernTheme.textTertiary.opacity(0.5)))
                        }
                        .padding(.top, 40)
                        
                        Text(statusText)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(isBrowsing ? "Connect to a nearby device to sync your library." : "Tap Go Online to discover nearby devices.")
                            .font(.subheadline)
                            .foregroundColor(ModernTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if isBrowsing {
                        // Device List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NEARBY DEVICES")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(ModernTheme.textTertiary)
                                .padding(.leading, 8)
                            
                            if multipeer.availablePeers.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("Searching for devices...")
                                        .font(.subheadline)
                                        .foregroundColor(ModernTheme.textSecondary)
                                        .italic()
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else {
                                ForEach(multipeer.availablePeers, id: \.displayName) { peer in
                                    Button {
                                        multipeer.invite(peer: peer)
                                    } label: {
                                        HStack {
                                            Image(systemName: "laptopcomputer.and.iphone")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .frame(width: 40)
                                            
                                            VStack(alignment: .leading) {
                                                Text(peer.displayName)
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                Text("Ready to connect")
                                                    .font(.caption)
                                                    .foregroundColor(ModernTheme.success)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(ModernTheme.textTertiary)
                                        }
                                        .padding()
                                        .background(ModernTheme.backgroundSecondary)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, ModernTheme.screenPadding)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    Spacer()
                    
                    // Progress & Action
                    VStack(spacing: 20) {
                        if isSyncActive || multipeer.transferProgress > 0 {
                            VStack(spacing: 8) {
                                ProgressView(value: multipeer.transferProgress, total: 1.0)
                                    .tint(ModernTheme.accentYellow)
                                
                                HStack {
                                    Text("\(Int(multipeer.transferProgress * 100))%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(ModernTheme.accentYellow)
                                    Spacer()
                                    Text("Sent \(multipeer.sentFilesCount) • Received \(multipeer.receivedFilesCount)")
                                        .font(.caption)
                                        .foregroundColor(ModernTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, ModernTheme.screenPadding + 16)
                        }
                        
                        if isBrowsing {
                            // Start Sync button (only when online and connected)
                            Button {
                                startSync()
                            } label: {
                                Text(isSyncActive ? "Syncing..." : "Start Sync")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        isSyncActive
                                        ? LinearGradient(colors: [ModernTheme.mediumGray, ModernTheme.mediumGray], startPoint: .top, endPoint: .bottom)
                                        : ModernTheme.accentGradient
                                    )
                                    .cornerRadius(16)
                            }
                            .disabled(multipeer.connectedPeers.isEmpty || isSyncActive)
                            .opacity(multipeer.connectedPeers.isEmpty || isSyncActive ? 0.5 : 1)
                            .padding(.horizontal, ModernTheme.screenPadding + 16)
                            
                            // Go Offline button
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    goOffline()
                                }
                            } label: {
                                Text("Go Offline")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(ModernTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .padding(.horizontal, ModernTheme.screenPadding + 16)
                            .padding(.bottom, 10)
                        } else {
                            // Go Online button
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    goOnline()
                                }
                            } label: {
                                Text("Go Online")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ModernTheme.accentGradient)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal, ModernTheme.screenPadding + 16)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            #if os(iOS)
            .padding(.bottom, 100)
            #endif
            .navigationTitle("Sync")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onDisappear {
            if isBrowsing {
                goOffline()
            }
        }
    }
    
    private func goOnline() {
        isBrowsing = true
        multipeer.startBrowsing()
    }
    
    private func goOffline() {
        isBrowsing = false
        multipeer.stopBrowsing()
    }
    
    private func startSync() {
        guard !multipeer.connectedPeers.isEmpty else {
            multipeer.syncStatus = "No device connected"
            return
        }
        
        guard !isSyncActive else { return }
        multipeer.syncStatus = "Preparing smart sync..."
        multipeer.syncDetails = ""
        multipeer.sentFilesCount = 0
        multipeer.receivedFilesCount = 0
        multipeer.pendingFilesCount = 0
        multipeer.startSmartSync()
    }
}

#Preview {
    SyncView()
        .preferredColorScheme(.dark)
}
