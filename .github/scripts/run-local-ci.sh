#!/bin/bash
#
#   $ .github/scripts/run-local-ci.sh                # 全てのテスト・アーカイブを実行
#   $ .github/scripts/run-local-ci.sh --all-tests    # ユニットテストとUIテストのみ実行
#   $ .github/scripts/run-local-ci.sh --unit-test    # ユニットテストのみ実行
#   $ .github/scripts/run-local-ci.sh --ui-test      # UIテストのみ実行
#   $ .github/scripts/run-local-ci.sh --archive-only # アーカイブのみ実行
#   $ .github/scripts/run-local-ci.sh --test-without-building # 既存ビルド成果物でテストのみ

set -euo pipefail

# === Configuration ===
OUTPUT_DIR="ci-outputs"
TEST_RESULTS_DIR="$OUTPUT_DIR/test-results"
TEST_DERIVED_DATA_DIR="$TEST_RESULTS_DIR/DerivedData"
PRODUCTION_DIR="$OUTPUT_DIR/production"
ARCHIVE_DIR="$PRODUCTION_DIR/archives"
PRODUCTION_DERIVED_DATA_DIR="$ARCHIVE_DIR/DerivedData"
EXPORT_DIR="$PRODUCTION_DIR/Export"
PROJECT_FILE="CatBoardApp.xcodeproj"
APP_SCHEME="CatBoardApp"
UNIT_TEST_SCHEME="CatBoardTests"
UI_TEST_SCHEME="CatBoardUITests"
WATCH_APP_SCHEME="CatBoardApp"

# === Default Flags ===
run_unit_tests=false
run_ui_tests=false
run_archive=false
skip_build_for_testing=false
run_all=true # 引数が指定されていない場合は、デフォルトですべてのステップを実行

# === Argument Parsing ===
specific_action_requested=false
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --all-tests)
      run_unit_tests=true
      run_ui_tests=true
      run_archive=false
      run_all=false
      specific_action_requested=true
      shift
      ;;
    --unit-test)
      run_unit_tests=true
      run_archive=false
      run_all=false
      specific_action_requested=true
      shift
      ;;
    --ui-test)
      run_ui_tests=true
      run_archive=false
      run_all=false
      specific_action_requested=true
      shift
      ;;
    --archive-only)
      run_unit_tests=false
      run_ui_tests=false
      run_archive=true
      run_all=false
      specific_action_requested=true
      shift
      ;;
    --test-without-building)
      skip_build_for_testing=true
      run_archive=false
      run_all=false
      specific_action_requested=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# 特定のアクションが要求されなかった場合は、すべてを実行
if [ "$specific_action_requested" = false ]; then
  run_unit_tests=true
  run_ui_tests=true
  run_archive=true
fi

# === Helper Functions ===
step() {
  echo ""
  echo "──────────────────────────────────────────────────────────────────────"
  echo "▶️  $1"
  echo "──────────────────────────────────────────────────────────────────────"
}

success() {
  echo "✅ $1"
}

fail() {
  echo "❌ Error: $1" >&2 # エラーを標準エラー出力へリダイレクト
  exit 1
}

# === Main Script ===

# 前回の出力をクリーンアップし、ディレクトリを作成 (ビルドをスキップしない場合のみ)
if [ "$skip_build_for_testing" = false ] || [ "$run_archive" = true ]; then
  step "Cleaning previous outputs and creating directories"
  echo "Removing old $OUTPUT_DIR directory if it exists..."
  rm -rf "$OUTPUT_DIR"
  echo "Creating directories..."
  mkdir -p "$TEST_RESULTS_DIR/unit" "$TEST_RESULTS_DIR/ui" "$TEST_DERIVED_DATA_DIR" \
           "$ARCHIVE_DIR" "$PRODUCTION_DERIVED_DATA_DIR" "$EXPORT_DIR"
  success "Directories created under $OUTPUT_DIR."
