#!/bin/bash
#
# 沖縄台風ナビ - Auto Run (Development Mode)
# ワンコマンドでバックエンドをホットリロード付きで起動します。
# プロセスが死んでも自動で再起動します（本番環境外での開発用）。
#
# Usage:
#   ./run-dev.sh
#

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
RESTART_DELAY=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌪️  沖縄台風ナビ - Auto Run (Development)${NC}"
echo "────────────────────────────────────────────────────────────"

# Check Bun
if ! command -v bun &> /dev/null; then
    echo -e "${RED}❌ Bun が見つかりません。${NC}"
    echo "   インストール: curl -fsSL https://bun.sh/install | bash"
    exit 1
fi

echo -e "${GREEN}✅ Bun: $(bun --version)${NC}"
echo ""

# Install dependencies if needed
if [ ! -d "$BACKEND_DIR/node_modules" ]; then
    echo -e "${YELLOW}📦 依存関係をインストール中...${NC}"
    (cd "$BACKEND_DIR" && bun install --silent)
    echo ""
fi

echo -e "${GREEN}🚀 バックエンドを watch モード + 自動復帰で起動します${NC}"
echo "   • ファイル変更 → ホットリロード"
echo "   • プロセス異常終了 → 自動再起動（${RESTART_DELAY}秒後）"
echo ""
echo -e "${YELLOW}📱 iOS アプリの起動手順:${NC}"
echo "   1. Xcode で typhoon-risk-navi/ios/TyphoonRiskNavi を開く"
echo "   2. iOS Simulator または実機を選択"
echo "   3. ビルド＆実行 (⌘R)"
echo ""
echo "   ※ 現在地追加機能を使う場合は Info.plist に"
echo "     'Privacy - Location When In Use Usage Description' を追加してください。"
echo ""
echo -e "${RED}🛑 完全に停止するには Ctrl+C を2回押してください。${NC}"
echo "────────────────────────────────────────────────────────────"
echo ""

cd "$BACKEND_DIR"

# Auto-restart loop
while true; do
    echo -e "${GREEN}[$(date '+%H:%M:%S')] サーバー起動中...${NC}"
    
    # Run with watch. We use a subshell so we can trap signals cleanly.
    bun run --watch index.ts &
    SERVER_PID=$!
    
    # Wait for the server process
    wait $SERVER_PID
    EXIT_CODE=$?
    
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] サーバーが終了しました (code: $EXIT_CODE)${NC}"
    
    # If user pressed Ctrl+C, the script itself will receive the signal and exit.
    # This loop only handles unexpected crashes.
    if [ $EXIT_CODE -eq 130 ] || [ $EXIT_CODE -eq 143 ]; then
        echo -e "${RED}停止シグナルを検知しました。終了します。${NC}"
        break
    fi
    
    echo -e "${YELLOW}${RESTART_DELAY}秒後に自動再起動します...${NC}"
    sleep $RESTART_DELAY
done

echo -e "${BLUE}Auto Run を終了しました。${NC}"
