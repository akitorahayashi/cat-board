import CatImagePrefetcher
import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var appSettings = AppSettings.shared

    let prefetcher: CatImagePrefetcherProtocol?

    init(prefetcher: CatImagePrefetcherProtocol? = nil) {
        self.prefetcher = prefetcher
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggleCard(
                        title: "画像スクリーニング",
                        caption: "不適切な画像をフィルタリングします。オフにすると全ての画像が表示されます",
                        isOn: $appSettings.isScreeningEnabled
                    )
                    .onChange(of: appSettings.isScreeningEnabled) {
                        clearPrefetchCache()
                    }

                    Text("※シミュレータでは十分なパフォーマンスを出せないため、iPhone16等の実機でスクリーニングを実行することを推奨します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)

                    Spacer().frame(height: 4)

                    SettingsToggleCard(
                        title: "スケアリーモード",
                        caption: "危険と判定された画像のみを表示します。通常は安全な画像のみが表示されます",
                        isOn: $appSettings.scaryMode
                    )
                    .onChange(of: appSettings.scaryMode) {
                        clearPrefetchCache()
                    }

                    Text("※このモードを使用するには画像スクリーニングをオンにする必要があります")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                doneToolbarItem
            }
        }
    }

    private var doneToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Label("完了", systemImage: "checkmark")
            }
        }
    }

    private func clearPrefetchCache() {
        guard let prefetcher else { return }

        Task {
            do {
                try await prefetcher.clearAllPrefetchedImages()
            } catch {
                print("プリフェッチキャッシュのクリアに失敗: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SettingsView()
}
