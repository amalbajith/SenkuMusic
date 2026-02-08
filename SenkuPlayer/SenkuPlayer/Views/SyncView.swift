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
    @State private var isSyncing = false
    @State private var progress: Double = 0.0
    @State private var syncStatus = "Ready to Sync"
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header Status
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(isSyncing ? ModernTheme.accentYellow.opacity(0.1) : ModernTheme.backgroundSecondary)
                                .frame(width: 160, height: 160)
                            
                            Circle()
                                .stroke(isSyncing || multipeer.isReceiving || multipeer.isSending ? ModernTheme.accentYellow : ModernTheme.borderSubtle, lineWidth: 2)
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Circle()
                                        .trim(from: 0, to: isSyncing || multipeer.isReceiving || multipeer.isSending ? 0.75 : 0)
                                        .stroke(ModernTheme.accentYellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                        .frame(width: 160, height: 160)
                                        .rotationEffect(.degrees(isSyncing || multipeer.isReceiving || multipeer.isSending ? 360 : 0))
                                        .animation((isSyncing || multipeer.isReceiving || multipeer.isSending) ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default, value: isSyncing || multipeer.isReceiving || multipeer.isSending)
                                )
                            
                            Image(systemName: multipeer.isReceiving ? "arrow.down.circle" : (multipeer.isSending ? "arrow.up.circle" : "arrow.triangle.2.circlepath"))
                                .font(.system(size: 60))
                                .foregroundColor(isSyncing || multipeer.isReceiving || multipeer.isSending ? ModernTheme.accentYellow : ModernTheme.textTertiary)
                        }
                        .padding(.top, 40)
                        
                        Text((multipeer.isSending || multipeer.isReceiving) && !multipeer.syncDetails.isEmpty ? multipeer.syncDetails : syncStatus)
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
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Progress & Action
                    VStack(spacing: 20) {
                        if isSyncing {
                            VStack(spacing: 8) {
                                ProgressView(value: progress, total: 1.0)
                                    .tint(ModernTheme.accentYellow)
                                
                                HStack {
                                    Text("\(Int(progress * 100))%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(ModernTheme.accentYellow)
                                    Spacer()
                                    Text("Transferring Library...")
                                        .font(.caption)
                                        .foregroundColor(ModernTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        
                        Button {
                            startSync()
                        } label: {
                            Text(isSyncing ? "Cancel Sync" : "Start Sync")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    isSyncing 
                                    ? LinearGradient(colors: [ModernTheme.mediumGray, ModernTheme.mediumGray], startPoint: .top, endPoint: .bottom)
                                    : ModernTheme.accentGradient
                                )
                                .cornerRadius(16)
                        }
                        .disabled(multipeer.connectedPeers.isEmpty && !isSyncing) // Only disabled if NOT connected and NOT syncing.
                        .opacity(multipeer.connectedPeers.isEmpty && !isSyncing ? 0.5 : 1)
                        .padding(.horizontal, 40)
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
            syncStatus = "No device connected"
            return
        }
        
        // Prevent multiple syncs (UI protection)
        guard !isSyncing else { return }
        
        isSyncing = true
        syncStatus = "Proposing Smart Sync..."
        
        // Start Protocol
        multipeer.startSmartSync()
        
        // Reset button state after delay (actual transfer happens in background)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.isSyncing = false
                self.syncStatus = "Catalog Sent"
            }
        }
    }
}

#Preview {
    SyncView()
        .preferredColorScheme(.dark)
}
