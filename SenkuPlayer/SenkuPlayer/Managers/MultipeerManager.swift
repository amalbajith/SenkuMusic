//
//  MultipeerManager.swift
//  SenkuPlayer
//
//  Created by Amal on 30/12/25.
//

import Foundation
import MultipeerConnectivity
import Combine

class MultipeerManager: NSObject, ObservableObject {
    static let shared = MultipeerManager()
    
    private let serviceType = "senku-share"
    private var myPeerId: MCPeerID
    private var serviceAdvertiser: MCNearbyServiceAdvertiser
    private var serviceBrowser: MCNearbyServiceBrowser
    private var session: MCSession
    
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedSongURL: URL?
    @Published var lastReceivedSongName: String?
    @Published var showReceivedNotification = false
    @Published var isReceiving = false
    @Published var isSending = false
    private var activeTransferCount = 0 {
        didSet { isSending = activeTransferCount > 0 }
    }
    @Published var syncDetails: String = ""
    @Published var transferProgress: Double = 0
    
    // Track connecting peers
    @Published var connectingPeers: [MCPeerID] = []
    
    // Invitation Handling
    @Published var showingInvitationAlert = false
    @Published var invitationSenderName = ""
    private var invitationHandler: ((Bool, MCSession?) -> Void)?

    
    override init() {
        // Sanitize device name (remove special characters that can break discovery)
        let rawName = DeviceInfo.name
        let sanitizedName = rawName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: " ")
        myPeerId = MCPeerID(displayName: sanitizedName.isEmpty ? "Unknown Device" : sanitizedName)
        
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        
        super.init()
        
