//
//  BookmarkResolver.swift
//  PeerToPeerConnectionTest
//

import Foundation

// MARK: - BookmarkResolver

enum BookmarkResolver {
    /// Resolves bookmark data to a URL and starts accessing the security-scoped resource.
    /// Caller is responsible for calling `stopAccessingSecurityScopedResource()` when done.
    static func resolve(_ data: Data) throws -> URL {
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: data,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            throw NSError(domain: "VideoLoadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bookmark is stale"])
        }

        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "VideoLoadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to access security-scoped resource"])
        }

        return resolvedURL
    }
}
