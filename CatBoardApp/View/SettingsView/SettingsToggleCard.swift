import SwiftUI

struct SettingsToggleCard: View {
    let title: String
    let caption: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(caption)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsToggleCard(
            title: "画像スクリーニング",
            caption: "不適切な画像をフィルタリングします",
            isOn: .constant(true)
        )

        SettingsToggleCard(
            title: "スケアリーモード",
            caption: "危険と判定された画像のみを表示します",
            isOn: .constant(false)
        )
    }
    .padding()
}
