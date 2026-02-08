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
    
    private var isSyncActive: Bool {
        multipeer.isSyncingCatalog || multipeer.isSending || multipeer.isReceiving
    }
    
    private var statusText: String {
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
                                .fill(isSyncActive ? ModernTheme.accentYellow.opacity(0.1) : ModernTheme.backgroundSecondary)
                                .frame(width: 160, height: 160)
                            
                            Circle()
                                .stroke(isSyncActive ? ModernTheme.accentYellow : ModernTheme.borderSubtle, lineWidth: 2)
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Circle()
                                        .trim(from: 0, to: isSyncActive ? 0.75 : 0)
                                        .stroke(ModernTheme.accentYellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                        .frame(width: 160, height: 160)
                                        .rotationEffect(.degrees(isSyncActive ? 360 : 0))
                                        .animation(isSyncActive ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default, value: isSyncActive)
                                )
                            
                            Image(systemName: multipeer.isReceiving ? "arrow.down.circle" : (multipeer.isSending ? "arrow.up.circle" : (multipeer.isSyncingCatalog ? "clock.arrow.circlepath" : "arrow.triangle.2.circlepath")))
                                .font(.system(size: 60))
                                .foregroundColor(isSyncActive ? ModernTheme.accentYellow : ModernTheme.textTertiary)
                        }
                        .padding(.top, 40)
                        
                        Text(statusText)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Connect to a nearby device to sync your library.")
                            .font(.subheadline)
                            .foregroundColor(ModernTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
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
                        .padding(.bottom, 30)
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
        .onAppear {
            multipeer.startBrowsing()
        }
        .onDisappear {
            multipeer.stopBrowsing()
        }
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
