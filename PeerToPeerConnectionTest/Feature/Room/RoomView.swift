internal import SwiftUI
internal import AVFoundation

// MARK: - RoomView

struct RoomView: View {
    @EnvironmentObject var service: MultipeerService
    @EnvironmentObject var videoStore: VideoStore
    @StateObject private var videoPlayer = VideoPlayerVM()
    @StateObject private var playlistVm = PlayListVm()
    @State private var selectedTab: RoomTab = .video
    @State private var selectedVideo: VideoItem? = nil
    @State private var activePlaylist: PlaylistModelData? = nil
    @State private var playlistIndex: Int = 0
    @State private var showVideoSelectionSheet = false
    @State private var showPlaylistQueue = false
    @State private var shouldAutoPlayAfterAdvance = false
    @State private var showVideoLoadError = false
    @State private var videoLoadErrorMessage = ""
    @State private var videoDelegateWrapper: VideoSyncDelegateWrapper?
    @State private var slavePlaylistInfo: PlaylistInfo? = nil
    
    enum RoomTab { case video, devices }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                GridPattern().ignoresSafeArea().opacity(AppLayout.gridPatternOpacity * 0.8)
                
                VStack(spacing: 0) {
                    roomHeader
                    tabBar
                    
                    switch selectedTab {
                    case .video:    VideoRoomView(
                        videoPlayer: videoPlayer,
                        currentPlaylistInfo: currentPlaylistInfo,
                        onShowPlaylistQueue: currentPlaylistInfo != nil ? { showPlaylistQueue = true } : nil
                    )
                    case .devices:  DevicesTab()
                    }
                }
            }
            .environmentObject(service)
            .toolbar {
                if service.role == .master {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showVideoSelectionSheet = true }) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "film.stack")
                                Text(AppText.Room.selectVideo)
                                    .font(.app.bodySemibold)
                            }
                            .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Set up video sync delegate
            print("🔧 Setting up video sync:")
            print("   Video player: \(videoPlayer)")
            print("   Service: \(service)")
            print("   Service role: \(service.role)")
            
            videoPlayer.service = service
            // Create and store the delegate wrapper to prevent deallocation
            let wrapper = VideoSyncDelegateWrapper(
                player: videoPlayer,
                videoStore: videoStore,
                onLoadVideo: { _ in }
            )
            
            // Set up callbacks for video loading
            wrapper.onVideoLoaded = { videoItem, url in
                videoPlayer.loadVideo(url: url, videoName: videoItem.name)
                selectedVideo = videoItem
                print("✅ Video loaded on slave: \(videoItem.name)")
            }
            
            wrapper.onError = { errorMessage in
                videoLoadErrorMessage = errorMessage
                showVideoLoadError = true
            }
            
            wrapper.onPlaylistInfoReceived = { info in
                DispatchQueue.main.async {
                    self.slavePlaylistInfo = info
                }
            }
            
            videoDelegateWrapper = wrapper
            service.videoDelegate = wrapper
            
            // Set up callback for video info requests (master only)
            service.onVideoInfoRequest = { peerID in
                if self.service.role == .master {
                    let videoName = self.selectedVideo?.name ?? ""
                    let position = self.videoPlayer.currentTime
                    let isPlaying = self.videoPlayer.isPlaying
                    if !videoName.isEmpty {
                        self.service.sendVideoInfoResponse(videoName: videoName, position: position, isPlaying: isPlaying, playlistInfo: self.makePlaylistInfo(), isFullScreen: self.videoPlayer.isFullScreen)
                        print("✅ Responded to video info request: \(videoName) at \(position)s, isPlaying: \(isPlaying)")
                    } else {
                        print("⚠️ No video selected, cannot respond to video info request")
                    }
                }
            }
            
            // When a new peer connects to master, push current video state so slave syncs immediately
            service.onPeerConnected = { peerID in
                if self.service.role == .master, let videoName = self.selectedVideo?.name, !videoName.isEmpty {
                    let position = self.videoPlayer.currentTime
                    let isPlaying = self.videoPlayer.isPlaying
                    self.service.sendVideoInfoResponse(videoName: videoName, position: position, isPlaying: isPlaying, playlistInfo: self.makePlaylistInfo(), isFullScreen: self.videoPlayer.isFullScreen, toPeer: peerID)
                }
            }
            
            print("   ✅ Delegate set: \(service.videoDelegate != nil)")
            
            // If slave is already connected (e.g. re-entered room or tab), request current video state
            if service.role == .slave, !service.connectedPeers.isEmpty {
                service.sendRequestVideoInfoCommand()
            }
        }
        .onChange(of: videoPlayer.isReady) { oldValue, newValue in
            // When video becomes ready, broadcast to slaves (master only)
            // Only broadcast if we have a selected video and peers are connected
            if newValue, service.role == .master, let videoName = selectedVideo?.name, !service.connectedPeers.isEmpty {
                service.sendLoadVideoCommand(videoName: videoName, playlistInfo: makePlaylistInfo(), isFullScreen: videoPlayer.isFullScreen)
                print("✅ Video ready, broadcasted: \(videoName)")
            }
            // Auto-play when advancing playlist or when selecting a playlist
            if newValue, shouldAutoPlayAfterAdvance {
                videoPlayer.masterPlay()
                shouldAutoPlayAfterAdvance = false
                // Send videoInfoResponse so slave gets play state when its video is ready
                // (play command alone may arrive before slave finishes loading)
                if let videoName = selectedVideo?.name, !service.connectedPeers.isEmpty {
                    service.sendVideoInfoResponse(
                        videoName: videoName,
                        position: videoPlayer.currentTime,
                        isPlaying: true,
                        playlistInfo: makePlaylistInfo(),
                        isFullScreen: videoPlayer.isFullScreen
                    )
                }
            }
        }
        .onChange(of: service.connectedPeers.count) { oldValue, newValue in
            // When slave (re)connects to master, auto-request current video state for smooth sync
            if service.role == .slave, oldValue == 0, newValue > 0 {
                print("✅ Slave connected to master, requesting video info")
                service.sendRequestVideoInfoCommand()
            }
        }
        .onDisappear {
            print("🔧 Cleaning up video sync")
            videoPlayer.player.pause()
            videoPlayer.stopBroadcasting()
            videoDelegateWrapper?.onPlaylistInfoReceived = nil
            service.videoDelegate = nil
            service.onVideoInfoRequest = nil
            service.onPeerConnected = nil
        }
        .sheet(isPresented: $showVideoSelectionSheet) {
            VideoSelectionSheet(
                selectedVideo: $selectedVideo,
                videoStore: videoStore,
                playlists: playlistVm.playlists,
                onSelectVideo: { video in
                    selectedVideo = video
                    activePlaylist = nil
                    playlistIndex = 0
                },
                onSelectPlaylist: { playlist in
                    let videos = resolveVideos(from: playlist)
                    guard let first = videos.first else { return }
                    activePlaylist = playlist
                    playlistIndex = 0
                    selectedVideo = first
                }
            )
        }
        .sheet(isPresented: $showPlaylistQueue) {
            if service.role == .master, let playlist = activePlaylist {
                PlaylistQueueSheet(
                    playlist: playlist,
                    videos: resolveVideos(from: playlist),
                    currentIndex: playlistIndex,
                    onDismiss: { showPlaylistQueue = false }
                )
            } else if let info = slavePlaylistInfo {
                PlaylistQueueSheet(
                    playlistInfo: info,
                    currentVideoName: selectedVideo?.name,
                    onDismiss: { showPlaylistQueue = false }
                )
            }
        }
        .onChange(of: selectedVideo) { oldValue, newValue in
            if let video = newValue, service.role == .master {
                loadVideoForMaster(video)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
        ) { notification in
            if notification.object as? AVPlayerItem === videoPlayer.player.currentItem {
                advancePlaylist()
            }
        }
        .alert(AppText.Alert.videoLoadError, isPresented: $showVideoLoadError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(videoLoadErrorMessage)
        }
    }
    
    // MARK: Header
    private var roomHeader: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.sm) {
                    StatusBadge(service.role == .master ? AppText.Room.master : AppText.Room.slave, isAccent: service.role == .master)

                    HStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(service.connectedPeers.isEmpty ? AppColors.textSecondary : AppColors.accent)
                            .frame(width: 6, height: 6)
                        Text(service.role == .slave && service.connectedPeers.isEmpty && service.isInRoom
                             ? AppText.Room.waitingForMaster
                             : "\(service.connectedPeers.count) connected")
                            .font(.app.label)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Text(AppText.Room.roomActive)
                    .font(.app.titleLarge)
                    .foregroundColor(AppColors.text)
            }

            Spacer()

            Button(action: { service.leaveRoom() }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "xmark")
                        .font(.app.smallSemibold)
                    Text(AppText.General.leave)
                        .font(.app.bodySemibold)
                }
                .foregroundColor(AppColors.danger)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.danger.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(AppColors.danger.opacity(0.3)))
                .cornerRadius(AppRadius.md)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppLayout.safeAreaTopContent)
        .padding(.bottom, AppSpacing.lg)
    }
    
    // MARK: Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([RoomTab.video, RoomTab.devices], id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
                    VStack(spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: iconForTab(tab))
                                .font(.system(size: 13))
                            Text(labelForTab(tab))
                                .font(.app.bodySemibold)
                        }
                        .foregroundColor(selectedTab == tab ? AppColors.accent : AppColors.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
        .background(AppColors.background)
        .overlay(Divider().background(AppColors.border), alignment: .bottom)
    }
    
    private func iconForTab(_ tab: RoomTab) -> String {
        switch tab {
        case .video: return "play.rectangle.fill"
        case .devices: return "network"
        }
    }
    
    private func labelForTab(_ tab: RoomTab) -> String {
        switch tab {
        case .video: return AppText.Room.video
        case .devices: return AppText.Room.devices
        }
    }
    
    // MARK: - Playlist Helpers

    private func makePlaylistInfo() -> PlaylistInfo? {
        guard let playlist = activePlaylist else { return nil }
        let names = resolveVideos(from: playlist).map { $0.name }
        return PlaylistInfo(playlistName: playlist.name, videoNames: names)
    }

    private var currentPlaylistInfo: PlaylistInfo? {
        if service.role == .master { return makePlaylistInfo() }
        return slavePlaylistInfo
    }

    private var currentPlaylistVideo: VideoItem? {
        guard let playlist = activePlaylist else { return nil }
        let videos = resolveVideos(from: playlist)
        guard playlistIndex < videos.count else { return nil }
        return videos[playlistIndex]
    }

    private func resolveVideos(from playlist: PlaylistModelData) -> [VideoItem] {
        let videoById = Dictionary(uniqueKeysWithValues: videoStore.videos.map { ($0.id.uuidString, $0) })
        return playlist.videoIds.compactMap { videoById[$0] }
    }

    private func advancePlaylist() {
        guard let playlist = activePlaylist else { return }
        let videos = resolveVideos(from: playlist)
        let nextIndex = playlistIndex + 1
        guard nextIndex < videos.count else {
            activePlaylist = nil
            playlistIndex = 0
            return
        }
        playlistIndex = nextIndex
        let nextVideo = videos[nextIndex]
        selectedVideo = nextVideo
        shouldAutoPlayAfterAdvance = true
        loadVideoForMaster(nextVideo)
    }

    // MARK: - Video Loading Helpers

    private func loadVideoForMaster(_ videoItem: VideoItem) {
        do {
            let url = try BookmarkResolver.resolve(videoItem.bookmarkURL)
            videoPlayer.loadVideo(url: url, videoName: videoItem.name)
            selectedVideo = videoItem
            
            // Broadcast will happen when video becomes ready (via onChange)
            print("✅ Video loaded: \(videoItem.name)")
        } catch {
            print("❌ Failed to load video: \(error.localizedDescription)")
            videoLoadErrorMessage = error.localizedDescription
            showVideoLoadError = true
            selectedVideo = nil
        }
    }
    
}

