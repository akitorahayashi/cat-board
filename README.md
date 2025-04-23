## 開発環境

プロジェクトのビルドと開発に必要なツールとそのバージョンは `Mintfile` で管理されています
以下のコマンドで必要なツール (`SwiftFormat`, `SwiftLint`) をインストールできます

```bash
# Mintをインストール（未導入の場合）
brew install mint

# Mintfileに記載されたツールをインストール/アップデート
mint bootstrap
```

TCAなどの依存パッケージはSwift Package Managerによって自動的に管理されるため、Xcodeがプロジェクトを開く際に必要なパッケージを自動的にダウンロードします

これにより、プロジェクトで使用している以下のツールが自動的にインストール、またはバージョン管理されます：
- SwiftLint (`0.59.1`)
- SwiftFormat (`0.55.5`)
