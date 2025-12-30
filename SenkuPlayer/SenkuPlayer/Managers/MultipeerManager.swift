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
    @Published var isReceiving = false
    @Published var transferProgress: Double = 0
    
    override init() {
        let deviceName = UIDevice.current.name
        myPeerId = MCPeerID(displayName: deviceName)
        
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
    
    func sendSong(_ url: URL, to peer: MCPeerID) {
        guard session.connectedPeers.contains(peer) else { return }
        
        session.sendResource(at: url, withName: url.lastPathComponent, toPeer: peer) { error in
            if let error = error {
                print("Error sending file: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
            case .notConnected:
                if let index = self.connectedPeers.firstIndex(of: peerID) {
                    self.connectedPeers.remove(at: index)
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle small data packets if needed
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle streams
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        DispatchQueue.main.async {
            self.isReceiving = true
            print("Started receiving: \(resourceName) from \(peerID.displayName)")
        }
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        DispatchQueue.main.async {
            self.isReceiving = false
            
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
                
                let destinationURL = musicDirectory.appendingPathComponent(resourceName)
                
                // Remove existing file if needed
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                print("Moved file to: \(destinationURL.path)")
                
                self.receivedSongURL = destinationURL
                
                // Refresh library
                MusicLibraryManager.shared.loadMusicFiles()
                
            } catch {
                print("Error saving received file: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Always accept invitations for now
        invitationHandler(true, session)
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
