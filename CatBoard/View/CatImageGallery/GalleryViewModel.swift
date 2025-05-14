import CBShared
import Combine
import Infrastructure
import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var catImages: [CatImageModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var imageClient: ImageClientProtocol
    private var cancellables = Set<AnyCancellable>()
    private static let imagesPerFetch = 10

    init(imageClient: ImageClientProtocol) {
        self.imageClient = imageClient
    }

    @MainActor func onAppear() {
        if catImages.isEmpty {
            fetchAdditionalImages()
        }
    }

    @MainActor
    func fetchAdditionalImages() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
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

                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
