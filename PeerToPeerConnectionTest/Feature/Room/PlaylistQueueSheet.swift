//
//  PlaylistQueueSheet.swift
//  PeerToPeerConnectionTest
//

internal import SwiftUI

// MARK: - PlaylistQueueSheet

struct PlaylistQueueSheet: View {
    private enum Source {
        case master(playlist: PlaylistModelData, videos: [VideoItem], currentIndex: Int)
        case slave(playlistInfo: PlaylistInfo, currentVideoName: String?)
    }
    
    private let source: Source
    private let onDismiss: () -> Void
    
    // Master init — driven by local playlist model
    init(playlist: PlaylistModelData, videos: [VideoItem], currentIndex: Int, onDismiss: @escaping () -> Void) {
        self.source = .master(playlist: playlist, videos: videos, currentIndex: currentIndex)
        self.onDismiss = onDismiss
    }
    
    // Slave init — driven purely by received PlaylistInfo
    init(playlistInfo: PlaylistInfo, currentVideoName: String?, onDismiss: @escaping () -> Void) {
        self.source = .slave(playlistInfo: playlistInfo, currentVideoName: currentVideoName)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(row.isCurrent ? AppTheme.accent : AppTheme.textDim)
                            .frame(width: 24, alignment: .leading)

                        Text(row.name)
                            .font(.system(size: 14, weight: row.isCurrent ? .semibold : .regular))
                            .foregroundColor(row.isCurrent ? AppTheme.text : AppTheme.textDim)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        if row.isCurrent {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .listRowBackground(row.isCurrent ? AppTheme.accentDim : Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var title: String {
        switch source {
        case .master(let playlist, _, _): return playlist.name
        case .slave(let info, _): return info.playlistName
        }
    }
    
    private struct Row { let name: String; let isCurrent: Bool }
    
    private var rows: [Row] {
        switch source {
        case .master(_, let videos, let currentIndex):
            return videos.enumerated().map { Row(name: $0.element.name, isCurrent: $0.offset == currentIndex) }
        case .slave(let info, let currentVideoName):
            return info.videoNames.map { name in
                Row(name: name, isCurrent: playlistVideoNamesMatch(name, currentVideoName))
            }
        }
    }
}

// Case-insensitive, extension-ignored match for playlist display
private func playlistVideoNamesMatch(_ a: String, _ b: String?) -> Bool {
    guard let b = b, !a.isEmpty, !b.isEmpty else { return false }
    let stemA = (a as NSString).deletingPathExtension.lowercased()
    let stemB = (b as NSString).deletingPathExtension.lowercased()
    return stemA == stemB
}
