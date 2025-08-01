import CatImagePrefetcher
import CatImageScreener
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var screeningSettings = ScreeningSettings()

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
                        isOn: $screeningSettings.isScreeningEnabled
                    )
                    .onChange(of: screeningSettings.isScreeningEnabled) {
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
                        isOn: $screeningSettings.scaryMode
                    )
                    .onChange(of: screeningSettings.scaryMode) {
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
            // presentationDetentsでmediumに指定しており、sheet外の部分をタップすると自動で閉じるため
            // .toolbar {
            //     doneToolbarItem
            // }
        }
    }

    private var doneToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                dismiss()
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
