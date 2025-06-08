import Kingfisher
import SwiftUI

struct SquareGalleryImageAsync: View {
    let url: URL?
    private let cornerRadius: CGFloat = 8
    @State private var isAppeared = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width

            Group {
                // UIテスト時は固定の画像を使用
                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    Image("cat_1be")
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
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .opacity(isAppeared ? 1 : 0)
            .scaleEffect(isAppeared ? 1 : 0.95)
            .animation(.easeOut(duration: 0.3), value: isAppeared)
            .onAppear {
                isAppeared = true
            }
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(.systemBackground).opacity(0.3), lineWidth: 2)
            )
        }
    }
}
