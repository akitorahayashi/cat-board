import SwiftUI
import TieredGridLayout


struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        ScrollView {
            TieredGridLayout {
                ForEach(viewModel.items) { item in
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .border(Color.white, width: 2)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                                .border(Color.white, width: 2)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchImages()
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
