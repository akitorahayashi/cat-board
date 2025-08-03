# --- Xcode操作 ---
#   make gen-proj                  - Xcodeプロジェクトを生成
#   make boot                      - ローカルシミュレータ（iPhone 16 Pro）を起動
#   make run-debug                 - デバッグビルドを作成し、ローカルシミュレータにインストール、起動（Fastlane経由）
#   make run-release               - リリースビルドを作成し、ローカルシミュレータにインストール、起動（Fastlane経由）
#   make clean                - Xcodeプロジェクトのビルドフォルダをクリーン
#   make resolve-pkg               - SwiftPMキャッシュ・依存関係・ビルドをリセット
#   make open                 - Xcodeでプロジェクトを開く
#
# --- ビルド ---
#   make build-test                - テスト用のビルドを実行
#   make archive                   - リリース用のアーカイブを作成
#
# --- テスト ---
#   make unit-test                 - ユニットテストを実行
#   make ui-test                   - UIテストを実行
#   make testp-package             - 全パッケージのテストを実行
#   make test-all                  - 全テストを実行
#   make unit-test-without-building - ユニットテストを実行（ビルド済みアーティファクトを利用）
#   make ui-test-without-building  - UIテストを実行（ビルド済みアーティファクトを利用）
# 
# --- Code Style ---
#   make format                - コードをフォーマット
#   make format-check          - コードのフォーマットをチェック
#   make lint                  - lintを実行
#

# === Local Simulator ===
# .envファイルが存在すれば読み込む
ifneq (,$(wildcard ./.env))
	include .env
endif

# === Configuration ===
OUTPUT_DIR := build
PROJECT_FILE := CatBoardApp.xcodeproj
APP_SCHEME := CatBoardApp
APP_BUNDLE_ID := com.akitorahayashi.CatBoardApp

# === Generate Xcode project ===
.PHONY: gen-proj
gen-proj:
	@echo "🔧 Generating Xcode project with TEAM_ID: $(TEAM_ID)"
	@TEAM_ID=$(TEAM_ID) envsubst < project.envsubst.yml > project.yml
	mint run xcodegen generate

# === Boot simulator ===
.PHONY: boot
boot:
ifndef LOCAL_SIMULATOR_UDID
	$(error LOCAL_SIMULATOR_UDID is not set. Please set it in your .env)
endif
	@echo "🚀 Booting local simulator: UDID: $(LOCAL_SIMULATOR_UDID)"
	@if xcrun simctl list devices | grep -q "$(LOCAL_SIMULATOR_UDID) (Booted)"; then \
		echo "⚡️ Simulator is already booted."; \
	else \
		xcrun simctl boot $(LOCAL_SIMULATOR_UDID); \
		echo "✅ Simulator booted."; \
	fi
	open -a Simulator

# === Run debug build ===
.PHONY: run-debug
run-debug:
	$(MAKE) boot
	@bundle exec fastlane build_debug
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) fastlane/build/debug/DerivedData/Build/Products/Debug-iphonesimulator/CatBoardApp.app
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)

# === Run release build ===
.PHONY: run-release
run-release:
	$(MAKE) boot
	@bundle exec fastlane build_release
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) fastlane/build/release/DerivedData/Build/Products/Release-iphonesimulator/CatBoardApp.app
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)

# === Clean project ===
.PHONY: clean
clean:
	@echo "🧹 Cleaning Xcode project build folder..."
	xcodebuild clean \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME)
	@echo "✅ Project build folder cleaned."

# === Resolve & Reset SwiftPM/Xcode Packages ===
.PHONY: resolve-pkg
resolve-pkg:
	@echo "🧹 Removing SwiftPM build and cache..."
	rm -rf .build
	rm -rf ~/Library/Caches/org.swift.swiftpm
	@echo "✅ SwiftPM build and cache removed."
	@echo "🔄 Resolving Swift package dependencies..."
	xcodebuild -resolvePackageDependencies -project $(PROJECT_FILE)
	@echo "✅ Package dependencies resolved."

# === Open project in Xcode ===
.PHONY: open
open:
	@open $(PROJECT_FILE)

# === Build for testing ===
.PHONY: build-test
build-test:
	bundle exec fastlane build_for_testing

# === Archive ===
.PHONY: archive
archive:
	bundle exec fastlane archive

# === Unit tests ===
.PHONY: unit-test
unit-test:
	bundle exec fastlane unit_test

# === UI tests ===
.PHONY: ui-test
ui-test:
	bundle exec fastlane ui_test
# === Package tests ===
.PHONY: package-test
package-test:
	bundle exec fastlane package_test

# === Unit tests without building ===
.PHONY: unit-test-without-building
unit-test-without-building:
	bundle exec fastlane unit_test_without_building

# === UI tests without building ===
.PHONY: ui-test-without-building
ui-test-without-building:
	bundle exec fastlane ui_test_without_building

# === All tests ===
.PHONY: test-all
test-all:
	bundle exec fastlane test_all

# === Code Style ===
.PHONY: format
format:
	mint run swiftformat .

.PHONY: format-check
format-check:
	mint run swiftformat --lint .

.PHONY: lint
lint:
	mint run swiftlint --strict