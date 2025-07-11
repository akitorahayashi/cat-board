# Makefile for CatBoardApp iOS Project
#
# [ユーザ向けコマンド]
# --- Xcodeの操作 ---
#   make boot                - ローカルシミュレータ（iPhone 16 Pro）を起動
#   make run-debug           - デバッグビルドを作成し、ローカルシミュレータにインストール、起動
#   make run-release         - リリースビルドを作成し、ローカルシミュレータにインストール、起動
#   make clean-proj          - Xcodeプロジェクトのビルドフォルダをクリーン
#
# --- ビルド関連 ---
#   make build-test          - テスト用ビルド（テスト実行前に必須）
#   make archive             - リリース用のアーカイブを作成
#
# --- テスト関連 ---
#   make unit-test           - ユニットテストを実行
#   make ui-test             - UIテストを実行
#   make test-all            - 全テストを実行
#
# [内部ワークフロー用コマンド]
#   make deps                - 依存関係をチェック
#   make find-test-artifacts - テストの成果物探索
#   make ci-build-for-testing - CI用: テスト用ビルド
#   make ci-unit-test        - CI用: ユニットテスト実行
#   make ci-ui-test          - CI用: UIテスト実行
#   make ci-archive          - CI用: アーカイブ作成
#
# === Configuration ===
OUTPUT_DIR := ./ci-outputs
PROJECT_FILE := CatBoardApp.xcodeproj
APP_SCHEME := CatBoardApp
UNIT_TEST_SCHEME := CatBoardTests
UI_TEST_SCHEME := CatBoardUITests

# CI用にシミュレータを選ぶ関数
select-simulator = $(shell \
    xcrun simctl list devices available | \
    grep -A1 "iPhone" | grep -Eo "[A-F0-9-]{36}" | head -n 1 \
)

# === Derived paths ===
ARCHIVE_PATH := $(OUTPUT_DIR)/production/archives/CatBoardApp.xcarchive
UNIT_TEST_RESULTS := $(OUTPUT_DIR)/test-results/unit/TestResults.xcresult
UI_TEST_RESULTS := $(OUTPUT_DIR)/test-results/ui/TestResults.xcresult
DERIVED_DATA_PATH := $(OUTPUT_DIR)/test-results/DerivedData

# === Local Simulator (ユーザの環境に合わせて変更してください) ===
# LOCAL_SIMULATOR_NAME := iPhone 16 Pro
# LOCAL_SIMULATOR_OS := 26.0
# LOCAL_SIMULATOR_UDID := 5495CFE4-9EBC-45C5-8F85-37E0E143B3CC

# === App Bundle Identifier (プロジェクト設定に合わせて確認・変更してください) ===
APP_BUNDLE_ID := com.example.catboardapp

# === Boot simulator ===
.PHONY: boot
boot:
ifndef LOCAL_SIMULATOR_UDID
	$(error LOCAL_SIMULATOR_UDID is not set. Please uncomment and set it in the Makefile)
endif
	@echo "🚀 Booting local simulator: $(LOCAL_SIMULATOR_NAME) (OS: $(LOCAL_SIMULATOR_OS), UDID: $(LOCAL_SIMULATOR_UDID))"
	xcrun simctl boot $(LOCAL_SIMULATOR_UDID) || echo "Simulator already booted."
	open -a Simulator
	@echo "✅ Local simulator boot command executed."

.PHONY: run-debug
run-debug:
ifndef LOCAL_SIMULATOR_UDID
	$(error LOCAL_SIMULATOR_UDID is not set. Please uncomment and set it in the Makefile)
endif
	@echo "Using Local Simulator: $(LOCAL_SIMULATOR_NAME) (OS: $(LOCAL_SIMULATOR_OS), UDID: $(LOCAL_SIMULATOR_UDID))"
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(OUTPUT_DIR)/debug
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
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(OUTPUT_DIR)/debug/DerivedData/Build/Products/Debug-iphonesimulator/$(APP_SCHEME).app
	@echo "✅ Installed debug build."
	@echo "🚀 Launching app ($(APP_BUNDLE_ID)) on simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)
	@echo "✅ App launched."

.PHONY: run-release
run-release:
ifndef LOCAL_SIMULATOR_UDID
	$(error LOCAL_SIMULATOR_UDID is not set. Please uncomment and set it in the Makefile)
