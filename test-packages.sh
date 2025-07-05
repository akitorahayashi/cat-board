#!/bin/bash

set -e

echo "==============================="
echo "CatBoard パッケージテスト開始"
echo "==============================="

MODULES=("CatImageURLRepository" "CatImageScreener" "CatImagePrefetcher")

# 失敗したモジュールを記録
FAILED_MODULES=()

echo "🧪 各モジュールのテストを実行中..."

# 各モジュールのテストを実行
for MODULE in "${MODULES[@]}"; do
    echo ""
    echo "📦 $MODULE のテスト実行中..."
    echo "----------------------------------------"
    
    if (cd "$MODULE" && swift test); then
        echo "✅ $MODULE のテスト完了"
    else
        echo "❌ $MODULE のテストが失敗しました"
        FAILED_MODULES+=("$MODULE")
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