else
  step "Skipping cleanup and directory creation (reusing existing build outputs)"
  # ビルドせずにテストを実行する場合、テストに必要なディレクトリが存在することを確認
  if [ "$run_unit_tests" = true ] || [ "$run_ui_tests" = true ]; then
      if [ ! -d "$TEST_DERIVED_DATA_DIR" ]; then
          fail "Cannot run tests without building: DerivedData directory not found at $TEST_DERIVED_DATA_DIR. Run a full build first."
      fi
      mkdir -p "$TEST_RESULTS_DIR/unit" "$TEST_RESULTS_DIR/ui"
      success "Required test directories exist or created."
  fi
fi

# === XcodeGen ===
# プロジェクト生成 (アーカイブ時 or ビルドを伴うテスト実行時)
if [[ "$skip_build_for_testing" = false && ( "$run_archive" = true || "$run_unit_tests" = true || "$run_ui_tests" = true ) ]]; then
  step "Generating Xcode project using XcodeGen"
  # mint の存在確認
  if ! command -v mint &> /dev/null; then
      fail "Mint がインストールされていません。先に mint をインストールしてください。(brew install mint)"
  fi
  # xcodegen の存在確認 (なければ bootstrap)
  if ! mint list | grep -q 'XcodeGen'; then
      echo "mint で XcodeGen が見つかりません。'mint bootstrap' を実行します..."
      mint bootstrap || fail "mint パッケージの bootstrap に失敗しました。"
  fi
  echo "Running xcodegen..."
  mint run xcodegen || fail "XcodeGen によるプロジェクト生成に失敗しました。"
  # プロジェクトファイルの存在確認
  if [ ! -d "$PROJECT_FILE" ]; then
    fail "XcodeGen 実行後、プロジェクトファイル '$PROJECT_FILE' が見つかりません。"
  fi
  success "Xcode project generated successfully."
fi