endif
	@echo "Using Local Simulator: $(LOCAL_SIMULATOR_NAME) (OS: $(LOCAL_SIMULATOR_OS), UDID: $(LOCAL_SIMULATOR_UDID))"
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(OUTPUT_DIR)/release
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
	@echo "📲 リリースビルドをシミュレータ（$(LOCAL_SIMULATOR_NAME)）にインストールしています..."
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(OUTPUT_DIR)/release/DerivedData/Build/Products/Release-iphonesimulator/$(APP_SCHEME).app
	@echo "✅ Installed release build."
	@echo "🚀 Launching app ($(APP_BUNDLE_ID)) on simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)
	@echo "✅ App launched."

# === Build for testing ===
.PHONY: build-test
build-test:
ifeq ($(SIMULATOR_UDID),)
	$(eval SIMULATOR_ID := $(call select-simulator))
else
	$(eval SIMULATOR_ID := $(SIMULATOR_UDID))
endif
	@echo "Using Simulator UDID: $(SIMULATOR_ID)"
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(DERIVED_DATA_PATH) $(UNIT_TEST_RESULTS) $(UI_TEST_RESULTS)
	@mkdir -p $(DERIVED_DATA_PATH) $(shell dirname $(UNIT_TEST_RESULTS)) $(shell dirname $(UI_TEST_RESULTS)) $(shell dirname $(ARCHIVE_PATH))
	@echo "✅ Previous outputs cleaned."
	@echo "🔨 Building for testing..."
	@set -o pipefail && xcodebuild build-for-testing \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-destination "platform=iOS Simulator,id=$(SIMULATOR_ID)" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-configuration Debug \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify
	@echo "✅ Build for testing completed."

# === Archive ===
.PHONY: archive
archive: deps generate-project
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(ARCHIVE_PATH) $(OUTPUT_DIR)/archives/DerivedData # Keep other outputs if any
	@mkdir -p $(shell dirname $(ARCHIVE_PATH)) $(OUTPUT_DIR)/archives/DerivedData
	@echo "✅ Previous outputs cleaned."
	@echo "📦 Building archive..."
	@set -o pipefail && xcodebuild \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-configuration Release \
		-destination "generic/platform=iOS" \
		-archivePath $(ARCHIVE_PATH) \
		-derivedDataPath $(OUTPUT_DIR)/archives/DerivedData \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO \
		archive \
		| xcbeautify
	@echo "🔍 Verifying archive contents..."
	@ARCHIVE_APP_PATH="$(ARCHIVE_PATH)/Products/Applications/$(APP_SCHEME).app"; \
	if [ ! -d "$$ARCHIVE_APP_PATH" ]; then \
		echo "❌ Error: '$(APP_SCHEME).app' not found in expected archive location ($$ARCHIVE_APP_PATH)"; \
		echo "Archive directory: $(ARCHIVE_PATH)"; \
		exit 1; \
	fi
	@echo "✅ Archive build completed and verified."

# === Unit tests ===
.PHONY: unit-test
unit-test: find-test-artifacts # Ensure build artifacts are available
ifeq ($(SIMULATOR_UDID),)
	$(eval SIMULATOR_ID := $(call select-simulator))
else
	$(eval SIMULATOR_ID := $(SIMULATOR_UDID))
endif
	@echo "Using Simulator UDID: $(SIMULATOR_ID)"
	@echo "🧪 Running Unit Tests..."
	@rm -rf $(UNIT_TEST_RESULTS)
	@set -o pipefail && xcodebuild test-without-building \
		-project $(PROJECT_FILE) \
		-scheme $(UNIT_TEST_SCHEME) \
		-destination "platform=iOS Simulator,id=$(SIMULATOR_ID)" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-enableCodeCoverage NO \
		-resultBundlePath $(UNIT_TEST_RESULTS) \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify
	@if [ ! -d "$(UNIT_TEST_RESULTS)" ]; then \
		echo "❌ Error: Unit test result bundle not found at $(UNIT_TEST_RESULTS)"; \
		exit 1; \
	fi
	@echo "✅ Unit tests completed. Results: $(UNIT_TEST_RESULTS)"

# === UI tests ===
.PHONY: ui-test
ui-test: find-test-artifacts # Ensure build artifacts are available
ifeq ($(SIMULATOR_UDID),)
	$(eval SIMULATOR_ID := $(call select-simulator))
else
	$(eval SIMULATOR_ID := $(SIMULATOR_UDID))
