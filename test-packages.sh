#!/bin/bash

set -e

echo "==============================="
echo "CatBoard パッケージテスト開始"
echo "==============================="

# テスト対象モジュール
MODULES=("CatImageScreener" "CatImagePrefetcher" "CatImageURLRepository")

# 全体のテスト結果を記録
TOTAL_TESTS=0
FAILED_MODULES=()

# 各モジュールのテストを実行
for MODULE in "${MODULES[@]}"; do
    echo ""
    echo "📦 $MODULE のテスト実行中..."
    echo "----------------------------------------"
    
    if cd "$MODULE" && swift test --parallel; then
        echo "✅ $MODULE のテスト完了"
        cd ..
    else
        echo "❌ $MODULE のテストが失敗しました"
        FAILED_MODULES+=("$MODULE")
        cd ..
    fi
done

# 結果の表示
echo ""
echo "==============================="
echo "テスト結果"
echo "==============================="

if [ ${#FAILED_MODULES[@]} -eq 0 ]; then
    echo "✅ 全てのモジュールのテストが成功しました！"
    exit 0
else
    echo "❌ 以下のモジュールでテストが失敗しました:"
    for FAILED in "${FAILED_MODULES[@]}"; do
        echo "  - $FAILED"
    done
    exit 1
fi 