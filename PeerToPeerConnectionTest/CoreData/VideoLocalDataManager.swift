//
//  VideoLocalDataManager.swift
//  PeerToPeerConnectionTest
//

import Combine
import CoreData
import Foundation

class VideoLocalDataManager {
    public struct ModelNotFound: Error {
        public let modelName: String
    }

    public struct DataAlreadyExistError: Error {
        public let description: String
    }

    static let modelName = "VideoDataContainer"
    static let model = NSManagedObjectModel(name: modelName, in: Bundle(for: VideoLocalDataManager.self))

    private let container: NSPersistentContainer
    let context: NSManagedObjectContext

    public init(storeURL: URL? = nil) throws {
        if let storeURL = storeURL {
            // Test
            guard let model = VideoLocalDataManager.model else {
                throw ModelNotFound(modelName: VideoLocalDataManager.modelName)
            }
            container = try NSPersistentContainer.load(name: Self.modelName, model: model, url: storeURL)
            debugPrint("DB>> Stored DB in \(storeURL.absoluteString)")
        } else {
            container = NSPersistentContainer(name: Self.modelName)
            container.loadPersistentStores { _, error in
                if let error = error {
                    debugPrint("Error Loading Core Data - \(error)")
                }
            }
        }
        context = container.newBackgroundContext()
        whereIsMySQLite()
    }

    deinit { cleanUpReferencesToPersistentStores() }

    // MARK: - Video Operations

    func insertVideos(videoDatas: [VideoCoreDataModel]) -> AnyPublisher<Bool, Error> {
        perform { context in
            let fetchRequest: NSFetchRequest<VideoEntity> = VideoEntity.fetchRequest()
            let existingIds = try context.fetch(fetchRequest).compactMap(\.id)

            let newVideos = videoDatas.filter { !existingIds.contains($0.id) }
            newVideos.forEach { model in
                let entity = VideoEntity(context: context)
                entity.id = model.id
                entity.name = model.name
                entity.bookmarkData = model.bookmarkData
            }
            do {
                try context.save()
                return true
            } catch {
                return false
            }
        }
    }

    func retrieveVideos() -> AnyPublisher<[VideoCoreDataModel], Error> {
        perform { context in
            let request: NSFetchRequest<VideoEntity> = VideoEntity.fetchRequest()
            let results = try context.fetch(request)
            return results.map { entityData in
                entityData.toCoreDataModel()
            }
        }
    }

    func updateVideo(updatedData: VideoCoreDataModel) -> AnyPublisher<VideoCoreDataModel, Error> {
        filterVideos(parameters: ["id": updatedData.id])
            .tryMap { [weak self] entities in
                guard let self, let singleEntity = entities.first else { throw NSError(domain: "UpdateError", code: 404) }

                singleEntity.convertFromCoreDataModel(coreData: updatedData)

                do {
                    try context.save()
                    return updatedData
                } catch {
                    throw error
                }
            }
            .eraseToAnyPublisher()
    }

    func deleteVideo(videoId: String) -> AnyPublisher<Bool, Error> {
        filterVideos(parameters: ["id": videoId])
            .tryMap { [weak self] entities in
                guard let self, let object = entities.first else { throw NSError(domain: "DeleteError", code: 404) }
                context.delete(object)
                try self.context.save()
                return true
            }
            .eraseToAnyPublisher()
    }

    func filterVideos(parameters: [String: Any]) -> AnyPublisher<[VideoEntity], Error> {
        perform { context in
            let request: NSFetchRequest<VideoEntity> = VideoEntity.fetchRequest()
            let predicates = parameters.map { NSPredicate(format: "%K == %@", $0.key, $0.value as! CVarArg) }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.fetchLimit = 1
            let results = try context.fetch(request)
            if results.isEmpty {
                print("⚠️ DB Filter: No results for \(parameters)")
            }
            return results
        }
    }

    // MARK: - Playlist Operations

    func insertPlaylists(playlists: [PlaylistCoreDataModel]) -> AnyPublisher<Bool, Error> {
        perform { context in
            playlists.forEach { model in
                let entity = PlaylistEntity(context: context)
                entity.convertFromCoreDataModel(coreData: model)
            }
            do {
                try context.save()
                return true
            } catch {
                return false
            }
        }
    }

    func retrievePlaylists() -> AnyPublisher<[PlaylistCoreDataModel], Error> {
        perform { context in
            let request: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
            let results = try context.fetch(request)
            return results.map { $0.toCoreDataModel() }
        }
    }

    func updatePlaylist(updatedData: PlaylistCoreDataModel) -> AnyPublisher<PlaylistCoreDataModel, Error> {
        filterPlaylists(parameters: ["id": updatedData.id])
            .tryMap { [weak self] entities in
                guard let self, let singleEntity = entities.first else { throw NSError(domain: "UpdateError", code: 404) }
                singleEntity.convertFromCoreDataModel(coreData: updatedData)
                try context.save()
                return updatedData
            }
            .eraseToAnyPublisher()
    }

    func deletePlaylist(playlistId: String) -> AnyPublisher<Bool, Error> {
        filterPlaylists(parameters: ["id": playlistId])
            .tryMap { [weak self] entities in
                guard let self, let object = entities.first else { throw NSError(domain: "DeleteError", code: 404) }
                context.delete(object)
                try context.save()
                return true
            }
            .eraseToAnyPublisher()
    }

    func filterPlaylists(parameters: [String: Any]) -> AnyPublisher<[PlaylistEntity], Error> {
        perform { context in
            let request: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
            let predicates = parameters.map { NSPredicate(format: "%K == %@", $0.key, $0.value as! CVarArg) }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            let results = try context.fetch(request)
            return results
        }
    }

    // MARK: - Private Helpers

    private func cleanUpReferencesToPersistentStores() {
        context.performAndWait {
            let coordinator = self.container.persistentStoreCoordinator
            try? coordinator.persistentStores.forEach(coordinator.remove)
        }
    }

    private func perform<T>(_ action: @escaping (NSManagedObjectContext) throws -> T) -> AnyPublisher<T, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "VideoLocalDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self deallocated"])))
                return
            }

            self.context.perform {
                do {
                    let result = try action(self.context)
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func whereIsMySQLite() {
        if let path = NSPersistentContainer.defaultDirectoryURL().path.removingPercentEncoding {
            debugPrint("DB Location: \(path)")
        }
    }
}

// MARK: - Entity Conversion Extensions

extension VideoEntity {
    static func find(in context: NSManagedObjectContext) throws -> VideoEntity? {
        let request = NSFetchRequest<VideoEntity>(entityName: entity().name!)
        return try context.fetch(request).first
    }

    static func getInstance(in context: NSManagedObjectContext) throws -> VideoEntity {
        let instance = try find(in: context)
        return instance ?? VideoEntity(context: context)
    }

    func toCoreDataModel() -> VideoCoreDataModel {
        return VideoCoreDataModel(id: id ?? "",
                                  name: name ?? "",
                                  bookmarkData: bookmarkData ?? Data())
    }
}

extension PlaylistEntity {
    func toCoreDataModel() -> PlaylistCoreDataModel {
        return PlaylistCoreDataModel(id: id ?? "",
                                     name: name ?? "",
                                     videoIds: PlaylistCoreDataModel.parseVideoIds(videoIds))
    }
}
