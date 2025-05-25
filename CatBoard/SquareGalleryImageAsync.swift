import Kingfisher
import SwiftUI

struct SquareGalleryImageAsync: View {
    let url: URL?
    private let cornerRadius: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width

            KFImage(url)
                .placeholder {
                    Color(.secondarySystemBackground)
                        .frame(width: size, height: size)
                }
                .fade(duration: 0.3)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.systemBackground).opacity(0.3), lineWidth: 2)
                )
                .setOptions([.cacheMemoryOnly])
        }
    }
}
