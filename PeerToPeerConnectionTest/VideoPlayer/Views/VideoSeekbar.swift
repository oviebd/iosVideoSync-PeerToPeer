//
//  VideoSeekbar.swift
//  PeerToPeerConnectionTest
//

internal import SwiftUI

struct VideoSeekbar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)

                // Progress Track
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width), height: 3)

                // Thumb (Handler) - Rounded and Small
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(radius: 2)
                    .offset(x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - 5)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                onEditingChanged(true)
                                let newValue = min(max(range.lowerBound, Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound), range.upperBound)
                                value = newValue
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle()) // Better hit testing
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let newValue = min(max(range.lowerBound, Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound), range.upperBound)
                        value = newValue
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 20) // Hit target height
    }
}
