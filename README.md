## プロジェクト概要

Cat Boardは、大量の猫の画像を効率的に処理して表示するためのiOSアプリケーションです。

スクリーニング処理には機械学習の処理が含まれるため、iPhone 16等の実機での検証を推奨します。シミュレータでは十分なパフォーマンスが得られません。

## アーキテクチャ

Cat BoardのアーキテクチャはXcodegenによるマルチモジュール構成と依存性の注入、Swift Concurrencyによる安全で高速な非同期処理のアルゴリズムが特徴的な設計です。

### 設計の特徴

- **マルチモジュール構成**
  - Xcodegen によるマルチモジュール構成
  - 疎結合
  - 依存関係の明確化

- **Swift Concurrency**
  - `async/await`による非同期処理の制御
  - `actor`による並行処理の安全性

- **SwiftData**
  - Cat APIから取得したurlをキャッシュ
  - プリフェッチしたurlをキャッシュ
  - 自動補充、削除機能

- **パフォーマンス最適化**
  - プリフェッチ、キャッシュによる高速な画像読み込み
  - バッチ処理による高速な画像表示
  - チャンク化したレイアウト + LazyVStack

- **依存性注入**
  - 依存性逆転の原則
  - テスト性の向上

## ディレクトリ構成

```
.
├── .github/
├── CatBoardApp/
├── CatAPIClient/
├── CatImageLoader/
├── CatImagePrefetcher/
├── CatImageScreener/
├── CatImageURLRepository/
├── CatURLImageModel/
├── CatBoardTests/
├── CatBoardUITests/
├── project.yml
├── Mintfile
├── .swiftlint.yml
├── .swiftformat
├── README.md
└── .gitignore
```

## 主要機能

### 1. レイアウト
LazyVStackとTieredGridLayoutを用いて、メモリ使用量を最適化しながらスムーズなスクロール体験を提供します。

### 2. Swift Concurrency
actor、MainActorを活用した並行処理の実装により、Badアクセスエラーを完全に排除しました。各コンポーネント（CatImagePrefetcher、CatImageURLRepository、CatImageLoader、CatImageScreener）はactorとして実装され、データ競合を防止しながら効率的な並列処理を実現します。UIの更新やSwiftDataの操作はMainActorで明示的に制御され、予測可能な状態管理を実現しています。

### 3. マルチレイヤーキャッシュシステム
Kingfisher、SwiftDataを活用したキャッシュシステムを実装。メモリキャッシュ（200MBに制限）、ディスクキャッシュ（500MBに制限、3日間有効）、SwiftDataによる取得したURL、プリフェッチしたURLの永続化を組み合わせ、より速い表示を実現します。表示時は `.memoryCacheExpiration(.seconds(3600))` と `.diskCacheExpiration(.expired)` を使い、表示後は短期でキャッシュを解放します。

### 4. 画像URLの自動管理
CatImageURLRepositoryが画像URLの在庫を監視し、表示可能なURLが一定枚数未満になった時点で自動的にCatAPIClientを通じて新しい画像URLを取得します。この補充処理はバックグラウンドで非同期実行され、効率的な補充を実現します。取得したURLはSwiftDataを通じて永続化され、次回起動時にも即座に利用可能な状態を維持します。

### 5. プリフェッチ
次に表示する画像を事前に用意するプリフェッチ機能があります。プリフェッチしたurlはSwiftDataに保存され、次回の起動時に使うことができます。これによって、別の機会にアプリを起動する際の画像の初期表示を高速化します。

### 6. スクリーニング
機械学習モデルですべての猫の画像を表示前にチェックし、不適切な画像を自動で除外し、安全な画像だけが表示されます。開発者向けに危険だと判断された特徴を持つ画像だけを表示するフラグもコード上に用意しています。

### 7. エラーハンドリングとリカバリー
各モジュールは独自のエラーハンドリングを実装し、ネットワークエラー、デコードエラー、メモリアクセスなどの異常系に対応。最大5回のリトライや10秒のタイムアウトの設定により、安定した動作を実現します。
  
## Unit Tests

- **GalleryViewModelTests**
  - 外部依存（ネットワーク、Screener）の分離
  - 画像表示の状態管理の検証
  - 初期画像の読み込みの検証
  - 追加画像の読み込みの検証
  - 最大画像数の制限の検証

- **CatImagePrefetcherTests**
  - プリフェッチの自動実行
    - プリフェッチ開始時に画像が取得できることの検証
    - 指定した枚数の画像を取得できることの検証
    - プリフェッチタスクの重複した実行の防止の検証

- **CatImageURLRepositoryTests**
  - APIからの画像URL取得
    - 要求した枚数の画像URLが取得できることの検証
  - キャッシュの制御
    - キャッシュから要求した枚数の画像URLを取得できることの検証
    - キャッシュに保存した画像URLが後で取り出した時に変わっていないことの検証
    - キャッシュが空の時に自動的にAPIから新しい画像URLを取得できることの検証
    - キャッシュの残数が少なくなった時に自動的に新しい画像URLを補充できることの検証
  - エラーハンドリング
    - APIエラー時の適切なエラー処理の検証
    - 自動補充をした時のAPIエラー処理の検証

- **CatImageScreenerTests**
  - スクリーナーの初期化とシングルトンパターンの検証
  - 画像処理の統合テスト（MockImageLoaderを使用した正常実行の検証）
