//
//  VideoListView.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 20/2/26.
//

internal import SwiftUI

struct VideoListView: View {
    @EnvironmentObject var videoStore: VideoStore
    @State private var showVideoPicker = false
    @State private var showDocumentPicker = false
    @State private var showPickerOptions = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                
                if videoStore.videos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.textDim)
                        Text("No videos imported yet")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textDim)
                    }
                } else {
                    List {
                        ForEach(videoStore.videos) { video in
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(AppTheme.accent)
                                    .font(.system(size: 20))
                                Text(video.name)
                                    .foregroundColor(AppTheme.text)
                                    .font(.system(size: 15))
                            }
                            .listRowBackground(AppTheme.surface)
                        }
                        .onDelete(perform: deleteVideos)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Videos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showPickerOptions = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .confirmationDialog("Select Video Source", isPresented: $showPickerOptions, titleVisibility: .visible) {
                Button("Photos Library") {
                    showVideoPicker = true
                }
                Button("Files") {
                    showDocumentPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker(isPresented: $showVideoPicker) { name, bookmarkData in
                    videoStore.addVideo(name: name, bookmarkURL: bookmarkData)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(isPresented: $showDocumentPicker) { name, bookmarkData in
                    videoStore.addVideo(name: name, bookmarkURL: bookmarkData)
                }
            }
        }
    }
    
    private func deleteVideos(at offsets: IndexSet) {
        videoStore.deleteVideo(at: offsets)
    }
}
