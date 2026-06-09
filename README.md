# 沖縄台風ナビ（Okinawa Typhoon Navi）

沖縄県内の台風進路・風速半径・リスクを地図上で視覚化し、登録した場所ごとの影響を予測する **iPhone 単体アプリ**。

**沖縄に住む人・訪れる人のための台風予測ツール**です。

---

## アーキテクチャ

**iPhone 単体で動作します。専用バックエンドはありません。**

```
┌──────────────────────────────┐
│      iPhone (アプリ本体)      │
│                              │
│  ┌────────────────────────┐  │
│  │ JTWCFetcher (HTTPS)    │──┼─→ https://www.metoc.navy.mil/jtwc/products/wpacprod.txt
│  │ JTWCParser (regex)     │  │
│  │ RiskCalculator (pure)  │  │
│  │ LocalLocationStore     │  │  保存場所は UserDefaults（端末ローカル）
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- **データソース**: 米軍 JTWC (Joint Typhoon Warning Center) の Western Pacific 警告テキストを iPhone から直接取得
- **保存場所**: 端末ローカル（UserDefaults JSON）。アプリ削除でクリアされる
- **リスク計算**: 端末上で完結。動的減衰モデル（4〜16%/日）も on-device
- **JTWC が取得失敗した場合**: 自動でデモデータにフォールバック（ステータスは UI に明示）

---

## ビルド方法（開発者向け）

### 初回セットアップ

```bash
# XcodeGen をインストール（未インストールの場合）
brew install xcodegen

# Xcode プロジェクトを生成
./ios/setup-xcode.sh
```

### 開いてビルド

```bash
open ios/TyphoonRiskNavi.xcodeproj
```

1. Signing & Capabilities で自分の Team ID を設定
2. シミュレータまたは実機を選択
3. ビルド＆実行（⌘R）

位置情報の利用目的（`NSLocationWhenInUseUsageDescription`）と
バンドル設定は `ios/TyphoonRiskNavi/Info.plist` にすでに記載済みです。

### テスト

```bash
xcodebuild test \
  -project ios/TyphoonRiskNavi.xcodeproj \
  -scheme TyphoonRiskNavi \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

XCTest で `JTWCParser` と `RiskCalculator` をカバーしています。

---

## 主な機能

- **沖縄特化**: 地図の初期表示が沖縄本島周辺に最適化
- **地図タブ**: 台風進路 + 予報円 + 風速半径（34kt/50kt/64kt）の同心円表示 + 凡例 + データソース表示
- **場所タブ**: 保存場所の永続化（端末ローカル） + リスクレベル表示 + 通知レベル設定（LOW/MEDIUM/HIGH/SEVERE） + タップで即時変更 + 長押しで編集 + 現在地ワンタップ追加 + 優先度ソート
- **JTWC 直接取得**: 米軍 JTWC の警告テキストを iPhone から直接取得しオンデバイスで解釈
- **動的減衰モデル**: 緯度進行と最大風速トレンドから 4〜16%/日 の減衰率を算出し、未来の風速半径を縮小表示
- **デモフォールバック**: JTWC が取れないときは自動でデモ台風を表示し、ステータスを UI に明示

---

## プロジェクト構成

```
typhoon-risk-navi/
├── ios/                          ← SwiftUI + MapKit（本体）
│   ├── project.yml               ← XcodeGen 設定
│   ├── setup-xcode.sh
│   └── TyphoonRiskNavi/
│       ├── Models/Models.swift
│       ├── ViewModels/TyphoonViewModel.swift
│       ├── Views/                ← MapView / LocationsView / SettingsView / etc.
│       ├── Services/
│       │   ├── JTWCFetcher.swift          ← HTTPS GET to JTWC
│       │   ├── JTWCParser.swift           ← regex-based pure parser
│       │   ├── RiskCalculator.swift       ← pure risk math
│       │   ├── LocalLocationStore.swift   ← UserDefaults JSON
│       │   └── DemoData.swift             ← フォールバック用デモ台風
│       ├── Resources/
│       │   ├── Localizable.swift, ja.lproj/, en.lproj/
│       │   └── PrivacyInfo.xcprivacy
│       └── Info.plist
├── ios/TyphoonRiskNaviTests/     ← XCTest（JTWCParser / RiskCalculator）
├── backend/                      ← レガシー Bun + Hono バックエンド（v1 では使用しない）
├── demo/                         ← 簡易HTMLデモ
├── AppStore_Metadata.md
├── RELEASE_CHECKLIST.md
├── RELEASE_NOTES.md
└── README.md
```