// MARK: - Video name matching (case-insensitive, extension ignored)

/// Returns true if both names refer to the same video: comparison is case-insensitive and file extension is ignored.
/// e.g. "Video1.Mp4" matches "video1.mp4", "video2.MOV" matches "video2.mp4".
private func videoNamesMatch(_ a: String?, _ b: String?) -> Bool {
    guard let a = a, let b = b, !a.isEmpty, !b.isEmpty else { return a == b }
    let stemA = (a as NSString).deletingPathExtension.lowercased()
    let stemB = (b as NSString).deletingPathExtension.lowercased()
    return stemA == stemB
}

// MARK: - VideoSyncDelegate Wrapper

class VideoSyncDelegateWrapper: VideoSyncDelegate {
    weak var player: VideoPlayerVM?
    let videoStore: VideoStore
    let onLoadVideo: (String) -> Void
    var onVideoLoaded: ((VideoItem, URL) -> Void)?
    var onError: ((String) -> Void)?
    var onPlaylistInfoReceived: ((PlaylistInfo?) -> Void)?

    init(player: VideoPlayerVM, videoStore: VideoStore, onLoadVideo: @escaping (String) -> Void) {
        self.player = player
        self.videoStore = videoStore
        self.onLoadVideo = onLoadVideo
    }
    
