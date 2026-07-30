# 沖縄台風ナビ (iOS)

> **iPhone / iPad 単体で動作します。専用バックエンドは不要です。**
> データ取得・リスク計算・保存場所の永続化はすべて端末上で完結します。

## 現在の状態

- SwiftUI + MapKit を使用した iPhone / iPad ネイティブアプリ
- 実データは気象庁 (JMA) を優先取得 → 失敗時は米軍 JTWC にフォールバック → どちらも不可ならデモ表示
- 保存場所の UserDefaults 永続化 + 通知レベル（LOW/MEDIUM/HIGH/SEVERE）の設定・編集
- 地図上で通知レベルが高い場所を視覚的に強調
- 端末上（オンデバイス）で風速半径・動的減衰モデルを使った到達時間・リスク計算
- タブ構成（地図 / 保存場所 / 設定） + データソース状況の可視化

## セットアップ & 実行

XcodeGen で `ios/project.yml` から Xcode プロジェクトを生成します。

```bash
# XcodeGen をインストール（未インストールの場合）
brew install xcodegen

# Xcode プロジェクトを生成
./ios/setup-xcode.sh
```

その後:

1. `open ios/TyphoonRiskNavi.xcodeproj`
2. Signing & Capabilities で自分の Team ID を設定
3. シミュレータ / 実機を選択してビルド＆実行（⌘R、iOS 17+）

位置情報の利用目的（`NSLocationWhenInUseUsageDescription`）は
`ios/TyphoonRiskNavi/Info.plist` にすでに記載済みです。

## アーキテクチャ

- **MVVM**：`TyphoonViewModel` を 1 つ用意し、地図・場所・設定の 3 タブで共有
- **データ取得戦略**：気象庁 (JMA) の `targetTc.json` → `specifications.json` を優先取得 → 失敗時のみ JTWC → どちらも不可ならデモデータにフォールバック
- **リスク計算**：`RiskCalculator`（純関数）で端末上で完結。風速半径 + 動的減衰モデル（4〜16%/日）から到達時間・リスクレベルを算出
- **保存場所**：`LocalLocationStore` による UserDefaults JSON 永続化（端末ローカル）
- **通知レベル**：LOW / MEDIUM / HIGH / SEVERE（設定・編集・クイック変更対応）

## テスト

```bash
xcodebuild test \
  -project ios/TyphoonRiskNavi.xcodeproj \
  -scheme TyphoonRiskNavi \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

XCTest で `JMAParser`・`JTWCParser`・`RiskCalculator` をカバーしています。

## ビルド時の注意

### プライバシー関連（App Store 提出必須）

- 位置情報の利用目的（`NSLocationWhenInUseUsageDescription`）は Info.plist に記載済み
- `PrivacyInfo.xcprivacy` は `ios/project.yml` の resources 経由でプロジェクトに含まれます

詳細はプロジェクトルートの `RELEASE_CHECKLIST.md` と `docs/TestFlight_Screenshots_Guide.md` を参照。

## 開発 Tips

実データが取れない場合やデバッグしたい場合は、プロジェクトルートの `DEBUGGING.md` を参照してください。
