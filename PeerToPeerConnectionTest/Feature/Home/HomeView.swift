//
//  HomeView.swift
//  PeerToPeerConnectionTest
//
//  Redesigned with Core design system: AppColors, AppFonts, AppSpacing, AppText, AppComponents.
//

internal import SwiftUI
import MultipeerConnectivity

struct HomeView: View {
    @EnvironmentObject var service: MultipeerService
    @State private var showBrowse = false
    @State private var pulsing = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            GridPattern()
                .ignoresSafeArea()
                .opacity(AppLayout.gridPatternOpacity)

            VStack(spacing: 0) {
                header
                    .padding(.top, AppLayout.safeAreaTopContent)
                    .padding(.horizontal, AppSpacing.xxxl)

                Spacer()
                identityCard
                Spacer()

                instructionText
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)

                actions
                    .padding(.horizontal, AppSpacing.xxxl)
                    .padding(.bottom, AppLayout.safeAreaBottomContent)
            }
        }
        .sheet(isPresented: $showBrowse) {
            BrowseView()
                .environmentObject(service)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                    .shadow(color: AppColors.accent.opacity(0.8), radius: AppSpacing.xs)

                Text(AppText.Home.badgeP2P)
                    .font(.app.smallSemibold)
                    .foregroundColor(AppColors.accent)
                    .tracking(3)

                Spacer()

                Text(AppText.Home.badgeWifi)
                    .font(.app.label)
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(2)
            }

            Text(AppText.Home.title)
                .font(.app.titleLarge)
                .foregroundColor(AppColors.text)
                .lineSpacing(AppSpacing.xs)
        }
    }

    // MARK: Identity Card

    private var identityCard: some View {
        VStack(spacing: AppSpacing.xxl) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(AppColors.accent.opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                        .frame(width: CGFloat(120 + i * 52), height: CGFloat(120 + i * 52))
                        .scaleEffect(pulsing ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: pulsing)
                }

                ZStack {
                    Circle()
                        .fill(AppColors.surface)
                        .frame(width: 96, height: 96)
                        .overlay(Circle().stroke(AppColors.border, lineWidth: 1))

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.app.iconXLarge)
                        .foregroundColor(AppColors.accent)
                }
            }
            .frame(height: 240)
            .onAppear { pulsing = true }

            VStack(spacing: AppSpacing.xs) {
                Text(AppText.Home.thisDevice)
                    .font(.app.labelSmall)
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(3)
                Text(service.myDisplayName)
                    .font(.app.title)
                    .foregroundColor(AppColors.text)
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
            .background(AppColors.surface)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(AppColors.border, lineWidth: 1))
            .cornerRadius(AppRadius.md)
        }
    }

    // MARK: Instruction

    private var instructionText: some View {
        Text(AppText.Home.videoSyncInstruction)
            .font(.app.small)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: AppSpacing.md) {
            ActionCard(
                icon: "plus.circle.fill",
                title: AppText.Home.createRoom,
                subtitle: AppText.Home.createRoomSubtitle,
                accentBorder: true
            ) {
                service.createRoom()
            }

            ActionCard(
                icon: "arrow.right.circle.fill",
                iconColor: AppColors.warning,
                title: AppText.Home.joinRoom,
                subtitle: AppText.Home.joinRoomSubtitle,
                accentBorder: false
            ) {
                service.startBrowsing()
                showBrowse = true
            }
        }
    }
}

// MARK: - BrowseView

struct BrowseView: View {
    @EnvironmentObject var service: MultipeerService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(AppColors.border)
                    .frame(width: 36, height: 4)
                    .padding(.top, AppSpacing.md)

                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(AppText.Browse.scan)
                            .font(.app.label)
                            .foregroundColor(AppColors.accent)
                            .tracking(4)
                        Text(AppText.Browse.availableRooms)
                            .font(.app.titleLarge)
                            .foregroundColor(AppColors.text)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: AppLayout.minTapTarget, height: AppLayout.minTapTarget)
                            .background(AppColors.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)

                if service.browsingPeers.isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        ScanningIndicator()
                        Text(AppText.Browse.searching)
                            .font(.app.body)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(service.browsingPeers, id: \.self) { peer in
                                PeerRow(peer: peer) {
                                    service.joinPeer(peer)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.xxl)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - PeerRow

struct PeerRow: View {
    let peer: MCPeerID
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.surface)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(AppColors.border))
                Image(systemName: "iphone")
                    .foregroundColor(AppColors.warning)
                    .font(.app.iconSmall)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(peer.displayName)
                    .font(.app.bodySemibold)
                    .foregroundColor(AppColors.text)
                Text(AppText.Browse.masterReady)
                    .font(.app.small)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Button(action: onJoin) {
                Text(AppText.General.join)
                    .font(.app.smallSemibold)
                    .tracking(2)
                    .foregroundColor(AppColors.background)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accent)
                    .cornerRadius(AppRadius.sm)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.lg)
        .appCardStyle(isSelected: false)
    }
}

// MARK: - ScanningIndicator

struct ScanningIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.border, lineWidth: 2)
                .frame(width: 60, height: 60)

            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
                .onAppear { rotation = 360 }
        }
    }
}

// MARK: - GridPattern

struct GridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing = AppLayout.gridSpacing
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