        session.delegate = self
        serviceAdvertiser.delegate = self
        serviceBrowser.delegate = self
    }
    
    func startBrowsing() {
        serviceBrowser.startBrowsingForPeers()
        serviceAdvertiser.startAdvertisingPeer()
    }
    
    func stopBrowsing() {
        serviceBrowser.stopBrowsingForPeers()
        serviceAdvertiser.stopAdvertisingPeer()
    }
    
    func invite(peer: MCPeerID) {
        serviceBrowser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    func sendSong(_ url: URL, to peer: MCPeerID) async throws {
        guard session.connectedPeers.contains(peer) else { return }
        
        await MainActor.run { 
            self.activeTransferCount += 1 
            self.syncDetails = "Sending: \(url.lastPathComponent.replacingOccurrences(of: ".mp3", with: ""))"
        }
        
        return await withCheckedContinuation { continuation in
            session.sendResource(at: url, withName: url.lastPathComponent, toPeer: peer) { error in
                Task { @MainActor in self.activeTransferCount -= 1 }
                if let error = error {
                    print("❌ Error sending file: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Invitation Response
    func acceptInvitation() {
        invitationHandler?(true, session)
        invitationHandler = nil
        showingInvitationAlert = false
    }
    
    func declineInvitation() {
        invitationHandler?(false, nil)
        invitationHandler = nil
        showingInvitationAlert = false
    }
}


// MARK: - Sync Models
struct SongIdentity: Codable, Hashable {
    let title: String
    let artist: String
}

struct SyncMessage: Codable {
    enum Kind: String, Codable {
        case catalog
        case request
    }
    let kind: Kind
    let items: [SongIdentity]
}

extension MultipeerManager {
    func startSmartSync() {
        Task { @MainActor in
            let songs = MusicLibraryManager.shared.songs
            let catalog = songs.map { SongIdentity(title: $0.title, artist: $0.artist) }
            let message = SyncMessage(kind: .catalog, items: catalog)
            
            if let data = try? JSONEncoder().encode(message),
               let peer = connectedPeers.first {
                try? session.send(data, toPeers: [peer], with: .reliable)
                print("🔄 Sent catalog with \(catalog.count) items to \(peer.displayName)")
            }
        }
    }
    
    private func handleData(_ data: Data, from peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(SyncMessage.self, from: data) else { return }
        
        Task { @MainActor in
            let localSongs = MusicLibraryManager.shared.songs
            
            switch message.kind {
            case .catalog:
                print("📥 Received catalog from \(peerID.displayName)")
                // Compare catalogs
                let remoteSet = Set(message.items)
                let localSet = Set(localSongs.map { SongIdentity(title: $0.title, artist: $0.artist) })
                
                // 1. Identify what Peer LACKS (I have, Peer doesn't) -> SEND
                let toSend = localSongs.filter {
                    !remoteSet.contains(SongIdentity(title: $0.title, artist: $0.artist))
                }
                
                // 2. Identify what I LACK (Peer has, I don't) -> REQUEST
                let toRequest = message.items.filter { !localSet.contains($0) }
                
                print("Calculated: Sending \(toSend.count), Requesting \(toRequest.count)")
                
                // Send Request
                if !toRequest.isEmpty {
                    let reqMsg = SyncMessage(kind: .request, items: toRequest)
                    if let reqData = try? JSONEncoder().encode(reqMsg) {
                        try? session.send(reqData, toPeers: [peerID], with: .reliable)
                    }
                }
                
                // Send Files (Async Task)
                Task.detached {
                    for song in toSend {
                        try? await self.sendSong(song.url, to: peerID)
                    }
                }
                
            case .request:
                print("📥 Received request for \(message.items.count) songs")
                // Peer wants these songs
                let requestedSet = Set(message.items)
                let songsToSend = localSongs.filter {
                    requestedSet.contains(SongIdentity(title: $0.title, artist: $0.artist))
                }
                
                Task.detached {
                    for song in songsToSend {
                        try? await self.sendSong(song.url, to: peerID)
                    }
                }
            }
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            // Remove from connecting list in all cases
            self.connectingPeers.removeAll { $0 == peerID }
            
            switch state {
            case .connected:
                print("🔗 Connected to \(peerID.displayName)")
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
            case .notConnected:
                print("🚫 Disconnected from \(peerID.displayName)")
                self.connectedPeers.removeAll { $0 == peerID }
            case .connecting:
                print("⏳ Connecting to \(peerID.displayName)...")
                if !self.connectingPeers.contains(peerID) {
                    self.connectingPeers.append(peerID)
                }
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handleData(data, from: peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle streams
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        DispatchQueue.main.async {
            self.isReceiving = true
            self.syncDetails = "Receiving: \(resourceName)"
            print("Started receiving: \(resourceName) from \(peerID.displayName)")
        }
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        DispatchQueue.main.async {
            self.isReceiving = false
            self.syncDetails = "Received: \(resourceName)"
            
            if let error = error {
                print("Error receiving file: \(error.localizedDescription)")
                return
            }
            
            guard let localURL = localURL else {
                print("Error: localURL is nil for \(resourceName)")
                return
            }
            
            print("File received at temp path: \(localURL.path)")
            
            // Move file to Documents/Music directory
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let musicDirectory = documentsPath.appendingPathComponent("Music", isDirectory: true)
                
                // Ensure Music directory exists
                if !FileManager.default.fileExists(atPath: musicDirectory.path) {
                    try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
                }
                
                // Sanitize the resource name to prevent path traversal attacks
                let sanitizedName = (resourceName as NSString).lastPathComponent
                let destinationURL = musicDirectory.appendingPathComponent(sanitizedName)
                
                // Remove existing file if needed
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                print("Moved file to: \(destinationURL.path)")
                
                self.receivedSongURL = destinationURL
                self.lastReceivedSongName = sanitizedName.replacingOccurrences(of: ".mp3", with: "", options: .caseInsensitive)
                self.showReceivedNotification = true
                
                // Import the new song
                Task {
                    await MusicLibraryManager.shared.addSongFromURL(destinationURL)
                }
                
            } catch {
                print("Error saving received file: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            self.invitationSenderName = peerID.displayName
            self.invitationHandler = invitationHandler
            self.showingInvitationAlert = true
        }
    }
}


// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.availablePeers.contains(peerID) {
                self.availablePeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            if let index = self.availablePeers.firstIndex(of: peerID) {
                self.availablePeers.remove(at: index)
            }
        }
    }
}