endif
	@echo "Using Simulator UDID: $(SIMULATOR_ID)"
	@echo "🧪 Running UI Tests..."
	@rm -rf $(UI_TEST_RESULTS)
	@set -o pipefail && xcodebuild test-without-building \
		-project $(PROJECT_FILE) \
		-scheme $(UI_TEST_SCHEME) \
		-destination "platform=iOS Simulator,id=$(SIMULATOR_ID)" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-enableCodeCoverage NO \
		-resultBundlePath $(UI_TEST_RESULTS) \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify
	@if [ ! -d "$(UI_TEST_RESULTS)" ]; then \
		echo "❌ Error: UI test result bundle not found at $(UI_TEST_RESULTS)"; \
		exit 1; \
	fi
	@echo "✅ UI tests completed. Results: $(UI_TEST_RESULTS)"

# === All tests ===
.PHONY: test-all
test-all: build-test unit-test ui-test
	@echo "✅ All tests completed."

# === Dependencies check ===
.PHONY: deps
deps:
	@echo "🔍 Checking dependencies..."
	@command -v mint >/dev/null 2>&1 || { echo "❌ Error: Mint not installed. Please install: brew install mint"; exit 1; }
	@command -v xcbeautify >/dev/null 2>&1 || { echo "❌ Error: xcbeautify not installed. Please install: brew install xcbeautify"; exit 1; }
	@command -v xcodegen >/dev/null 2>&1 || { echo "❌ Error: xcodegen not installed. Please install: brew install xcodegen"; exit 1; }
	@echo "✅ All required dependencies are available."

# === Find existing artifacts ===
.PHONY: find-test-artifacts
find-test-artifacts:
	@echo "🔍 Finding existing build artifacts in $(DERIVED_DATA_PATH)..."
	@if [ -d "$(DERIVED_DATA_PATH)" ] && find "$(DERIVED_DATA_PATH)" -name "$(APP_SCHEME).app" -type d -print -quit | grep -q "."; then \
		echo "✅ Found existing build artifacts."; \
	else \
		echo "ℹ️ No existing build artifacts found. This is expected if 'make build-test' or 'make ci-build-for-testing' hasn't run yet, or if derived data is in a different location."; \
	fi

.PHONY: clean-proj
clean-proj:
ifndef LOCAL_SIMULATOR_UDID
	$(error LOCAL_SIMULATOR_UDID is not set. Please uncomment and set it in the Makefile)
endif
	@echo "🧹 Cleaning Xcode project build folder..."
	xcodebuild clean \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-destination "platform=iOS Simulator,id=$(LOCAL_SIMULATOR_UDID)"
	@echo "✅ Project build folder cleaned."

# === CI specific targets ===
.PHONY: ci-build-for-testing
ci-build-for-testing: deps generate-project
	$(MAKE) build-test SIMULATOR_UDID=$(SIMULATOR_UDID)

.PHONY: ci-unit-test
ci-unit-test: deps generate-project
	$(MAKE) unit-test SIMULATOR_UDID=$(SIMULATOR_UDID)

.PHONY: ci-ui-test
ci-ui-test: deps generate-project
	$(MAKE) ui-test SIMULATOR_UDID=$(SIMULATOR_UDID)

# Generate Xcode Project (Helper for CI, can be used locally too)
.PHONY: generate-project
generate-project: deps
	@echo "⚙️ Generating Xcode project using xcodegen..."
	mint run xcodegen generate
	@echo "✅ Xcode project generated."

# === Package Tests ===
.PHONY: test-packages
test-packages: deps
	@echo "==============================="
	@echo "CatBoard パッケージテスト開始"
	@echo "==============================="
	@MODULES=("CatImageURLRepository" "CatImageScreener" "CatImagePrefetcher"); \
	FAILED_MODULES=""; \
	echo "🧪 各モジュールのテストを実行中..."; \
	for MODULE in $${MODULES[@]}; do \
		echo ""; \
		echo "📦 $$MODULE のテスト実行中..."; \
		echo "----------------------------------------"; \
		if (cd "$$MODULE" && swift test); then \
			echo "✅ $$MODULE のテスト完了"; \
		else \
			echo "❌ $$MODULE のテストが失敗しました"; \
			FAILED_MODULES="$$FAILED_MODULES $$MODULE"; \
		fi; \
	done; \
	echo ""; \
	echo "==============================="; \
	echo "テスト結果"; \
	echo "==============================="; \
	if [ -z "$$FAILED_MODULES" ]; then \
		echo "✅ 全てのモジュールのテストが成功しました！"; \
		exit 0; \
	else \
		echo "❌ 以下のモジュールでテストが失敗しました:"; \
		for FAILED in $$FAILED_MODULES; do \
			echo "  - $$FAILED"; \
		done; \
		exit 1; \
	fi
