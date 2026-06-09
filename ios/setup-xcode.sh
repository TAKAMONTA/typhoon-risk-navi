#!/bin/bash
#
# 沖縄台風ナビ - Xcode プロジェクト生成スクリプト
#
# XcodeGen を使って ios/project.yml から TyphoonRiskNavi.xcodeproj を生成します。
#
# Usage:
#   ./ios/setup-xcode.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🛠️  Xcode プロジェクト生成${NC}"
echo "────────────────────────────────────────────────────────────"

# XcodeGen を確認
if ! command -v xcodegen &> /dev/null; then
    echo -e "${YELLOW}⚠️  XcodeGen が未インストール${NC}"
    if command -v brew &> /dev/null; then
        echo "  Homebrew でインストールします..."
        brew install xcodegen
    elif command -v mint &> /dev/null; then
        echo "  Mint でインストールします..."
        mint install yonaskolb/XcodeGen
    else
        echo -e "${RED}❌ Homebrew も Mint も見つかりません。${NC}"
        echo "   いずれかをインストールしてから再実行してください："
        echo "   - Homebrew: https://brew.sh"
        echo "   - Mint:     https://github.com/yonaskolb/Mint"
        exit 1
    fi
fi

echo -e "${GREEN}✅ XcodeGen: $(xcodegen --version 2>&1 | head -1)${NC}"

# 既存プロジェクトをバックアップ（あれば）
if [ -d "TyphoonRiskNavi.xcodeproj" ]; then
    BACKUP="TyphoonRiskNavi.xcodeproj.bak.$(date +%s)"
    echo -e "${YELLOW}📦 既存の .xcodeproj をバックアップ → $BACKUP${NC}"
    mv TyphoonRiskNavi.xcodeproj "$BACKUP"
fi

# 生成
echo -e "${BLUE}🎯 project.yml から Xcode プロジェクトを生成中...${NC}"
xcodegen generate --spec project.yml

if [ -d "TyphoonRiskNavi.xcodeproj" ]; then
    echo ""
    echo -e "${GREEN}✅ 生成完了: ios/TyphoonRiskNavi.xcodeproj${NC}"
    echo ""
    echo "次のステップ:"
    echo "  1. open TyphoonRiskNavi.xcodeproj"
    echo "  2. Signing & Capabilities でチーム ID を設定"
    echo "  3. backend を起動（プロジェクトルートで ./run-dev.sh）"
    echo "  4. シミュレータでビルド＆実行（⌘R）"
    echo ""
    echo "ℹ️  本番デプロイ時は ios/TyphoonRiskNavi/Info.plist の APIBaseURL を"
    echo "    HTTPS の本番 URL に変更してください。"
else
    echo -e "${RED}❌ プロジェクト生成に失敗しました${NC}"
    exit 1
fi
