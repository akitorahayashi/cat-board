# CatBoard

## アーキテクチャ

このアプリは The Composable Architecture (TCA) を基盤としたアーキテクチャを採用しています。

具体的には、UIを担当するプレゼンテーション層、ビジネスロジックと状態を管理するドメイン層、そして外部依存を抽象化するインフラ層に分けられます。この構成は、TCAの状態管理と依存性注入の強みを活かし、保守性の高いコードベースを実現します。

### プレゼンテーション層 (View/)

SwiftUI View で構成され、ユーザーインターフェースの表示とユーザー操作の受付を担当します。TCA の ViewStore を介して状態を監視し、Action を Store に送信します。

### ドメイン層 (Domain/)

TCA の主要コンポーネント (State, Action, Reducer) で構成されます。
各機能（例: `Coordinator`, `Gallery`, `ImageRepository`）が独立したドメインとして定義され、それぞれの状態管理とビジネスロジックを担当します。

- **`CoordinatorReducer`**: ルートとして各ドメインの Reducer を統合し、アプリ全体の状態遷移や機能間の連携を管理します。
- **`GalleryReducer`**: ギャラリー画面固有の表示ロジック（例：画像タップ処理）や、`ImageRepositoryReducer` へのデータ要求などを担当します。
- **`ImageRepositoryReducer`**: 画像データの取得（API通信）、キャッシュ管理（将来実装予定）、および関連する状態（画像リスト、読み込み状態など）の管理を担当します。副作用の実行は、注入された依存サービス（`ImageClient` など）に委譲します。

### インフラ層 (Infrastructure/)

システムAPI（URLSession, CoreImage など）や外部依存関係へのアクセスを抽象化する層です。APIクライアント、イメージプロセッサー、キャッシュシステムなどがここに含まれます。

### 依存性注入 (DI)

インフラ層では TCA の依存性注入システム (@Dependency) を採用しています。

- 各サービスは Infrastructure/Interface/ に定義されたプロトコルに基づいて実装され、ドメイン層は具体的な実装詳細から分離されます
- 各サービスは、本番用の実装 (`liveValue`)、プレビュー用 (`previewValue`)、テスト用 (`testValue`) にそれぞれ提供されます
- さらに、デバッグ用に固定データを返すモック実装 (`mockValue`) も提供され、`CatBoard/Infrastructure/Mock/` に配置されています

## 効果 (Effects) システム

画像処理の効果は拡張性を考慮した設計になっています：

- **効果パイプライン**: 複数の効果を順番に適用できるパイプラインパターンを採用
- **プラグイン可能**: 新しい効果を簡単に追加できるように設計
- **設定可能**: 各効果にはパラメータを設定可能
- **非同期処理**: バックグラウンドスレッドでの処理を最適化

### 現在実装されている効果

- **不適切コンテンツフィルタリング**: 不適切な画像を検出し除外
- **色彩調整**: 色味、コントラスト、彩度などの調整
- **フィルター適用**: 様々な視覚フィルターの適用

## ディレクトリ構成

```
cat-board
├── .github/
│   └── workflows/
├── CBShared/
├── CatBoard/
│   ├── Preview Content/
│   ├── Assets.xcassets/
│   ├── Infrastructure/
│   ├── Domain/
│   │   ├── Coordinator/
│   │   └── Gallery/
│   ├── View/
│   │   └── CatImageGallery/
│   ├── Info.plist
│   └── CatBoardApp.swift
├── CatBoardTests/
├── CatBoardUITests/
├── .gitignore
├── .swiftformat
├── .swiftlint.yml
├── Mintfile
├── project.yml
└── README.md
```


## 外部API

このプロジェクトでは以下のAPIを利用しています。

### The Cat API

**概要:** 猫の画像や情報を取得するためのAPIです。<br>
**利用:** アプリケーション内で猫の画像を表示するために使用されます。<br>
**公式サイト:** https://thecatapi.com/

## CI/CD

このプロジェクトでは、GitHub Actions を利用して CI/CD パイプラインを構築しています。`.github/workflows/` ディレクトリ以下に設定ファイルが格納されています。

主なパイプライン (`ci-cd-pipeline.yml`) は、Pull Request や `main` ブランチへのプッシュ時に自動実行され、以下の主要な処理を行います:
- **コード品質チェック**: SwiftFormat と SwiftLint を実行します
- **ビルドとテスト**: アプリのビルドとユニット/UIテストを実行します
- **リリース準備**: `main` ブランチへのプッシュ時には、署名なしの `.xcarchive` を作成し、アーティファクトとして保存します

詳細なワークフローの説明は [CI_CD_WORKFLOWS.md](./.github/CI_CD_WORKFLOWS.md) を参照してください。

## 開発環境

プロジェクトのビルドと開発に必要なツールとそのバージョンは `Mintfile` で管理されています。
以下のコマンドで必要なツール (`SwiftFormat`, `SwiftLint`, `XcodeGen`) をインストールできます。

```bash
# Mintをインストール（未導入の場合）
brew install mint

# Mintfileに記載されたツールをインストール/アップデート
mint bootstrap

# Xcodeプロジェクトファイルの生成
mint run xcodegen generate
```

プロジェクトを開く前に、必ず `mint run xcodegen generate` を実行して `CatBoard.xcodeproj` を生成してください。

TCAなどの依存パッケージはSwift Package Managerによって自動的に管理されるため、Xcodeがプロジェクトを開く際に必要なパッケージを自動的にダウンロードします。

これにより、プロジェクトで使用している以下のツールが自動的にインストール、またはバージョン管理されます：
- SwiftLint (`0.59.1`)
- SwiftFormat (`0.55.5`)
- XcodeGen (`2.43.0`)
