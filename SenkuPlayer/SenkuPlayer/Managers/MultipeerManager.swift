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

    // Transfer tuning: 2-3 gives better throughput without overwhelming MCSession.
    private let maxConcurrentTransfers = 3

    private var sendProgressMap: [String: Progress] = [:]
    private var receiveProgressMap: [String: Progress] = [:]
    private var progressTimer: Timer?

    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedSongURL: URL?
    @Published var lastReceivedSongName: String?
    @Published var showReceivedNotification = false
    @Published var isReceiving = false
    @Published var isSending = false
    @Published var isSyncingCatalog = false
    @Published var syncStatus: String = "Ready to Sync"
    @Published var syncDetails: String = ""
    @Published var transferProgress: Double = 0
    @Published var sentFilesCount = 0
    @Published var receivedFilesCount = 0
    @Published var pendingFilesCount = 0

    private var activeTransferCount = 0 {
        didSet { isSending = activeTransferCount > 0 }
    }

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

    func startSmartSync() {
        Task {
            guard let peer = await MainActor.run(resultType: MCPeerID?.self, body: { self.connectedPeers.first }) else {
                await MainActor.run {
                    self.syncStatus = "No device connected"
                }
                return
            }

            let songs = await MainActor.run { MusicLibraryManager.shared.songs }
            let catalog = songs.map { Self.normalizedIdentity(for: $0) }
            let message = SyncMessage(kind: .catalog, items: catalog)

            guard let data = try? JSONEncoder().encode(message) else {
                await MainActor.run {
                    self.syncStatus = "Failed to encode catalog"
                }
                return
            }

            await MainActor.run {
                self.isSyncingCatalog = true
                self.syncStatus = "Sending catalog to \(peer.displayName)..."
                self.syncDetails = "Catalog: \(catalog.count) songs"
                self.transferProgress = 0
            }

            do {
                try self.session.send(data, toPeers: [peer], with: .reliable)
                await MainActor.run {
                    self.syncStatus = "Catalog sent. Waiting for delta..."
                }
            } catch {
                await MainActor.run {
                    self.isSyncingCatalog = false
                    self.syncStatus = "Failed to send catalog"
                    self.syncDetails = error.localizedDescription
                }
            }
        }
    }

    func sendSong(_ url: URL, to peer: MCPeerID) async throws {
        guard session.connectedPeers.contains(peer) else { return }

        let transferKey = "send-\(peer.displayName)-\(url.lastPathComponent)-\(UUID().uuidString)"

        await MainActor.run {
            self.activeTransferCount += 1
            self.syncDetails = "Sending: \(url.lastPathComponent.replacingOccurrences(of: ".mp3", with: ""))"
            self.startProgressMonitoringIfNeeded()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let progress = session.sendResource(at: url, withName: url.lastPathComponent, toPeer: peer) { error in
                Task { @MainActor in
                    self.activeTransferCount = max(0, self.activeTransferCount - 1)
                    self.pendingFilesCount = max(0, self.pendingFilesCount - 1)
                    self.sendProgressMap.removeValue(forKey: transferKey)
                    self.refreshTransferProgress()
                    self.stopProgressMonitoringIfIdle()

                    if error == nil {
                        self.sentFilesCount += 1
                    }

                    if self.pendingFilesCount == 0 && !self.isReceiving {
                        self.syncStatus = "Sync complete"
                        self.syncDetails = "Sent \(self.sentFilesCount), received \(self.receivedFilesCount)"
                    }
                }

                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }

            if let progress {
                Task { @MainActor in
                    self.sendProgressMap[transferKey] = progress
                    self.refreshTransferProgress()
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
    let album: String
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
    private static func normalizedIdentity(for song: Song) -> SongIdentity {
        SongIdentity(
            title: song.title.normalizedSyncKey,
            artist: song.artist.normalizedSyncKey,
            album: song.album.normalizedSyncKey
        )
    }

    private func sendSongs(_ songs: [Song], to peerID: MCPeerID) {
        guard !songs.isEmpty else {
            Task { @MainActor in
                if self.pendingFilesCount == 0 && !self.isReceiving {
                    self.syncStatus = "Sync up to date"
                    self.syncDetails = "No missing files"
                }
            }
            return
        }

        Task {
            await MainActor.run {
                self.pendingFilesCount += songs.count
                self.syncStatus = "Transferring \(songs.count) file\(songs.count == 1 ? "" : "s")..."
                self.syncDetails = "Sending to \(peerID.displayName)"
            }

            for batch in songs.chunked(into: self.maxConcurrentTransfers) {
                await withTaskGroup(of: Void.self) { group in
                    for song in batch {
                        group.addTask {
                            try? await self.sendSong(song.url, to: peerID)
                        }
                    }
                }
            }
        }
    }

    private func handleData(_ data: Data, from peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(SyncMessage.self, from: data) else { return }

        Task {
            let localSongs = await MainActor.run { MusicLibraryManager.shared.songs }
            let localByIdentity = Dictionary(
                localSongs.map { (Self.normalizedIdentity(for: $0), $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let localSet = Set(localByIdentity.keys)

            switch message.kind {
            case .catalog:
                let remoteSet = Set(message.items)

                let toSend = localByIdentity
                    .filter { !remoteSet.contains($0.key) }
                    .map { $0.value }

                let toRequest = Array(remoteSet.subtracting(localSet))

                await MainActor.run {
                    self.isSyncingCatalog = false
                    self.syncStatus = "Delta found: send \(toSend.count), request \(toRequest.count)"
                    self.syncDetails = "Optimizing transfer..."
                }

                // Ask for what this device is missing.
                if !toRequest.isEmpty {
                    let reqMsg = SyncMessage(kind: .request, items: toRequest)
                    if let reqData = try? JSONEncoder().encode(reqMsg) {
                        try? self.session.send(reqData, toPeers: [peerID], with: .reliable)
                    }
                }

                // Send what peer is missing using concurrent batches.
                sendSongs(toSend, to: peerID)

            case .request:
                let requestedSet = Set(message.items)
                let songsToSend = localByIdentity
                    .filter { requestedSet.contains($0.key) }
                    .map { $0.value }

                await MainActor.run {
                    self.isSyncingCatalog = false
                    self.syncStatus = "Peer requested \(songsToSend.count) file\(songsToSend.count == 1 ? "" : "s")"
                    self.syncDetails = "Preparing transfer..."
                }

                sendSongs(songsToSend, to: peerID)
            }
        }
    }

    @MainActor
    private func startProgressMonitoringIfNeeded() {
        guard progressTimer == nil else { return }

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshTransferProgress()
            }
        }
    }

    @MainActor
    private func stopProgressMonitoringIfIdle() {
        let hasActiveProgress = !sendProgressMap.isEmpty || !receiveProgressMap.isEmpty
        if !hasActiveProgress && activeTransferCount == 0 && !isReceiving {
            progressTimer?.invalidate()
            progressTimer = nil
            transferProgress = 0
        }
    }

    @MainActor
    private func refreshTransferProgress() {
        sendProgressMap = sendProgressMap.filter { !$0.value.isFinished && !$0.value.isCancelled }
        receiveProgressMap = receiveProgressMap.filter { !$0.value.isFinished && !$0.value.isCancelled }

        let active = Array(sendProgressMap.values) + Array(receiveProgressMap.values)
        guard !active.isEmpty else {
            transferProgress = 0
            return
        }

        let totalFraction = active.reduce(0.0) { $0 + $1.fractionCompleted }
        transferProgress = min(max(totalFraction / Double(active.count), 0), 1)
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectingPeers.removeAll { $0 == peerID }

            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.syncStatus = "Connected to \(peerID.displayName)"
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                self.syncStatus = "Disconnected"
            case .connecting:
                if !self.connectingPeers.contains(peerID) {
                    self.connectingPeers.append(peerID)
                }
                self.syncStatus = "Connecting to \(peerID.displayName)..."
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
            self.syncStatus = "Receiving files..."
            self.syncDetails = "Receiving: \(resourceName)"

            let key = "recv-\(peerID.displayName)-\(resourceName)"
            self.receiveProgressMap[key] = progress
            self.startProgressMonitoringIfNeeded()
            self.refreshTransferProgress()
        }
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        DispatchQueue.main.async {
            let key = "recv-\(peerID.displayName)-\(resourceName)"
            self.receiveProgressMap.removeValue(forKey: key)
            self.refreshTransferProgress()

            if self.receiveProgressMap.isEmpty {
                self.isReceiving = false
            }

            self.syncDetails = "Received: \(resourceName)"

            if let error = error {
                self.syncStatus = "Receive failed"
                self.syncDetails = error.localizedDescription
                self.stopProgressMonitoringIfIdle()
                return
            }

            guard let localURL = localURL else {
                self.syncStatus = "Receive failed"
                self.syncDetails = "File URL was missing"
                self.stopProgressMonitoringIfIdle()
                return
            }

            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let musicDirectory = documentsPath.appendingPathComponent("Music", isDirectory: true)

                if !FileManager.default.fileExists(atPath: musicDirectory.path) {
                    try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
                }

                // Path traversal protection.
                let sanitizedName = (resourceName as NSString).lastPathComponent
                let destinationURL = musicDirectory.appendingPathComponent(sanitizedName)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.moveItem(at: localURL, to: destinationURL)

                self.receivedSongURL = destinationURL
                self.lastReceivedSongName = sanitizedName.replacingOccurrences(of: ".mp3", with: "", options: .caseInsensitive)
                self.showReceivedNotification = true
                self.receivedFilesCount += 1

                Task {
                    await MusicLibraryManager.shared.addSongFromURL(destinationURL)
                }

                if self.pendingFilesCount == 0 && !self.isSending && !self.isReceiving {
                    self.syncStatus = "Sync complete"
                    self.syncDetails = "Sent \(self.sentFilesCount), received \(self.receivedFilesCount)"
                }

            } catch {
                self.syncStatus = "Import failed"
                self.syncDetails = error.localizedDescription
            }

            self.stopProgressMonitoringIfIdle()
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

private extension String {
    var normalizedSyncKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }

        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}
