//
//  PlaylistQueueSheet.swift
//  PeerToPeerConnectionTest
//

internal import SwiftUI

// MARK: - PlaylistQueueSheet

struct PlaylistQueueSheet: View {
    let playlist: PlaylistModelData
    let videos: [VideoItem]
    let currentIndex: Int
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(index == currentIndex ? AppTheme.accent : AppTheme.textDim)
                            .frame(width: 24, alignment: .leading)

                        Text(video.name)
                            .font(.system(size: 14, weight: index == currentIndex ? .semibold : .regular))
                            .foregroundColor(index == currentIndex ? AppTheme.text : AppTheme.textDim)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        if index == currentIndex {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .listRowBackground(index == currentIndex ? AppTheme.accentDim : Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle(playlist.name)
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
}
