## CI/CD

このプロジェクトでは、GitHub Actions を利用して CI/CD パイプラインを構築しています`.github/workflows/` ディレクトリ以下に設定ファイルが格納されています

主なパイプライン (`ci-cd-pipeline.yml`) は、Pull Request や `main` ブランチへのプッシュ時に自動実行され、以下の主要な処理を行います:
- **コード品質チェック** SwiftFormat と SwiftLint を実行します
- **ビルドとテスト** アプリのビルドとユニット/UIテストを実行します
- **リリース準備** `main` ブランチへのプッシュ時には、署名なしの `.xcarchive` を作成し、アーティファクトとして保存します

**リリースのプロセス**
- App Store Connect への配布や GitHub Releases への `.ipa` ファイルのアップロードは、**手動トリガー**によるワークフロー (`sign-and-distribute.yml`) で行います
- この手動ワークフローは、保存された署名なし `.xcarchive` をダウンロードし、必要な証明書とプロファイルで署名した後、配布を実行します

**主な機能**
- **Pull Request** PR作成・更新時に、コード品質チェック、ビルド、テストが自動実行されます
- **Mainブランチ** `main` ブランチへのプッシュ時にも同様のチェックが実行されます
- **リリース** `vX.Y.Z` 形式のタグがプッシュされると、リリース用のワークフロー (`release.yml`) が自動実行され、ビルド、署名、App Store Connect へのアップロード、GitHub Release の作成が行われます

詳細なワークフローの説明は [CI_CD_WORKFLOWS.md](./.github/CI_CD_WORKFLOWS.md) を参照してください

## リリース方法

1.  リリース対象のコミットを決定します
   - 最新の `main` ブランチのコミットをリリースする場合 (通常):
     ```bash
     git checkout main
     git pull origin main
     ```
   - 過去の特定のコミットをリリースする場合:
     リリースしたいコミットのハッシュ値を確認します`git log` や GitHub の履歴で探します
     ```bash
     git log --oneline --graph
     ```
     見つけたコミットハッシュ (例: `a1b2c3d`) を控えておきます

2. 決定したコミットに対してタグを作成します:
   - 最新の `main` にいる場合:
     ```bash
     git tag v1.0.0
     ```
   - 過去のコミット (`a1b2c3d`) に対して直接タグ付けする場合:
     ```bash
     git tag v1.0.1 a1b2c3d
     ```

3. 作成したタグをリモートリポジトリにプッシュします:
     ```bash
     git push origin v1.0.0
     ```
これにより、GitHub Actions の `release.yml` ワークフローが自動的にトリガーされ、App Store Connect へのアップロードと GitHub Release の作成が行われます

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
