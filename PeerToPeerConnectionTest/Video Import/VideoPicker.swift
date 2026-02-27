//
//  VideoPicker.swift
//  PeerToPeerConnectionTest
//
//  Created by Habibur_Periscope on 20/2/26.
//

internal import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Photos Picker

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onVideoPicked: (String, Data) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard let result = results.first else { return }
            
            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    guard let url = url, error == nil else {
                        print("Failed to load file: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    self.processVideo(url: url)
                }
            }
        }
        
        private func processVideo(url: URL) {
            // Copy to app's documents directory to create a bookmarkable URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
            
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy file
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // Create security-scoped bookmark
                let bookmarkData = try destinationURL.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                let fileName = url.lastPathComponent
                
                DispatchQueue.main.async {
                    self.parent.onVideoPicked(fileName, bookmarkData)
                }
            } catch {
                print("Failed to copy file or create bookmark: \(error)")
            }
        }
    }
}

// MARK: - Document Picker (Files App)

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onVideoPicked: (String, Data) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .avi], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.isPresented = false
                return
            }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource")
                parent.isPresented = false
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Create security-scoped bookmark for the selected file
            // Note: .withSecurityScope and .securityScopeAllowOnlyReadAccess are macOS-only
            // For iOS, we use .minimalBookmark which works with startAccessingSecurityScopedResource()
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                let fileName = url.lastPathComponent
                
                DispatchQueue.main.async {
                    self.parent.onVideoPicked(fileName, bookmarkData)
                    self.parent.isPresented = false
                }
            } catch {
                print("Failed to create bookmark: \(error)")
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
    }
}
