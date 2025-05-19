

import Foundation
import SwiftData
import CBShared

actor CatImageRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchUnviewedCatImageModels(limit: Int? = nil) throws -> [CatImageModel] {
        var descriptor = FetchDescriptor<CatImageEntity>(
            predicate: #Predicate { !$0.isViewed },
            sortBy: [.init(\.createdAt, order: .reverse)]
        )
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        let entities = try modelContext.fetch(descriptor)
        return entities.map(CatImageModel.init(entity:))
    }

    func saveNewImages(_ models: [CatImageModel]) {
        for model in models {
            let entity = CatImageEntity(url: model.imageURL)
            modelContext.insert(entity)
        }
        try? modelContext.save()
    }

    func markAsViewed(urls: [String]) {
        let descriptor = FetchDescriptor<CatImageEntity>(
            predicate: #Predicate { urls.contains($0.url) }
        )
        if let entities = try? modelContext.fetch(descriptor) {
            for entity in entities {
                entity.isViewed = true
            }
            try? modelContext.save()
        }
    }
}