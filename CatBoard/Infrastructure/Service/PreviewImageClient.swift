#if DEBUG
    import ComposableArchitecture
    import Foundation

    // PreviewImageClientは、ImageClient.previewValueを直接使うか、
    // より複雑なプレビューロジックが必要な場合に個別に定義します。
    // ここでは ImageClient.previewValue を使うことを推奨するため、
    // このファイルは不要になるかもしれませんが、例として残します。

    enum PreviewImageClient {
        static func create() -> ImageClient {
            ImageClient(
                fetchImages: { limit, page in
                    print("Using explicit PreviewImageClient - Returning sample data (limit: \(limit), page: \(page))")
                    try await Task.sleep(for: .seconds(1))
                    return []
                }
            )
        }
    }

#endif
