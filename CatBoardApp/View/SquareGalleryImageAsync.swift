import Kingfisher
import SwiftUI

struct SquareGalleryImageAsync: View {
    let url: URL?
    private let cornerRadius: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width

            KFImage(source: url.map { .network($0) })
                .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 200, height: 200)))
                .memoryCacheExpiration(.minutes(1))
                .diskCacheExpiration(.expired)
                .cacheOriginalImage(false)
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
        }
    }
}
