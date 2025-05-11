#!/bin/bash

# コマンドが失敗したらすぐに終了する
set -e

# 利用可能な最初の iOS シミュレータを検索
echo "Finding the first available iOS simulator... (xcrun simctl)" >&2

# xcrun simctl から利用可能なデバイスリストを JSON 形式で取得
SIMCTL_OUTPUT=$(xcrun simctl list devices available --json)
if [ $? -ne 0 ] || [ -z "$SIMCTL_OUTPUT" ]; then
    echo "Error: Failed to get simulator list from xcrun simctl." >&2
    exit 1
fi

# jq がインストールされているか確認 (簡易チェック)
if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found. Please install jq (e.g., brew install jq)." >&2
    exit 1
fi

# jqクエリ: 利用可能な最新の iOS シミュレータの UDID を取得
JQ_QUERY='.devices | to_entries | map(select(.key | startswith("com.apple.CoreSimulator.SimRuntime.iOS"))) | sort_by(.key) | reverse | .[0].value[] | select(.isAvailable == true and (.name | contains("iPhone"))) | .udid'

# 利用可能な最初の UDID を取得
SIMULATOR_UDID=$(echo "$SIMCTL_OUTPUT" | jq -r "$JQ_QUERY" | head -n 1)

if [ -z "$SIMULATOR_UDID" ]; then
    echo "Error: No available iOS simulator found." >&2
    echo "--- simctl output excerpt (iOS Simulators) --- " >&2
    echo "$SIMCTL_OUTPUT" | jq '.devices | to_entries[] | select(.key | startswith("com.apple.CoreSimulator.SimRuntime.iOS"))' || echo "(jq extraction failed)" >&2
    echo "----------------------------------------------" >&2
    exit 1
fi

# 見つかったシミュレータの名前をログ出力用に取得 (失敗しても続行)
SIMULATOR_NAME=$(echo "$SIMCTL_OUTPUT" | jq -r --arg udid "$SIMULATOR_UDID" '.devices | .[] | .[] | select(.udid == $udid) | .name' | head -n 1 || echo "(Failed to get name)")
echo "Simulator found: $SIMULATOR_NAME (UDID: $SIMULATOR_UDID)" >&2

# UDID を標準出力へ
echo "$SIMULATOR_UDID" 