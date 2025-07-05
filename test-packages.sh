#!/bin/bash

set -e

echo "==============================="
echo "CatBoard パッケージテスト開始"
echo "==============================="

# 依存関係の順序を考慮したテスト対象モジュール
# 依存関係の少ないものから順にテストを実行
MODULES=("CatImageURLRepository" "CatImageScreener" "CatImagePrefetcher")

# 全体のテスト結果を記録
TOTAL_TESTS=0
FAILED_MODULES=()

echo "🔧 共通の依存関係を事前にresolveしています..."
echo "----------------------------------------"

# 共通の依存関係を事前にresolveしてキャッシュ
COMMON_DEPS=("CatURLImageModel" "CatAPIClient" "CatImageLoader")
for DEP in "${COMMON_DEPS[@]}"; do
    if [ -d "$DEP" ]; then
        echo "📦 $DEP をresolve中..."
        cd "$DEP"
        swift package resolve
        cd ..
    fi
done

echo ""
echo "🧪 各モジュールのテストを実行中..."

# 各モジュールのテストを実行（並列処理は避ける）
for MODULE in "${MODULES[@]}"; do
    echo ""
    echo "📦 $MODULE のテスト実行中..."
    echo "----------------------------------------"
    
    if cd "$MODULE" && swift test; then
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