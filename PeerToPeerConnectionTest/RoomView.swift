internal import SwiftUI
internal import AVFoundation

// MARK: - RoomView

struct RoomView: View {
    @EnvironmentObject var service: MultipeerService
    @StateObject private var videoPlayer = SyncedVideoPlayer(videoFileName: "sample.mp4")
    @State private var selectedTab: RoomTab = .video
    
    enum RoomTab { case video, devices, messages }
    
    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            GridPattern().ignoresSafeArea().opacity(0.05)
            
            VStack(spacing: 0) {
                roomHeader
                tabBar
                
                switch selectedTab {
                case .video:    VideoRoomView(videoPlayer: videoPlayer)
                case .devices:  DevicesTab()
                case .messages: MessagesTab()
                }
            }
        }
        .environmentObject(service)
        .onAppear {
            // Set up video sync delegate
            print("🔧 Setting up video sync:")
            print("   Video player: \(videoPlayer)")
            print("   Service: \(service)")
            print("   Service role: \(service.role)")
            
            videoPlayer.service = service
            service.videoDelegate = videoPlayer
            
            print("   ✅ Delegate set: \(service.videoDelegate != nil)")
        }
        .onDisappear {
            print("🔧 Cleaning up video sync")
            videoPlayer.player.pause()
            service.videoDelegate = nil
        }
    }
    
    // MARK: Header
    private var roomHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // Role badge
                    Text(service.role == .master ? "MASTER" : "SLAVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(service.role == .master ? AppTheme.bg : AppTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(service.role == .master ? AppTheme.accent : AppTheme.warning.opacity(0.15))
                        .overlay(
                            Capsule().stroke(service.role == .master ? Color.clear : AppTheme.warning.opacity(0.4))
                        )
                        .clipShape(Capsule())
                    
                    // Connected count
                    HStack(spacing: 4) {
                        Circle()
                            .fill(service.connectedPeers.isEmpty ? AppTheme.textDim : AppTheme.accent)
                            .frame(width: 6, height: 6)
                        Text("\(service.connectedPeers.count) connected")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppTheme.textDim)
                    }
                }
                Text("Room Active")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.text)
            }
            
            Spacer()
            
            Button(action: { service.leaveRoom() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Leave")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppTheme.danger)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.danger.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.danger.opacity(0.3)))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }
    
    // MARK: Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([RoomTab.video, RoomTab.devices, RoomTab.messages], id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: iconForTab(tab))
                                .font(.system(size: 13))
                            Text(labelForTab(tab))
                                .font(.system(size: 14, weight: .semibold))
                            
                            if tab == .messages && !service.messages.isEmpty {
                                Text("\(service.messages.count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.bg)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selectedTab == tab ? AppTheme.accent : AppTheme.textDim)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? AppTheme.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .background(AppTheme.bg)
        .overlay(Divider().background(AppTheme.border), alignment: .bottom)
    }
    
    private func iconForTab(_ tab: RoomTab) -> String {
        switch tab {
        case .video: return "play.rectangle.fill"
        case .devices: return "network"
        case .messages: return "bubble.left.fill"
        }
    }
    
    private func labelForTab(_ tab: RoomTab) -> String {
        switch tab {
        case .video: return "Video"
        case .devices: return "Devices"
        case .messages: return "Messages"
        }
    }
}

// MARK: - Devices Tab

struct DevicesTab: View {
    @EnvironmentObject var service: MultipeerService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Status card
                statusCard
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                if service.connectedPeers.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(service.connectedPeers) { peer in
                            DeviceRow(peer: peer)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
    }
    
    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accentDim)
                    .frame(width: 48, height: 48)
                Image(systemName: service.role == .master ? "crown.fill" : "iphone")
                    .foregroundColor(AppTheme.accent)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(service.myDisplayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                Text(service.statusMessage.isEmpty ? (service.role == .master ? "Broadcasting room" : "Listening for messages") : service.statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textDim)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.accent.opacity(0.25)))
        .cornerRadius(12)
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 60)
            Image(systemName: "wifi.slash")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppTheme.textDim)
            Text(service.role == .master ? "Waiting for devices to join…" : "Not connected to any master")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textDim)
        }
    }
}

struct DeviceRow: View {
    let peer: ConnectedPeer
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(AppTheme.border))
                Image(systemName: "iphone")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.warning)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(peer.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 6, height: 6)
                    Text("Connected")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textDim)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.accent)
                .font(.system(size: 18))
        }
        .padding(14)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
        .cornerRadius(12)
    }
}

// MARK: - Messages Tab

struct MessagesTab: View {
    @EnvironmentObject var service: MultipeerService
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if service.messages.isEmpty {
                            emptyMessages
                                .id("top")
                        } else {
                            ForEach(service.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .onChange(of: service.messages.count) { _ in
                    if let last = service.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Input bar (master only)
            if service.role == .master {
                inputBar
            } else {
                slaveHint
            }
        }
    }
    
    private var emptyMessages: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppTheme.textDim)
            Text(service.role == .master ? "Send a message to all connected devices" : "Waiting for messages from master…")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Broadcast to all devices…", text: $messageText)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
                .cornerRadius(10)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.textDim : AppTheme.bg)
                    .frame(width: 44, height: 44)
                    .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.surface : AppTheme.accent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.border : Color.clear)
                    )
                    .cornerRadius(10)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.bg)
        .overlay(Divider().background(AppTheme.border), alignment: .top)
    }
    
    private var slaveHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textDim)
            Text("Slave devices receive only — master controls broadcast")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textDim)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .overlay(Divider().background(AppTheme.border), alignment: .top)
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        service.sendMessage(text)
        messageText = ""
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: P2PMessage
    
    var isOwn: Bool { message.senderName == "You" }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwn { Spacer(minLength: 60) }
            
            if !isOwn {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.surface)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(AppTheme.border))
                    Text(String(message.senderName.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.warning)
                }
            }
            
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                if !isOwn {
                    Text(message.senderName)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.textDim)
                        .tracking(1)
                }
                
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(isOwn ? AppTheme.bg : AppTheme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isOwn ? AppTheme.accent : AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isOwn ? Color.clear : AppTheme.border)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                Text(message.formattedTime)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppTheme.textDim)
            }
            
            if !isOwn { Spacer(minLength: 60) }
        }
    }
}


