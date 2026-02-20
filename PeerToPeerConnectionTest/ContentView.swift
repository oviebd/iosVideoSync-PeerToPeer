//
//  ContentView.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 18/2/26.
//

internal import SwiftUI

struct ContentView: View {
    @StateObject private var service = MultipeerService()
    
    var body: some View {
        Group {
            if service.isInRoom {
                RoomView()
                    .environmentObject(service)
            } else {
                HomeView()
                    .environmentObject(service)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: service.isInRoom)
    }
}

#Preview {
    ContentView()
}
