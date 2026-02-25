import Foundation
import MultipeerConnectivity
import Combine

// MARK: - Models

struct P2PMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let senderName: String
    let timestamp: Date
    
    var formattedTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: timestamp)
    }
}

struct ConnectedPeer: Identifiable, Equatable {
    let id: MCPeerID
    var displayName: String { id.displayName }
}

enum SessionRole {
    case master, slave
}

// MARK: - Video Control Commands

enum VideoCommand: Codable, CustomStringConvertible {
    case play(position: Double)
    case pause(position: Double)
    case seekingStarted  // Master started seeking - pause slaves and show "seeking..."
    case seek(position: Double)
    case sync(position: Double, isPlaying: Bool)  // Periodic sync from master
    case loadVideo(videoName: String)  // Master broadcasts video name to load
    case requestVideoInfo  // Slave requests current video info from master
    case videoInfoResponse(videoName: String, position: Double, isPlaying: Bool)  // Master responds with video name, position, and play state
    
    var description: String {
        switch self {
        case .play(let pos): return "play(position: \(String(format: "%.1f", pos))s)"
        case .pause(let pos): return "pause(position: \(String(format: "%.1f", pos))s)"
        case .seekingStarted: return "seekingStarted"
        case .seek(let pos): return "seek(position: \(String(format: "%.1f", pos))s)"
        case .sync(let pos, let playing): return "sync(position: \(String(format: "%.1f", pos))s, isPlaying: \(playing))"
        case .loadVideo(let name): return "loadVideo(videoName: \(name))"
        case .requestVideoInfo: return "requestVideoInfo"
        case .videoInfoResponse(let name, let pos, let playing): return "videoInfoResponse(videoName: \(name), position: \(String(format: "%.1f", pos))s, isPlaying: \(playing))"
        }
    }
}

struct VideoCommandMessage: Codable {
    let command: VideoCommand
    let timestamp: Date
}

// MARK: - Video Sync Handler Protocol

protocol VideoSyncDelegate: AnyObject {
    func didReceiveVideoCommand(_ command: VideoCommand)
    func didReceiveLoadVideoCommand(videoName: String)
    func didReceiveVideoInfoResponse(videoName: String, position: Double, isPlaying: Bool)
}

// MARK: - MultipeerService

class MultipeerService: NSObject, ObservableObject {
    
    static let serviceType = "p2p-connect"
    
    // MARK: Published State
    @Published var connectedPeers: [ConnectedPeer] = []
    @Published var messages: [P2PMessage] = []
    @Published var isInRoom: Bool = false
    @Published var role: SessionRole = .slave
    @Published var statusMessage: String = ""
    @Published var browsingPeers: [MCPeerID] = []   // peers found but not yet connected
    
    // Video sync
    weak var videoDelegate: VideoSyncDelegate?
    var onVideoInfoRequest: ((MCPeerID) -> Void)?  // Callback for master to handle video info requests
    var onPeerConnected: ((MCPeerID) -> Void)?     // Callback when a peer connects (master: push video state to new slave)
    @Published var syncInterval: TimeInterval = 0.5  // Sync interval (shorter = smoother slave sync)
    @Published var commandLog: [String] = []  // For debugging - shows sent/received commands
    
