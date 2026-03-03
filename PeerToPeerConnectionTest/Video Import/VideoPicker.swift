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
        configuration.selectionLimit = 0  // 0 = unlimited
        
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
            
            guard !results.isEmpty else { return }
            
            let videoResults = results.filter { $0.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) }
            
            for result in videoResults {
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
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
            
            // Ensure unique filename to avoid overwriting
            var counter = 1
            let baseName = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            while FileManager.default.fileExists(atPath: destinationURL.path) {
                let uniqueName = "\(baseName) (\(counter)).\(ext)"
                destinationURL = documentsPath.appendingPathComponent(uniqueName)
                counter += 1
            }
            
            do {
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                let bookmarkData = try destinationURL.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                let fileName = destinationURL.lastPathComponent
                
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
        picker.allowsMultipleSelection = true
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
            parent.isPresented = false
            
            guard !urls.isEmpty else { return }
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource for: \(url.lastPathComponent)")
                    continue
                }
                
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .minimalBookmark,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    
                    let fileName = url.lastPathComponent
                    
                    DispatchQueue.main.async {
                        self.parent.onVideoPicked(fileName, bookmarkData)
                    }
                } catch {
                    print("Failed to create bookmark: \(error)")
                }
                
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
        }
    }
}
