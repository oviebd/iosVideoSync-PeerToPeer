//
//  AppText.swift
//  PeerToPeerConnectionTest
//
//  Centralized reusable text content (labels, buttons, placeholders, alerts).
//

import Foundation

enum AppText {

    // MARK: - General

    enum General {
        static let cancel = "Cancel"
        static let ok = "OK"
        static let done = "Done"
        static let create = "Create"
        static let save = "Save"
        static let delete = "Delete"
        static let edit = "Edit"
        static let leave = "Leave"
        static let join = "JOIN"
    }

    // MARK: - Home

    enum Home {
        static let title = "Device\nNetwork"
        static let badgeP2P = "P2P CONNECT"
        static let badgeWifi = "LOCAL WIFI"
        static let thisDevice = "THIS DEVICE"
        static let createRoom = "Create Room"
        static let createRoomSubtitle = "Become the master device"
        static let joinRoom = "Join Room"
        static let joinRoomSubtitle = "Connect to a master device"
    }

    // MARK: - Room

    enum Room {
        static let roomActive = "Room Active"
        static let connected = "Connected"
        static let master = "MASTER"
        static let slave = "SLAVE"
        static let selectVideo = "Select Video"
        static let video = "Video"
        static let devices = "Devices"
    }

    // MARK: - Browse

    enum Browse {
        static let scan = "SCAN"
        static let availableRooms = "Available Rooms"
        static let searching = "Searching for rooms…"
        static let masterReady = "Master Device · Ready"
    }

    // MARK: - Video List

    enum VideoList {
        static let videos = "Videos"
        static let noVideos = "No videos available"
        static let noVideosOrPlaylists = "No videos or playlists yet"
        static let noVideosInPlaylist = "No videos in this playlist"
        static let allVideos = "All Videos"
        static let importVideos = "Import Videos"
        static let selectAll = "Select All"
        static let deselectAll = "Deselect All"
        static let selectedCount = "%d Selected"
    }

    // MARK: - Playlist

    enum Playlist {
        static let playlists = "Playlists"
        static let noPlaylists = "No playlists yet"
        static let videosCount = "%d videos"
    }

    // MARK: - Alerts

    enum Alert {
        static let videoLoadError = "Video Load Error"
        static let videoNotAvailable = "Video not available. Please import '%@' first."
        static let videoNotFound = "Video '%@' not available. Please import it first."
        static let deleteVideos = "Delete Videos"
        static let deleteVideosMessage = "Are you sure you want to delete the selected videos?"
        static let deletePlaylist = "Delete Playlist"
        static let deletePlaylistMessage = "Are you sure you want to delete '%@'? This action cannot be undone."
        static let newFolder = "New Folder"
        static let newFolderMessage = "Enter a name for this folder."
        static let selectOption = "Select Option"
        static let moveToPlaylist = "Move to Playlist"
        static let photosLibrary = "Photos Library"
        static let files = "Files"
        static let folderName = "Folder Name"
        static let editName = "Edit Name"
        static let videoName = "Video name"
    }

    // MARK: - Placeholders

    enum Placeholder {
        static let search = "Search..."
        static let playlistName = "Playlist name"
    }
}
