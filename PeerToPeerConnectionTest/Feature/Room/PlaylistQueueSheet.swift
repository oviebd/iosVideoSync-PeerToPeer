//
//  PlaylistQueueSheet.swift
//  PeerToPeerConnectionTest
//
//  Redesigned with Core design system.
//

internal import SwiftUI

struct PlaylistQueueSheet: View {
    private enum Source {
        case master(playlist: PlaylistModelData, videos: [VideoItem], currentIndex: Int)
        case slave(playlistInfo: PlaylistInfo, currentVideoName: String?)
    }

    private let source: Source
    private let onDismiss: () -> Void

    init(playlist: PlaylistModelData, videos: [VideoItem], currentIndex: Int, onDismiss: @escaping () -> Void) {
        self.source = .master(playlist: playlist, videos: videos, currentIndex: currentIndex)
        self.onDismiss = onDismiss
    }

    init(playlistInfo: PlaylistInfo, currentVideoName: String?, onDismiss: @escaping () -> Void) {
        self.source = .slave(playlistInfo: playlistInfo, currentVideoName: currentVideoName)
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: AppSpacing.md) {
                        Text("\(index + 1)")
                            .font(.app.bodyMedium)
                            .foregroundColor(row.isCurrent ? AppColors.accent : AppColors.textSecondary)
                            .frame(width: 24, alignment: .leading)

                        Text(row.name)
                            .font(.system(size: 14, weight: row.isCurrent ? .semibold : .regular))
                            .foregroundColor(row.isCurrent ? AppColors.text : AppColors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        if row.isCurrent {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.app.body)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.md)
                    .listRowBackground(row.isCurrent ? AppColors.accentDim : Color.clear)
                    .listRowInsets(EdgeInsets(top: AppSpacing.xs, leading: AppSpacing.lg, bottom: AppSpacing.xs, trailing: AppSpacing.lg))
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppText.General.done) { onDismiss() }
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
            return info.videoNames.map { Row(name: $0, isCurrent: playlistVideoNamesMatch($0, currentVideoName)) }
        }
    }
}

private func playlistVideoNamesMatch(_ a: String, _ b: String?) -> Bool {
    guard let b = b, !a.isEmpty, !b.isEmpty else { return false }
    let stemA = (a as NSString).deletingPathExtension.lowercased()
    let stemB = (b as NSString).deletingPathExtension.lowercased()
    return stemA == stemB
}
