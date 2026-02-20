internal import SwiftUI
import MultipeerConnectivity

// MARK: - Design Tokens
struct AppTheme {
    static let bg        = Color(hex: "#0A0C10")
    static let surface   = Color(hex: "#141720")
    static let border    = Color(hex: "#252A35")
    static let accent    = Color(hex: "#4FFFB0")       // electric mint
    static let accentDim = Color(hex: "#1A5C3E")
    static let text      = Color(hex: "#E8EAF0")
    static let textDim   = Color(hex: "#5A6070")
    static let danger    = Color(hex: "#FF4D6A")
    static let warning   = Color(hex: "#FFB547")
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var service: MultipeerService
    @State private var showBrowse = false
    @State private var pulsing = false
    
    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            
            // Grid background pattern
            GridPattern()
                .ignoresSafeArea()
                .opacity(0.06)
            
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 60)
                    .padding(.horizontal, 28)
                
                Spacer()
                
                // Radar / identity card
                identityCard
                
                Spacer()
                
                // Action buttons
                actions
                    .padding(.horizontal, 28)
                    .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showBrowse) {
            BrowseView()
                .environmentObject(service)
        }
    }
    
    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Status dot
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: AppTheme.accent.opacity(0.8), radius: 4)
                Text("P2P CONNECT")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppTheme.accent)
                    .tracking(3)
                Spacer()
                Text("LOCAL WIFI")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textDim)
                    .tracking(2)
            }
            
            Text("Device\nNetwork")
                .font(.system(size: 42, weight: .black))
                .foregroundColor(AppTheme.text)
                .lineSpacing(2)
        }
    }
    
    // MARK: Identity Card
    private var identityCard: some View {
        VStack(spacing: 24) {
            // Radar rings
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                        .frame(width: CGFloat(120 + i * 52), height: CGFloat(120 + i * 52))
                        .scaleEffect(pulsing ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: pulsing)
                }
                
                // Center node
                ZStack {
                    Circle()
                        .fill(AppTheme.surface)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                    
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .frame(height: 240)
            .onAppear { pulsing = true }
            
            // Device name tag
            VStack(spacing: 4) {
                Text("THIS DEVICE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textDim)
                    .tracking(3)
                Text(service.myDisplayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.text)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            .cornerRadius(8)
        }
    }
    
    // MARK: Actions
    private var actions: some View {
        VStack(spacing: 12) {
            // Create Room — Master
            Button(action: { service.createRoom() }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.accentDim)
                            .frame(width: 36, height: 36)
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.accent)
                            .font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create Room")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.text)
                        Text("Become the master device")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textDim)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(16)
                .background(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            
            // Join Room — Slave
            Button(action: {
                service.startBrowsing()
                showBrowse = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#1A2030"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(AppTheme.warning)
                            .font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Join Room")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.text)
                        Text("Connect to a master device")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textDim)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(16)
                .background(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - BrowseView (Slave scans for rooms)

struct BrowseView: View {
    @EnvironmentObject var service: MultipeerService
    @Environment(\.dismiss) var dismiss
    @State private var scanning = true
    
    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(AppTheme.border)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Title
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SCAN")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppTheme.accent)
                            .tracking(4)
                        Text("Available Rooms")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.text)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textDim)
                            .padding(10)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Peer List
                if service.browsingPeers.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ScanningIndicator()
                        Text("Searching for rooms…")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppTheme.textDim)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(service.browsingPeers, id: \.self) { peer in
                                PeerRow(peer: peer) {
                                    service.joinPeer(peer)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

struct PeerRow: View {
    let peer: MCPeerID
    let onJoin: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(AppTheme.border))
                Image(systemName: "iphone")
                    .foregroundColor(AppTheme.warning)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(peer.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.text)
                Text("Master Device · Ready")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textDim)
            }
            Spacer()
            Button(action: onJoin) {
                Text("JOIN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(AppTheme.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent)
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
        .cornerRadius(12)
    }
}

// MARK: - Scanning Indicator

struct ScanningIndicator: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.border, lineWidth: 2)
                .frame(width: 60, height: 60)
            
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
                .onAppear { rotation = 360 }
        }
    }
}

// MARK: - Grid Pattern

struct GridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(.white), lineWidth: 0.5)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8)  / 255
        let b = Double(hexNumber & 0x0000ff)          / 255
        self.init(red: r, green: g, blue: b)
    }
}