if [ "$run_unit_tests" = true ] || [ "$run_ui_tests" = true ]; then
  step "Running Tests"

  # シミュレータを検索
  echo "Finding simulator..."
  FIND_SIMULATOR_SCRIPT="./.github/scripts/find-simulator.sh"

  # スクリプトが実行可能であることを確認
  if [ ! -x "$FIND_SIMULATOR_SCRIPT" ]; then
    echo "Making $FIND_SIMULATOR_SCRIPT executable..."
    chmod +x "$FIND_SIMULATOR_SCRIPT"
    if [ $? -ne 0 ]; then
        fail "Failed to make $FIND_SIMULATOR_SCRIPT executable."
    fi
  fi

  # スクリプトを実行し、IDと終了コードをキャプチャ
  SIMULATOR_ID=$("$FIND_SIMULATOR_SCRIPT")
  SCRIPT_EXIT_CODE=$?

  if [ $SCRIPT_EXIT_CODE -ne 0 ]; then
      fail "$FIND_SIMULATOR_SCRIPT failed with exit code $SCRIPT_EXIT_CODE."
  fi

  if [ -z "$SIMULATOR_ID" ]; then
    fail "Could not find a suitable simulator ($FIND_SIMULATOR_SCRIPT returned empty ID)."
  fi
  echo "Using Simulator ID: $SIMULATOR_ID"
  success "Simulator selected."

  # テスト用にビルド (スキップされていない場合)
  if [ "$skip_build_for_testing" = false ]; then
    echo "Building for testing..."
    set -o pipefail && xcodebuild build-for-testing \
      -project "$PROJECT_FILE" \
      -scheme "$APP_SCHEME" \
      -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -derivedDataPath "$TEST_DERIVED_DATA_DIR" \
      -configuration Debug \
      -skipMacroValidation \
      CODE_SIGNING_ALLOWED=NO \
    | xcbeautify
    success "Build for testing completed."
  else
      echo "Skipping build for testing as requested (--test-without-building)."
      if [ ! -d "$TEST_DERIVED_DATA_DIR/Build/Intermediates.noindex/XCBuildData" ]; then
         fail "Cannot skip build: No existing build artifacts found in $TEST_DERIVED_DATA_DIR. Run a full build first."
      fi
      success "Using existing build artifacts."
  fi

  # Unitテストを実行
  if [ "$run_unit_tests" = true ]; then
    # Swift Package Managerのテストを実行
    step "Running Swift Package Manager Tests"
    echo "Running SPM tests..."
    swift test || fail "Swift Package Manager tests failed"
    success "Swift Package Manager tests completed successfully"

    echo "Running Xcode Unit Tests..."
    set -o pipefail && xcodebuild test-without-building \
      -project "$PROJECT_FILE" \
      -scheme "$UNIT_TEST_SCHEME" \
      -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -derivedDataPath "$TEST_DERIVED_DATA_DIR" \
      -enableCodeCoverage NO \
      -resultBundlePath "$TEST_RESULTS_DIR/unit/TestResults.xcresult" \
      CODE_SIGNING_ALLOWED=NO \
    | xcbeautify --report junit --report-path "$TEST_RESULTS_DIR/unit/junit.xml"

    # Unitテスト結果バンドルの存在を確認
    echo "Verifying unit test results bundle..."
    if [ ! -d "$TEST_RESULTS_DIR/unit/TestResults.xcresult" ]; then
      fail "Unit test result bundle not found at $TEST_RESULTS_DIR/unit/TestResults.xcresult"
    fi
    success "Unit test result bundle found at $TEST_RESULTS_DIR/unit/TestResults.xcresult"
  fi

  # UIテストを実行
  if [ "$run_ui_tests" = true ]; then
    echo "Running UI Tests..."
    set -o pipefail && xcodebuild test-without-building \
      -project "$PROJECT_FILE" \
      -scheme "$UI_TEST_SCHEME" \
      -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -derivedDataPath "$TEST_DERIVED_DATA_DIR" \
      -enableCodeCoverage NO \
      -resultBundlePath "$TEST_RESULTS_DIR/ui/TestResults.xcresult" \
      CODE_SIGNING_ALLOWED=NO \
    | xcbeautify --report junit --report-path "$TEST_RESULTS_DIR/ui/junit.xml"

    # UIテスト結果バンドルの存在を確認
    echo "Verifying UI test results bundle..."
    if [ ! -d "$TEST_RESULTS_DIR/ui/TestResults.xcresult" ]; then
      fail "UI test result bundle not found at $TEST_RESULTS_DIR/ui/TestResults.xcresult"
    fi
    success "UI test result bundle found at $TEST_RESULTS_DIR/ui/TestResults.xcresult"
  fi
fi

# --- Build for Production (Archive) ---
if [ "$run_archive" = true ]; then
  step "Building for Production (Unsigned)"

  ARCHIVE_PATH="$ARCHIVE_DIR/CatBoard.xcarchive"
  ARCHIVE_APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_SCHEME.app"

  # アーカイブビルド
  echo "Building archive..."
  set -o pipefail && xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$APP_SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$PRODUCTION_DERIVED_DATA_DIR" \
    -skipMacroValidation \
    CODE_SIGNING_ALLOWED=NO \
    archive \
  | xcbeautify
  success "Archive build completed."

  # アーカイブ内容を検証
  echo "Verifying archive contents..."
  if [ ! -d "$ARCHIVE_APP_PATH" ]; then
    echo "Error: '$APP_SCHEME.app' not found in expected archive location ($ARCHIVE_APP_PATH)."
    echo "--- Listing Archive Contents (on error) ---"
    ls -lR "$ARCHIVE_PATH" || echo "Archive directory not found or empty."
    fail "Archive verification failed."
  fi
  success "Archive content verified."
fi

step "Local CI Check Completed Successfully!"