    func addCommandLog(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.commandLog.append("[\(timestamp)] \(message)")
            if self.commandLog.count > 20 {
                self.commandLog.removeFirst()
            }
        }
    }
    
    // MARK: Private
    private let myPeerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    var myDisplayName: String { myPeerID.displayName }
    
    // MARK: Init
    override init() {
        let name = UIDevice.current.name
        self.myPeerID = MCPeerID(displayName: name)
        super.init()
        resetSession()
    }
    
    private func resetSession() {
        session?.disconnect()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }
    
    // MARK: - Master: Create Room
    func createRoom() {
        resetSession()
        role = .master
        isInRoom = true
        statusMessage = "Room open — waiting for peers…"
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }
    
    // MARK: - Slave: Browse
    func startBrowsing() {
        role = .slave
        browsingPeers = []
        statusMessage = "Scanning for rooms…"
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    // MARK: - Slave: Join specific peer
    func joinPeer(_ peer: MCPeerID) {
        isInRoom = true
        statusMessage = "Connecting to \(peer.displayName)…"
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }
    
    // MARK: - Leave Room / Stop
    func leaveRoom() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        
        DispatchQueue.main.async {
            self.connectedPeers = []
            self.messages = []
            self.browsingPeers = []
            self.isInRoom = false
            self.statusMessage = ""
        }
    }
    
    // MARK: - Send Message (Master only)
    func sendMessage(_ text: String) {
        guard role == .master, !connectedPeers.isEmpty else { return }
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            DispatchQueue.main.async {
                self.messages.append(P2PMessage(text: text, senderName: "You", timestamp: Date()))
            }
        } catch {
            print("Send error: \(error)")
        }
    }
    
    // MARK: - Video Commands (Master only)
    
    func sendVideoCommand(_ command: VideoCommand) {
        guard role == .master, !connectedPeers.isEmpty else {
            print("⚠️ Cannot send command: role=\(role), peers=\(connectedPeers.count)")
            addCommandLog("❌ Cannot send: role=\(role), peers=\(connectedPeers.count)")
            return
        }
        
        let message = VideoCommandMessage(command: command, timestamp: Date())
        guard let data = try? JSONEncoder().encode(message) else {
            addCommandLog("❌ Failed to encode command")
            return
        }
        
        // Prepend a marker to distinguish video commands from text messages
        var commandData = Data([0xFF]) // Marker byte
        commandData.append(data)
        
        print("📤 Attempting to send: \(commandData.count) bytes")
        print("   First byte (marker): \(commandData.first ?? 0)")
        print("   Session.connectedPeers: \(session.connectedPeers)")
        
        do {
            try session.send(commandData, toPeers: session.connectedPeers, with: .reliable)
            print("✅ Sent video command: \(command) to \(session.connectedPeers.count) peer(s)")
            addCommandLog("📤 SENT: \(command)")
        } catch {
            print("❌ Video command send error: \(error)")
            addCommandLog("❌ Send failed: \(error.localizedDescription)")
        }
    }
    
    func sendPlayCommand(position: Double) {
        sendVideoCommand(.play(position: position))
    }
    
    func sendPauseCommand(position: Double) {
        sendVideoCommand(.pause(position: position))
    }
    
    func sendSeekingStartedCommand() {
        sendVideoCommand(.seekingStarted)
    }
    
    func sendSeekCommand(to position: Double) {
        sendVideoCommand(.seek(position: position))
    }
    
    func sendSyncCommand(position: Double, isPlaying: Bool) {
        sendVideoCommand(.sync(position: position, isPlaying: isPlaying))
    }
    
    func sendLoadVideoCommand(videoName: String) {
        sendVideoCommand(.loadVideo(videoName: videoName))
    }
    
    func sendRequestVideoInfoCommand() {
        guard role == .slave, !connectedPeers.isEmpty else {
            print("⚠️ Cannot request video info: role=\(role), peers=\(connectedPeers.count)")
            return
        }
        
        // Send request to master (first connected peer)
        guard let masterPeer = connectedPeers.first?.id else { return }
        
        let message = VideoCommandMessage(command: .requestVideoInfo, timestamp: Date())
        guard let data = try? JSONEncoder().encode(message) else {
            print("❌ Failed to encode video info request")
            return
        }
        
        var commandData = Data([0xFF]) // Marker byte
        commandData.append(data)
        
        do {
            try session.send(commandData, toPeers: [masterPeer], with: .reliable)
            print("✅ Sent video info request to master")
            addCommandLog("📤 REQUEST: video info")
        } catch {
            print("❌ Failed to send video info request: \(error)")
            addCommandLog("❌ Request failed: \(error.localizedDescription)")
        }
    }
    
    func sendVideoInfoResponse(videoName: String, position: Double, isPlaying: Bool) {
        guard role == .master, !connectedPeers.isEmpty else { return }
        
        let message = VideoCommandMessage(command: .videoInfoResponse(videoName: videoName, position: position, isPlaying: isPlaying), timestamp: Date())
        guard let data = try? JSONEncoder().encode(message) else {
            print("❌ Failed to encode video info response")
            return
        }
        
        var commandData = Data([0xFF]) // Marker byte
        commandData.append(data)
        
        do {
            try session.send(commandData, toPeers: session.connectedPeers, with: .reliable)
            print("✅ Sent video info response: \(videoName) at \(position)s, isPlaying: \(isPlaying)")
            addCommandLog("📤 RESPONSE: video info (\(videoName), \(String(format: "%.1f", position))s, \(isPlaying ? "play" : "pause"))")
        } catch {
            print("❌ Failed to send video info response: \(error)")
            addCommandLog("❌ Response failed: \(error.localizedDescription)")
        }
    }
    
    /// Send current video state to a single peer (e.g. when that peer just connected).
    func sendVideoInfoResponse(videoName: String, position: Double, isPlaying: Bool, toPeer peerID: MCPeerID) {
        guard role == .master else { return }
        
        let message = VideoCommandMessage(command: .videoInfoResponse(videoName: videoName, position: position, isPlaying: isPlaying), timestamp: Date())
        guard let data = try? JSONEncoder().encode(message) else { return }
        
        var commandData = Data([0xFF])
        commandData.append(data)
        
        do {
            try session.send(commandData, toPeers: [peerID], with: .reliable)
            print("✅ Pushed video info to new peer \(peerID.displayName): \(videoName) at \(String(format: "%.1f", position))s, \(isPlaying ? "play" : "pause")")
            addCommandLog("📤 PUSH to \(peerID.displayName): video info")
        } catch {
            print("❌ Failed to push video info to peer: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerService: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(where: { $0.id == peerID }) {
                    self.connectedPeers.append(ConnectedPeer(id: peerID))
                    // Master: push current video state to newly connected slave for immediate sync
                    if self.role == .master {
                        self.onPeerConnected?(peerID)
                    }
                }
                self.statusMessage = "\(peerID.displayName) connected"
                if self.role == .slave { self.isInRoom = true }
                
            case .notConnected:
                self.connectedPeers.removeAll { $0.id == peerID }
                self.statusMessage = "\(peerID.displayName) disconnected"
                if self.role == .slave && self.connectedPeers.isEmpty {
                    self.isInRoom = false
                }
                
            case .connecting:
                self.statusMessage = "Connecting to \(peerID.displayName)…"
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("📥 Received \(data.count) bytes from \(peerID.displayName)")
        print("   First byte: 0x\(String(format: "%02X", data.first ?? 0))")
        
        // Check if this is a video command (marked with 0xFF prefix)
        if data.first == 0xFF, data.count > 1 {
            print("   ✅ Detected video command marker (0xFF)")
            let commandData = data.dropFirst()
            print("   Command data size: \(commandData.count) bytes")
            
            do {
                let message = try JSONDecoder().decode(VideoCommandMessage.self, from: commandData)
                print("📥 Received video command: \(message.command) from \(peerID.displayName)")
                addCommandLog("📥 RECEIVED: \(message.command)")
                
                DispatchQueue.main.async {
                    // Handle requestVideoInfo on master side
                    if case .requestVideoInfo = message.command {
                        if self.role == .master {
                            print("✅ Received video info request from \(peerID.displayName)")
                            self.onVideoInfoRequest?(peerID)
                        }
                        return
                    }
                    
                    // Handle videoInfoResponse on slave side
                    if case .videoInfoResponse(let videoName, let position, let isPlaying) = message.command {
                        if self.role == .slave {
                            print("✅ Received video info response: \(videoName) at \(position)s, isPlaying: \(isPlaying)")
                            self.videoDelegate?.didReceiveVideoInfoResponse(videoName: videoName, position: position, isPlaying: isPlaying)
                        }
                        return
                    }
                    
                    if self.videoDelegate == nil {
                        print("⚠️ Warning: videoDelegate is nil!")
                        self.addCommandLog("⚠️ Delegate is nil!")
                    } else {
                        // Handle loadVideo command separately
                        if case .loadVideo(let videoName) = message.command {
                            print("✅ Calling videoDelegate.didReceiveLoadVideoCommand")
                            self.videoDelegate?.didReceiveLoadVideoCommand(videoName: videoName)
                        } else {
                            print("✅ Calling videoDelegate.didReceiveVideoCommand")
                            self.videoDelegate?.didReceiveVideoCommand(message.command)
                        }
                    }
                }
            } catch {
                print("❌ Failed to decode video command: \(error)")
                addCommandLog("❌ Decode failed: \(error.localizedDescription)")
            }
            return
        }
        
        // Otherwise, treat as text message
        print("   → Treating as text message (no 0xFF marker)")
        guard let text = String(data: data, encoding: .utf8) else {
            print("   ❌ Failed to decode as UTF-8 string")
            return
        }
        DispatchQueue.main.async {
            self.messages.append(P2PMessage(text: text, senderName: peerID.displayName, timestamp: Date()))
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Master auto-accepts all invitations
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.browsingPeers.contains(peerID) {
                self.browsingPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.browsingPeers.removeAll { $0 == peerID }
        }
    }
}
