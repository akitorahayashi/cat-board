SHELL := /bin/bash

# Makefile for CatBoardApp iOS Project
#
# [ユーザ向けコマンド]
# --- Xcodeの操作 ---
#   make boot                - ローカルシミュレータ（iPhone 16 Pro）を起動
#   make run-debug           - デバッグビルドを作成し、ローカルシミュレータにインストール、起動
#   make run-release         - リリースビルドを作成し、ローカルシミュレータにインストール、起動
#   make clean-proj          - Xcodeプロジェクトのビルドフォルダをクリーン
#   make resolve-pkg         - SwiftPMキャッシュ・依存関係・ビルドをリセット
#   make open-proj           - Xcodeでプロジェクトを開く
#   make test-packages       - CatBoard内の全てのローカルパッケージテストを実行
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
#   make find-test-artifacts - テストの成果物探索
#
# === Configuration ===
OUTPUT_DIR := build
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

# === Local Simulator ===
LOCAL_SIMULATOR_NAME := iPhone 16 Pro
LOCAL_SIMULATOR_OS := 26.0
LOCAL_SIMULATOR_UDID := 5495CFE4-9EBC-45C5-8F85-37E0E143B3CC

# === App Bundle Identifier ===
APP_BUNDLE_ID := com.akitorahayashi.CatBoardApp

# === Boot simulator ===
.PHONY: boot
boot:
	@echo "🚀 Booting local simulator: $(LOCAL_SIMULATOR_NAME) (OS: $(LOCAL_SIMULATOR_OS), UDID: $(LOCAL_SIMULATOR_UDID))"
	@if xcrun simctl list | grep -A1 "$(LOCAL_SIMULATOR_UDID)" | grep -q "Booted"; then \
		echo "⚡️ Simulator is already booted."; \
	else \
		xcrun simctl boot $(LOCAL_SIMULATOR_UDID); \
		echo "✅ Simulator booted."; \
	fi
	open -a Simulator
	@echo "✅ Local simulator boot command executed."

.PHONY: run-debug
run-debug:
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
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(OUTPUT_DIR)/debug/DerivedData/Build/Products/Debug-iphonesimulator/$(APP_SCHEME).app
	@echo "✅ Installed debug build."
	@echo "🚀 Launching app ($(APP_BUNDLE_ID)) on simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)
	@echo "✅ App launched."

.PHONY: run-release
run-release:
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
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(OUTPUT_DIR)/release/DerivedData/Build/Products/Release-iphonesimulator/$(APP_SCHEME).app
	@echo "✅ Installed release build."
	@echo "🚀 Launching app ($(APP_BUNDLE_ID)) on simulator ($(LOCAL_SIMULATOR_NAME))..."
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)
	@echo "✅ App launched."

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

# === Open Xcode Project ===
.PHONY: open-proj
open-proj:
	@echo "🚀 Opening Xcode project: $(PROJECT_FILE)"
	open $(PROJECT_FILE)
	@echo "✅ Xcode project opened."
	

# === Package Tests ===
.PHONY: test-packages
test-packages:
	@set -e; 
	echo "🧪 Running package tests..."; 
	echo "📦 Testing CatImageURLRepository..."; 
	(cd CatImageURLRepository && set -o pipefail && swift test | xcbeautify); 
	echo "📦 Testing CatImageScreener..."; 
	(cd CatImageScreener && set -o pipefail && swift test | xcbeautify); 
	echo "📦 Testing CatImagePrefetcher..."; 
	(cd CatImagePrefetcher && set -o pipefail && swift test | xcbeautify); 
	echo "✅ All package tests passed."


# === Build for testing ===

.PHONY: build-test
build-test:
ifeq ($(SIMULATOR_UDID),)
	$(eval SIMULATOR_ID := $(call select-simulator,$(APP_SCHEME)))
else
	$(eval SIMULATOR_ID := $(SIMULATOR_UDID))
