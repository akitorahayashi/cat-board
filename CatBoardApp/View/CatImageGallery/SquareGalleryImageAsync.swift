import Foundation
import Kingfisher
import SwiftUI

struct SquareGalleryImageAsync: View {
    let url: URL?
    private let cornerRadius: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width

            Group {
                // UIテスト時は固定の画像を使用
                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    Image("SampleUITestImage")
                        .resizable()
                        .scaledToFill()
                } else {
                    KFImage(source: url.map { .network($0) })
                        .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 200, height: 200)))
                        .memoryCacheExpiration(.seconds(3600))
                        .diskCacheExpiration(.expired)
                        .cacheOriginalImage(false)
                        .placeholder {
                            Color(.secondarySystemBackground)
                                .frame(width: size, height: size)
                        }
                        .fade(duration: 0.3)
                        .resizable()
                        .scaledToFill()
                }
            }
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
