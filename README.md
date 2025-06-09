## プロジェクト概要

![Icon-App-60x60@3x](https://github.com/user-attachments/assets/f6822898-f8c6-43c7-a476-9de7eddbfd3d)

Cat Board は、大量の猫の画像を効率的に処理して表示するための iOS アプリケーションです。

スクリーニング処理には機械学習の処理が含まれるため、iPhone 16 等の実機での検証を推奨します。シミュレータでは十分なパフォーマンスが得られません。

## アーキテクチャ

Cat Board のアーキテクチャは SPM・Xcodegen によるマルチモジュール構成と依存性の注入、Swift Concurrency を使った安全で高速な非同期処理のアルゴリズムが特徴的な設計です。

### 設計の特徴

- **マルチモジュール構成**
  - Xcodegen での xcodeproj の管理
  - SwiftPM でのモジュールの管理

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

- **GalleryViewModelTests**: ViewModelの画像読み込み、追加取得、クリア、最大枚数制限機能、スクリーニングとの連携を検証
- **CatImagePrefetcherTests**: プリフェッチ機能の自動実行、重複実行の防止、スクリーニングとの連携を検証
- **CatImageURLRepositoryTests**: 画像URLの取得、キャッシュ、自動補充機能を検証
- **CatImageScreenerTests**: スクリーニング機能を検証

## UI Tests

- アプリ起動時の初期画面表示とスクロールビュー、最初の画像の存在確認
- リフレッシュボタンの動作と画像再表示、エラー状態の非発生確認
- エラー状態の表示、リトライボタンの動作、正常状態への復帰確認
- スクロール操作による追加画像取得の確認