    func didReceiveVideoCommand(_ command: VideoCommand) {
        print("🎬 VideoSyncDelegateWrapper: Forwarding video command to player")
        player?.didReceiveVideoCommand(command)
    }
    
    func didReceiveVideoInfoResponse(videoName: String, position: Double, isPlaying: Bool, playlistInfo: PlaylistInfo?, isFullScreen: Bool?) {
        print("📹 VideoSyncDelegateWrapper: Received video info response")
        print("   Video name: \(videoName)")
        print("   Position: \(position)s, isPlaying: \(isPlaying)")
        
        guard let player = player else {
            print("❌ Player is nil")
            DispatchQueue.main.async {
                self.onError?("Player not available")
            }
            return
        }
        
        // Validate position
        guard position >= 0, position.isFinite else {
            print("❌ Invalid position: \(position)")
            DispatchQueue.main.async {
                self.onError?("Invalid playback position received")
            }
            return
        }
        
        let applyPlayState = {
            player.isRemoteSeeking = false
            if isPlaying {
                player.player.play()
                print("   ✅ Seek completed, starting playback")
            } else {
                player.player.pause()
                print("   ✅ Seek completed, staying paused")
            }
        }
        
        // Check if video is already loaded (case-insensitive, extension ignored)
        let isVideoAlreadyLoaded = videoNamesMatch(player.currentVideoName, videoName)
        
        if isVideoAlreadyLoaded {
            print("✅ Video already loaded: \(videoName)")
            // Only seek if position differs significantly (>0.5 seconds)
            let diff = abs(player.currentTime - position)
            if diff > 0.5 {
                print("   Seeking to position: \(position)s (diff: \(diff)s)")
                DispatchQueue.main.async {
                    let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                    player.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                        if finished { applyPlayState() }
                    }
                }
            } else {
                print("   Position already synced (diff: \(diff)s)")
                DispatchQueue.main.async { applyPlayState() }
            }
            DispatchQueue.main.async {
                self.onPlaylistInfoReceived?(playlistInfo)
                if let full = isFullScreen { player.isFullScreen = full }
            }
        } else {
            print("📹 Video not loaded, loading: \(videoName)")
            
            // Search VideoStore for the video (case-insensitive, extension ignored)
            guard let videoItem = videoStore.videos.first(where: { videoNamesMatch($0.name, videoName) }) else {
                print("❌ Video not found in store: \(videoName)")
                print("   Available videos: \(videoStore.videos.map { $0.name })")
                DispatchQueue.main.async {
                    self.onError?("Video '\(videoName)' not available. Please import it first.")
                }
                return
            }
            
            print("✅ Found video in store: \(videoItem.name)")

            do {
                let resolvedURL = try BookmarkResolver.resolve(videoItem.bookmarkURL)
                print("✅ Bookmark resolved successfully: \(resolvedURL)")

                DispatchQueue.main.async {
                    // Load video
                    player.loadVideo(url: resolvedURL, videoName: videoItem.name)
                    
                    // Wait for video to be ready, then seek and play
                    // Use a timer to check when video is ready
                    var checkCount = 0
                    let maxChecks = 50 // 5 seconds max wait
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                        checkCount += 1
                        if player.isReady {
                            timer.invalidate()
                            print("   ✅ Video ready, seeking to position: \(position)s")
                            let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                            player.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                                if finished {
                                    if isPlaying {
                                        player.player.play()
                                        print("   ✅ Seek completed, starting playback")
                                    } else {
                                        player.player.pause()
                                        print("   ✅ Seek completed, staying paused")
                                    }
                                }
                            }
                        } else if checkCount >= maxChecks {
                            timer.invalidate()
                            print("   ⚠️ Video did not become ready in time")
                            self.onError?("Video loaded but did not become ready")
                                }
                            }
                            
                            self.onVideoLoaded?(videoItem, resolvedURL)
                            self.onPlaylistInfoReceived?(playlistInfo)
                            if let full = isFullScreen { player.isFullScreen = full }
                        }
                    } catch {
                print("❌ Failed to resolve bookmark: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onError?("Failed to load video: \(error.localizedDescription)")
                }
            }
        }
    }

    func didReceiveSetFullScreen(isFullScreen: Bool) {
        DispatchQueue.main.async {
            self.player?.isFullScreen = isFullScreen
        }
    }
    
    func didReceiveLoadVideoCommand(videoName: String, playlistInfo: PlaylistInfo?, isFullScreen: Bool?) {
        print("📹 VideoSyncDelegateWrapper: Received loadVideo command for: \(videoName)")
        DispatchQueue.main.async {
            self.onPlaylistInfoReceived?(playlistInfo)
            if let full = isFullScreen, let player = self.player { player.isFullScreen = full }
        }
        
        // Search VideoStore for the video (case-insensitive, extension ignored)
        guard let videoItem = videoStore.videos.first(where: { videoNamesMatch($0.name, videoName) }) else {
            print("❌ Video not found in store: \(videoName)")
            print("   Available videos: \(videoStore.videos.map { $0.name })")
            DispatchQueue.main.async {
                self.onError?("Video not available. Please import '\(videoName)' first.")
            }
            return
        }
        
        print("✅ Found video in store: \(videoItem.name)")

        do {
            let resolvedURL = try BookmarkResolver.resolve(videoItem.bookmarkURL)
            print("✅ Bookmark resolved successfully: \(resolvedURL)")

            DispatchQueue.main.async {
                self.onVideoLoaded?(videoItem, resolvedURL)
                if let full = isFullScreen, let p = self.player { p.isFullScreen = full }
            }
        } catch {
            print("❌ Failed to resolve bookmark: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.onError?("Failed to load video: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Video Selection Sheet

private enum SelectionTab { case videos, playlists }

struct VideoSelectionSheet: View {
    @Binding var selectedVideo: VideoItem?
    @ObservedObject var videoStore: VideoStore
    let playlists: [PlaylistModelData]
    var onSelectVideo: (VideoItem) -> Void
    var onSelectPlaylist: (PlaylistModelData) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SelectionTab = .videos

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(AppText.VideoList.videos).tag(SelectionTab.videos)
                    Text(AppText.Playlist.playlists).tag(SelectionTab.playlists)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)

                List {
                    if selectedTab == .videos {
                        videosContent
                    } else {
                        playlistsContent
                    }
                }
            }
            .navigationTitle(AppText.Room.selectVideo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppText.General.cancel) { dismiss() }
                }
            }
        }
    }

    private var videosContent: some View {
        Group {
            if videoStore.videos.isEmpty {
                Text(AppText.VideoList.noVideos)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(videoStore.videos) { video in
                    Button(action: {
                        onSelectVideo(video)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "film")
                                .foregroundColor(AppColors.accent)
                            Text(video.name)
                                .foregroundColor(AppColors.text)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var playlistsContent: some View {
        Group {
            if playlists.isEmpty {
                Text(AppText.Playlist.noPlaylists)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(playlists) { playlist in
                    Button(action: {
                        onSelectPlaylist(playlist)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundColor(AppColors.accent)
                            Text(playlist.name)
                                .foregroundColor(AppColors.text)
                            Spacer()
                            Text(String(format: AppText.Playlist.videosCount, playlist.videoIds.count))
                                .font(.app.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Devices Tab

struct DevicesTab: View {
    @EnvironmentObject var service: MultipeerService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                statusCard
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)

                if service.connectedPeers.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(service.connectedPeers) { peer in
                            DeviceRow(peer: peer)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.lg)
                }
            }
        }
    }
    
    private var statusCard: some View {
        HStack(spacing: AppSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.accentDim)
                    .frame(width: 48, height: 48)
                Image(systemName: service.role == .master ? "crown.fill" : "iphone")
                    .foregroundColor(AppColors.accent)
                    .font(.app.iconMedium)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(service.myDisplayName)
                    .font(.app.bodySemibold)
                    .foregroundColor(AppColors.text)
                Text(service.statusMessage.isEmpty ? (service.role == .master ? "Broadcasting room" : "Listening for messages") : service.statusMessage)
                    .font(.app.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColors.accent.opacity(0.25)))
        .cornerRadius(AppRadius.lg)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 60)
            Image(systemName: service.role == .slave && service.isInRoom ? "clock.arrow.circlepath" : "wifi.slash")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppColors.textSecondary)
            Text(service.role == .master ? "Waiting for devices to join…" : (service.isInRoom ? AppText.Room.waitingForMaster : "Not connected to any master"))
                .font(.app.body)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

struct DeviceRow: View {
    let peer: ConnectedPeer

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.surface)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(AppColors.border))
                Image(systemName: "iphone")
                    .font(.app.iconSmall)
                    .foregroundColor(AppColors.warning)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(peer.displayName)
                    .font(.app.bodySemibold)
                    .foregroundColor(AppColors.text)
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 6, height: 6)
                    Text(AppText.Room.connected)
                        .font(.app.small)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.accent)
                .font(.app.iconSmall)
        }
        .padding(AppSpacing.lg)
        .appCardStyle(isSelected: false)
    }
}
