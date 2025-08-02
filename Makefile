# --- Xcode操作 ---
#   make boot                      - ローカルシミュレータ（iPhone 16 Pro）を起動
#   make run-debug                 - デバッグビルドを作成し、ローカルシミュレータにインストール、起動
#   make run-release               - リリースビルドを作成し、ローカルシミュレータにインストール、起動
#   make clean                - Xcodeプロジェクトのビルドフォルダをクリーン
#   make resolve-pkg               - SwiftPMキャッシュ・依存関係・ビルドをリセット
#   make open                 - Xcodeでプロジェクトを開く
#
# --- ビルド ---
#   make build-test                - fastlaneでテスト用のビルドを実行
#   make archive                   - fastlaneでリリース用のアーカイブを作成
#
# --- テスト ---
#   make unit-test                 - fastlaneでユニットテストを実行
#   make ui-test                   - fastlaneでUIテストを実行
#   make package-test             - 全パッケージのテストを実行
#   make test-all                  - fastlaneで全テストを実行
#   make unit-test-without-building - ユニットテストを実行（ビルド済みアーティファクトを利用）
#   make ui-test-without-building  - UIテストを実行（ビルド済みアーティファクトを利用）
# 
# --- Code Style ---
#   make format                - コードをフォーマット
#   make format-check          - コードのフォーマットをチェック
#   make lint                  - lintを実行
#

# === Configuration ===
OUTPUT_DIR := build
PROJECT_FILE := CatBoardApp.xcodeproj
APP_SCHEME := CatBoardApp
UNIT_TEST_SCHEME := CatBoardTests
UI_TEST_SCHEME := CatBoardUITests


# === Derived paths ===
ARCHIVE_PATH := $(OUTPUT_DIR)/archives/CatBoardApp.xcarchive
UNIT_TEST_RESULTS := $(OUTPUT_DIR)/test-results/unit/TestResults.xcresult
UI_TEST_RESULTS := $(OUTPUT_DIR)/test-results/ui/TestResults.xcresult
DERIVED_DATA_PATH := $(OUTPUT_DIR)/test-results/DerivedData

# === Local Simulator ===
# .envファイルが存在すれば読み込む
ifneq (,$(wildcard ./.env))
	include .env
endif

# === App Bundle Identifier ===
APP_BUNDLE_ID := com.akitorahayashi.CatBoardApp

# === Boot simulator ===
.PHONY: boot
boot:
ifndef LOCAL_SIMULATOR_UDID
	$(error LOCAL_SIMULATOR_UDID is not set. Please set it in your .env)
endif
	@echo "🚀 Booting local simulator: $(LOCAL_SIMULATOR_NAME) (OS: $(LOCAL_SIMULATOR_OS), UDID: $(LOCAL_SIMULATOR_UDID))"
	@if xcrun simctl list devices | grep -q "$(LOCAL_SIMULATOR_UDID) (Booted)"; then \
		echo "⚡️ Simulator is already booted."; \
	else \
		xcrun simctl boot $(LOCAL_SIMULATOR_UDID); \
		echo "✅ Simulator booted."; \
	fi
	open -a Simulator
	@echo "✅ Local simulator boot command executed."

# === Run debug build ===
.PHONY: run-debug
run-debug:
	make boot
	@echo "Using Local Simulator: $(LOCAL_SIMULATOR_NAME) (OS: $(LOCAL_SIMULATOR_OS), UDID: $(LOCAL_SIMULATOR_UDID))"
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(OUTPUT_DIR)
	@mkdir -p $(OUTPUT_DIR)/debug
	@echo "✅ Previous outputs cleaned."
	@echo "🔨 Building debug..."
	@set -o pipefail && xcodebuild build \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-destination "platform=iOS Simulator,id=$(LOCAL_SIMULATOR_UDID)" \
		-derivedDataPath $(OUTPUT_DIR)/debug/DerivedData \
		-configuration Debug \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify
	@echo "✅ Debug build completed."
	@echo "📲 Installing debug build to simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(OUTPUT_DIR)/debug/DerivedData/Build/Products/Debug-iphonesimulator/CatBoardApp.app
	@echo "✅ Installed debug build."
	@echo "🚀 Launching app ($(APP_BUNDLE_ID)) on simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)
	@echo "✅ App launched."

# === Run release build ===
.PHONY: run-release
run-release:
	make boot
	@echo "Using Local Simulator: $(LOCAL_SIMULATOR_NAME) (OS: $(LOCAL_SIMULATOR_OS), UDID: $(LOCAL_SIMULATOR_UDID))"
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(OUTPUT_DIR)
	@mkdir -p $(OUTPUT_DIR)/release
	@echo "✅ Previous outputs cleaned."
	@echo "🔨 Building release..."
	@set -o pipefail && xcodebuild build \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-destination "platform=iOS Simulator,id=$(LOCAL_SIMULATOR_UDID)" \
		-derivedDataPath $(OUTPUT_DIR)/release/DerivedData \
		-configuration Release \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify
	@echo "✅ Release build completed."
	@echo "📲 Installing release build to simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(OUTPUT_DIR)/release/DerivedData/Build/Products/Release-iphonesimulator/CatBoardApp.app
	@echo "✅ Installed release build."
	@echo "🚀 Launching app ($(APP_BUNDLE_ID)) on simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)
	@echo "✅ App launched."

# === Clean project ===
.PHONY: clean
clean:
	@echo "🧹 Cleaning Xcode project build folder..."
	xcodebuild clean \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-destination "platform=iOS Simulator,id=$(LOCAL_SIMULATOR_UDID)"
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
	@echo "📖 Opening $(PROJECT_FILE) in Xcode..."
	@open $(PROJECT_FILE)
	@echo "✅ Project opened."

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
	@echo "🎨 Running swiftformat (mint)..."
	mint run swiftformat .
	@echo "✅ Code formatted."

.PHONY: format-check
format-check:
	@echo "🔍 Checking code format with swiftformat (mint)..."
	mint run swiftformat --lint .
	@echo "✅ Format check completed."

.PHONY: lint
lint:
	@echo "🔍 Running swiftlint (mint)..."
	mint run swiftlint --strict
	@echo "✅ Lint completed."