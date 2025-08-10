# --- HELP ---
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "; OFS=" "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Load environment variables from .env file if it exists
-include .env

PROJECT_FILE   := CatBoardApp.xcodeproj
APP_BUNDLE_ID  := com.akitorahayashi.CatBoardApp
# --- PROJECT SPECIFIC PATHS ---
TEST_DERIVED_DATA_PATH := fastlane/build/test-results/DerivedData
DEBUG_APP_PATH    := $(TEST_DERIVED_DATA_PATH)/Debug/Build/Products/Debug-iphonesimulator/CatBoardApp.app
RELEASE_APP_PATH  := $(TEST_DERIVED_DATA_PATH)/Release/Build/Products/Release-iphonesimulator/CatBoardApp.app
SWIFTPM_CACHE_PATH := ~/Library/Caches/org.swift.swiftpm

.PHONY: setup
setup: ## Run all setup tasks
	bundle install
	mint bootstrap
	$(MAKE) gen-proj

.PHONY: gen-proj
gen-proj: ## Generate Xcode project
	@echo "🔧 Generating Xcode project with TEAM_ID: $(TEAM_ID)"
	@TEAM_ID=$(TEAM_ID) envsubst < project.envsubst.yml > project.yml
	mint run xcodegen generate

.PHONY: resolve-pkg
resolve-pkg: ## Reset SwiftPM cache, dependencies, and build
	@echo "🧹 Removing SwiftPM build and cache..."
	rm -rf .build
	rm -rf $(SWIFTPM_CACHE_PATH)
	@echo "✅ SwiftPM build and cache removed."
	@echo "🔄 Resolving Swift package dependencies..."
	xcodebuild -resolvePackageDependencies -project $(PROJECT_FILE)
	@echo "✅ Package dependencies resolved."

.PHONY: open
open: ## Open project in Xcode
	@xed $(PROJECT_FILE)

# --- LOCAL SIMULATOR ---
.PHONY: boot
boot: ## Boot local simulator
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

.PHONY: run-debug
run-debug: ## Build debug, install and launch on local simulator
	$(MAKE) boot
	@bundle exec fastlane build_for_testing
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(DEBUG_APP_PATH)
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)

.PHONY: run-release
run-release: ## Build release, install and launch on local simulator
	$(MAKE) boot
	@bundle exec fastlane build_for_testing configuration:Release
	xcrun simctl install $(LOCAL_SIMULATOR_UDID) $(RELEASE_APP_PATH)
	xcrun simctl launch $(LOCAL_SIMULATOR_UDID) $(APP_BUNDLE_ID)

# --- BUILD & SIGN ---
.PHONY: build-debug
build-debug: ## Build Debug archive (unsigned)
	bundle exec fastlane build_debug

.PHONY: build-release
build-release: ## Build Release archive (unsigned)
	bundle exec fastlane build_release

.PHONY: sign-debug-development
sign-debug-development: ## Sign debug archive for development
	bundle exec fastlane sign_debug_development

.PHONY: sign-release-development
sign-release-development: ## Sign release archive for development
	bundle exec fastlane sign_release export_method:development

.PHONY: sign-release-app-store
sign-release-app-store: ## Sign release archive for app_store
	bundle exec fastlane sign_release export_method:app_store

.PHONY: sign-release-ad-hoc
sign-release-ad-hoc: ## Sign release archive for ad_hoc
	bundle exec fastlane sign_release export_method:ad_hoc

.PHONY: sign-release-enterprise
sign-release-enterprise: ## Sign release archive for enterprise
	bundle exec fastlane sign_release export_method:enterprise

# --- TESTING ---
.PHONY: build-for-testing
build-for-testing: ## Build for testing
	bundle exec fastlane build_for_testing

.PHONY: unit-test
unit-test: ## Run unit tests
	bundle exec fastlane unit_test

.PHONY: unit-test-without-building
unit-test-without-building: ## Run unit tests without building
	bundle exec fastlane unit_test_without_building

.PHONY: ui-test
ui-test: ## Run UI tests
	bundle exec fastlane ui_test

.PHONY: ui-test-without-building
ui-test-without-building: ## Run UI tests without building
	bundle exec fastlane ui_test_without_building

.PHONY: package-test
package-test: ## Run Swift package tests
	bundle exec fastlane package_test

.PHONY: test-all
test-all: ## Run all tests (unit, UI, package)
	bundle exec fastlane test_all


# --- BUILD & SIGN ---
.PHONY: format
format: ## Format code
	mint run swiftformat .

.PHONY: format-check
format-check: ## Check code format
	mint run swiftformat --lint .

.PHONY: lint
lint:
	mint run swiftlint --strict