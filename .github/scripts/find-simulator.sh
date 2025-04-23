#!/bin/bash

# コマンドが失敗したらすぐに終了する
set -e

PROJECT_NAME="CatBoard.xcodeproj"
APP_SCHEME="CatBoard"
UI_TEST_SCHEME="CatBoardUITests"
SIMULATOR_NAME_PATTERN="iPhone"

echo "Searching for valid '$SIMULATOR_NAME_PATTERN' simulator destination for scheme '$APP_SCHEME'...'" >&2

# アプリスキームの有効な iOS Simulator の宛先リストを取得
DESTINATIONS=$(xcodebuild -showdestinations -project "$PROJECT_NAME" -scheme "$APP_SCHEME")

# '$SIMULATOR_NAME_PATTERN' を含む iOS Simulator の宛先を検索
SIMULATOR_INFO=$(echo "$DESTINATIONS" | grep "platform:iOS Simulator" | grep "name:$SIMULATOR_NAME_PATTERN" | head -1)

if [ -z "$SIMULATOR_INFO" ]; then
  echo "エラー: '$APP_SCHEME' スキームで '$SIMULATOR_NAME_PATTERN' を含む有効な iOS Simulator 宛先が見つかりません。" >&2
  echo "利用可能な宛先:" >&2
  echo "$DESTINATIONS" | grep "platform:iOS Simulator" | cat >&2
  exit 1
fi

# 宛先情報から ID と名前を抽出
SIMULATOR_ID=$(echo "$SIMULATOR_INFO" | sed -nE 's/.*id:([0-9A-F-]+).*/\1/p')
SIMULATOR_NAME=$(echo "$SIMULATOR_INFO" | sed -nE 's/.*name:([^,]+).*/\1/p' | xargs)

if [ -z "$SIMULATOR_ID" ]; then
    echo "エラー: シミュレーター情報からIDを抽出できませんでした: $SIMULATOR_INFO" >&2
    exit 1
fi

echo "Found simulator: $SIMULATOR_NAME (ID: $SIMULATOR_ID)" >&2

# UIテストのスキームで宛先が存在するか検証
echo "Verifying destination for UI test scheme '$UI_TEST_SCHEME'...'" >&2
# Check if *any* iOS Simulator destination exists for the UI test scheme
DESTINATION_UI_FOUND=$(xcodebuild -showdestinations -project "$PROJECT_NAME" -scheme "$UI_TEST_SCHEME" | grep "platform:iOS Simulator" || echo "not found")
if [[ "$DESTINATION_UI_FOUND" == "not found" ]]; then
    echo "エラー: '$UI_TEST_SCHEME' スキームに有効な iOS Simulator 宛先が見つかりません。" >&2
    echo "UIテストスキームで利用可能な宛先:" >&2
    xcodebuild -showdestinations -project "$PROJECT_NAME" -scheme "$UI_TEST_SCHEME" | cat >&2
    exit 1
fi

# すべてのチェックをパスしたらIDを出力
echo "Using simulator: $SIMULATOR_NAME (ID: $SIMULATOR_ID)" >&2 # ログ情報を標準エラー出力へ
echo "$SIMULATOR_ID" # IDを標準出力へ 