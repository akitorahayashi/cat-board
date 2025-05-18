import Kingfisher
import CBShared
import Combine
import Infrastructure
import SwiftUI
import UIKit

class GalleryViewModel: ObservableObject {
    @Published var catImages: [CatImageModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private var imageClient: ImageClientProtocol
    private var cancellables = Set<AnyCancellable>()
    private static let imagesPerFetch = 10
    private static let maxImageCount = 300
    
    init(imageClient: ImageClientProtocol) {
        self.imageClient = imageClient
    }
    
    @MainActor func onAppear() {
        if catImages.isEmpty {
            Task {
                await fetchAdditionalImages()
            }
        }
    }
    
    @MainActor
    func fetchAdditionalImages() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let stream = await imageClient.fetchImages(
                desiredSafeImageCountPerFetch: Self.imagesPerFetch,
                timesOfFetch: 3
            )
            var newItems: [CatImageModel] = []
            for try await batch in stream {
                newItems += batch.map { model -> CatImageModel in
                    var mutableModel = model
                    mutableModel.isLoading = false
                    return mutableModel
                }
            }
            self.catImages.append(contentsOf: newItems)
            
            if self.catImages.count > Self.maxImageCount {
                self.catImages = []
                KingfisherManager.shared.cache.clearMemoryCache()
            }
            
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
}
