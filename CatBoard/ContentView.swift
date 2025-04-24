import SwiftUI
import TieredGridLayout

struct SquareAsyncImage: View {
    let url: URL?
    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            let geometryWidth = geo.size.width
            AsyncImage(
                url: url,
                transaction: Transaction(animation: .easeInOut(duration: 0.3))
            ) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                         .scaledToFill()
                         .opacity(1.0)
                         .scaleEffect(1.0)

                case .failure(_):
                    placeholder(symbol: "photo")

                default:
                    placeholder(symbol: nil)
                }
            }
            .frame(width: geometryWidth, height: geometryWidth)
            .clipped()
            .onAppear { shimmer = true }
            .onDisappear { shimmer = false }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func placeholder(symbol: String?) -> some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let symbol = symbol {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .foregroundColor(.secondary)
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(.secondarySystemBackground).opacity(0.6), location: 0),
                                .init(color: Color(.secondarySystemBackground).opacity(0.9), location: 0.5),
                                .init(color: Color(.secondarySystemBackground).opacity(0.6), location: 1),
                            ]),
                            startPoint: .init(x: -1, y: 0.5),
                            endPoint: .init(x: 2, y: 0.5)
                        )
                    )
                    .offset(x: shimmer ? 300 : -300)
                    .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: shimmer)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        ScrollView {
            TieredGridLayout {
                ForEach(viewModel.items) { item in
                    SquareAsyncImage(url: URL(string: item.imageURL))
                        .border(Color.white, width: 2)
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