`backend/` は将来 Xweather 等の商用データソースを統合するときの予備として残してあります。v1 リリースでは使いません。

---

## アーキテクチャのポイント

- **iPhone 単体で完結**
  - JTWC の公開テキストを iPhone から直接 HTTPS で取得
  - 保存場所は端末ローカル（UserDefaults JSON）に永続化
  - 月額のホスティング費用なし、バックエンドのダウンタイムを気にする必要なし
- **失敗時の体験を明示**
  - JTWC が 403 を返したり台風シーズン外で 0 件のときは自動でデモにフォールバック
  - ステータス（実データ / デモデータ / 取得失敗）を Map・場所一覧・設定画面で常に表示
- **動的減衰モデル**
  - 北上速度（緯度進行）と最大風速の弱体化トレンドから減衰率を自動算出
  - 4〜16%/日の範囲にクランプ
  - UI に「精度モデル XX%」として常時表示

---

## リリース準備状況

- ✅ iPhone 単体で完結する on-device 構成
- ✅ Info.plist（位置情報 Usage / ローカライズ / HTTPS 厳密化）
- ✅ Privacy Manifest（Location + UserDefaults 宣言済）
- ✅ ローカライズ（日本語 + English）
- ✅ XcodeGen による再現可能なプロジェクト生成
- ✅ XCTest（JTWCParser / RiskCalculator）
- ⬜ アプリアイコン（1024×1024 から全サイズ展開、Bakery 等で生成）
- ⬜ Apple Developer Program 加入 + Team ID 設定
- ⬜ スクリーンショット撮影（`docs/TestFlight_Screenshots_Guide.md` 参照）
- ⬜ App Store Connect でアプリ登録 + 提出

詳細は以下を参照：
- `RELEASE_CHECKLIST.md` — リリース準備チェックリスト
- `AppStore_Metadata.md` — App Store Connect 入力用テキスト
- `RELEASE_NOTES.md` — リリースノート
- `docs/TestFlight_Screenshots_Guide.md` — スクリーンショット撮影ガイド
- `docs/Localization_Setup_Guide.md` — 多言語対応の Xcode 組み込み手順

---

## 技術スタック

- **iOS**: SwiftUI + MapKit + CoreLocation + Combine
- **永続化**: UserDefaults JSON（端末ローカル）
- **ネットワーク**: URLSession で JTWC HTTPS を直接叩く
- **テスト**: XCTest

---

## レガシー backend について

`backend/` ディレクトリは過去の構成（Bun + Hono + SQLite）の名残です。
v1 リリースでは iPhone 単体で動作するため使いません。`run-dev.sh` も同様です。

将来、Xweather などの商用ソース統合や、マルチデバイス同期を導入する際の再利用候補として残しています。

---

## サポート / お問い合わせ

**沖縄台風ナビ（Okinawa Typhoon Navi）** に関するお問い合わせ・不具合報告・機能要望は、以下のいずれかからお願いします。

- **メール**: admin@takaapps.com
- **GitHub Issues**: [このリポジトリの Issues](../../issues) からも報告可能です

回答までに数日いただく場合があります。返信は日本語または英語で行います。

### よくあるご質問

**Q. 「実データ取得失敗」と表示されます**
A. データソースの米軍 JTWC（Joint Typhoon Warning Center）が、現在進行中の台風がない期間や、ネットワーク状況によっては取得失敗を返すことがあります。その場合は自動でデモデータ表示に切り替わります。アプリの不具合ではなく、想定された挙動です。

**Q. 沖縄以外の地域でも使えますか？**
A. このアプリは沖縄県内の地点に最適化されています。沖縄県以外の場所も登録できますが、台風の進路予測表示の初期表示は沖縄本島周辺になります。

**Q. 通知機能はいつ実装されますか？**
A. 通知レベルの設定は将来のプッシュ通知機能のための準備として用意されています。次期バージョンでの実装を予定しています。

---

## プライバシー

本アプリは以下を**収集・送信しません**：

- 個人を特定できる情報
- 位置情報（ユーザーが明示的に「現在地を追加」を選択した場合のみ取得し、端末ローカルにのみ保存）
- アプリの使用状況の分析データ

外部サーバとの通信は、米軍 JTWC（https://www.metoc.navy.mil/jtwc/）からの台風データ取得時のみ発生します。

---

## ライセンス

このアプリケーションは個人開発のプロダクトです。
コードの利用については、別途お問い合わせください。