endif
	@echo "Using Simulator UDID: $(SIMULATOR_ID)"
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(OUTPUT_DIR)
	@mkdir -p $(OUTPUT_DIR)/test-results/unit $(OUTPUT_DIR)/test-results/ui $(OUTPUT_DIR)/archives
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
archive:
	@echo "🧹 Cleaning previous outputs..."
	@rm -rf $(OUTPUT_DIR)
	@mkdir -p $(OUTPUT_DIR)/archives
	@echo "✅ Previous outputs cleaned."
	@echo "📦 Building archive..."
	@set -o pipefail && xcodebuild \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-configuration Release \
		-destination "generic/platform=iOS Simulator" \
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
unit-test:
	$(eval SIMULATOR_RAW := $(call select-simulator,$(UNIT_TEST_SCHEME)))
	@echo "Using Simulator UDID: $(SIMULATOR_RAW)"
	@echo "🧪 Running Unit Tests..."
	@rm -rf $(UNIT_TEST_RESULTS)
	@set -o pipefail && xcodebuild test-without-building \
		-project $(PROJECT_FILE) \
		-scheme $(UNIT_TEST_SCHEME) \
		-destination "platform=iOS Simulator,id=$(word 1,$(subst |, ,$(SIMULATOR_RAW)))" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-enableCodeCoverage NO \
		-resultBundlePath $(UNIT_TEST_RESULTS) \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify
	@if [ ! -d "$(UNIT_TEST_RESULTS)" ]; then \
		echo "❌ Error: Unit test result bundle not found"; \
		exit 1; \
	fi
	@echo "✅ Unit tests completed. Results: $(UNIT_TEST_RESULTS)"

# === UI tests ===
.PHONY: ui-test
ui-test:
	$(eval SIMULATOR_RAW := $(call select-simulator,$(UI_TEST_SCHEME)))
	@echo "Using Simulator UDID: $(SIMULATOR_RAW)"
	@echo "🧪 Running UI Tests..."
	@rm -rf $(UI_TEST_RESULTS)
	@set -o pipefail && xcodebuild test-without-building \
		-project $(PROJECT_FILE) \
		-scheme $(UI_TEST_SCHEME) \
		-destination "platform=iOS Simulator,id=$(word 1,$(subst |, ,$(SIMULATOR_RAW)))" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-enableCodeCoverage NO \
		-resultBundlePath $(UI_TEST_RESULTS) \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify
	@if [ ! -d "$(UI_TEST_RESULTS)" ]; then \
		echo "❌ Error: UI test result bundle not found"; \
		exit 1; \
	fi
	@echo "✅ UI tests completed. Results: $(UI_TEST_RESULTS)"

# === All tests ===
.PHONY: test-all
test-all: find-test-artifacts unit-test ui-test
	@echo "✅ All tests completed."

# === Find existing artifacts ===
.PHONY: find-test-artifacts
find-test-artifacts:
	@echo "🔍 Finding existing build artifacts..."
	@FOUND=false; \
	for path in "$(OUTPUT_DIR)/test-results/DerivedData" "DerivedData" "$$HOME/Library/Developer/Xcode/DerivedData"; do \
		if [ -d "$$path" ] && find "$$path" -name "$(APP_SCHEME).app" -type d | head -1 | grep -q "$(APP_SCHEME).app"; then \
			echo "✅ Found existing build artifacts at: $$path"; \
			if [ "$$path" != "$(OUTPUT_DIR)/test-results/DerivedData" ]; then \
				echo "🔗 Linking artifacts to $(OUTPUT_DIR)/test-results/DerivedData"; \
				mkdir -p $(OUTPUT_DIR)/test-results; \
				ln -sfn "$$path" "$(OUTPUT_DIR)/test-results/DerivedData"; \
			fi; \
			FOUND=true; \
			break; \
		fi; \
	done; \
	if [ "$$FOUND" = false ]; then \
		echo "❌ Error: No existing build artifacts found. Please run 'make build-test' first."; \
		exit 1; \
	fi

.PHONY: clean-proj
clean-proj:
	@echo "🧹 Cleaning Xcode project build folder..."
	xcodebuild clean \
		-project $(PROJECT_FILE) \
		-scheme $(APP_SCHEME) \
		-destination "platform=iOS Simulator,id=$(LOCAL_SIMULATOR_UDID)"
	@echo "✅ Project build folder cleaned."
