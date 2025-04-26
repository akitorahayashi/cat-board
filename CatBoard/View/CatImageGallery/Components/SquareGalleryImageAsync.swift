import SwiftUI

struct SquareGalleryImageAsync: View {
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
                    case let .success(image):
                        image.resizable()
                            .scaledToFill()
                            .opacity(1.0)
                            .scaleEffect(1.0)

                    case .failure:
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
            if let symbol {
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
                    .offset(x: shimmer ? 100 : -100)
                    .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: shimmer)
            }
        }
    }
}

//#Preview("Success") {
//    SquareGalleryImageAsync(url: URL(string: "https://cdn2.thecatapi.com/images/0XYvRd7oD.jpg"))
//        .frame(width: 150, height: 150)
//}

#Preview("Placeholder (Loading/Nil URL)") {
    SquareGalleryImageAsync(url: nil)
        .frame(width: 150, height: 150)
}

//#Preview("Placeholder (Failure)") {
//    // Use a deliberately non-resolving URL to potentially trigger the failure case,
//    // though network conditions might still show loading first.
//    SquareGalleryImageAsync(url: URL(string: "file:///nonexistent.jpg"))
//        .frame(width: 150, height: 150)
//}
