//
//  ContentView.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 18/2/26.
//

internal import SwiftUI

struct ContentView: View {
    @StateObject private var service = MultipeerService()
    @StateObject private var videoStore = VideoStore()
    
    var body: some View {
        Group {
            if service.isInRoom {
                RoomView()
                    .environmentObject(service)
                    .environmentObject(videoStore)
            } else {
                TabView {
                    VideoListView()
                        .environmentObject(videoStore)
                        .tabItem {
                            Label("Videos", systemImage: "film")
                        }
                    
                    HomeView()
                        .environmentObject(service)
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: service.isInRoom)
    }
}

#Preview {
    ContentView()
}
