# 沖縄台風ナビ - 多言語対応（日本語 / English）Xcode組み込み手順

このドキュメントは、すでに作成済みのローカライズファイルをXcodeプロジェクトに正しく組み込み、2言語対応を完成させるための手順です。

## 1. 準備（すでに完了していること）

- `ios/TyphoonRiskNavi/Resources/ja.lproj/Localizable.strings`
- `ios/TyphoonRiskNavi/Resources/en.lproj/Localizable.strings`
- `ios/TyphoonRiskNavi/Resources/Localizable.swift`（ヘルパー）

これらが正しい場所に存在することを確認してください。

## 2. Xcodeプロジェクトへの追加手順

### Step 1: ローカライズファイルの追加

1. Xcodeでプロジェクトを開く。
2. 左側のProject Navigatorで `TyphoonRiskNavi` フォルダ（または Resources フォルダ）を右クリック → **Add Files to "TyphoonRiskNavi"...**
3. 以下の2つのフォルダを選択して追加：
   - `Resources/ja.lproj`
   - `Resources/en.lproj`
4. 追加ダイアログで以下の設定にする：
   - **Add to targets**: `TyphoonRiskNavi`（必ずチェック）
   - **Create groups** を選択（Create folder referencesではない）
5. `Localizable.swift` も同様にプロジェクトに追加（まだ追加されていない場合）。

### Step 2: Development Language の設定

1. Project Navigatorで一番上のプロジェクトファイル（青いアイコン）をクリック。
2. 中央の **Info** タブを選択。
3. **Localizations** セクションで：
   - **Development Language** を **Japanese** に設定。
4. **Localizations** リストに以下が表示されていることを確認：
   - Japanese
   - English

（表示されていない場合は「+」ボタンで追加可能）

### Step 3: アプリ名（Display Name）の多言語対応（推奨）

アプリ名も言語によって切り替えたい場合：

1. `Resources/ja.lproj` フォルダ内に `InfoPlist.strings` を作成。
2. 内容：

```strings
CFBundleDisplayName = "沖縄台風ナビ";
```

3. `Resources/en.lproj` フォルダ内に同じファイルを作成。

```strings
CFBundleDisplayName = "Okinawa Typhoon Navi";
```

4. 上記2ファイルをXcodeに追加（Step 1と同じ手順）。

### Step 4: ビルド設定の確認

1. Project設定 → **Build Settings** タブ。
2. 検索で "Localization" と入力。
3. **Base Internationalization** が有効になっていることを確認。
4. **Development Region** が `ja` または `Japanese` になっていることを推奨。

## 3. 動作確認方法

1. 実機またはシミュレータでアプリをビルド＆実行。
2. 設定アプリ → 一般 → 言語と地域 で：
   - **優先する言語** を **日本語** と **English** で切り替えてテスト。
3. アプリを強制終了 → 再起動して表示を確認。

確認すべき主な画面：
- タブバー（沖縄の台風 / My Locations / 設定）
- 地図画面の凡例
- 場所一覧の空の状態
- 設定画面の精度モデル説明
- エラーバナー

## 4. App Store Connect での言語設定

1. App Store Connect → アプリ → **アプリ情報**。
2. **プライマリ言語** を **日本語** に設定。
3. **追加言語** として **English (U.S.)** を追加。
4. 各言語ごとに以下を入力：
   - アプリ名
   - サブタイトル
   - 説明
   - キーワード
   - スクリーンショット（言語ごとに最適なものをアップロード）

**推奨**：
- 日本語スクリーンショット：日本語UIで撮影
- 英語スクリーンショット：英語UIで撮影

## 5. よくあるトラブルと対処

- **ローカライズが反映されない**：
  - シミュレータの場合：Device → Erase All Content and Settings を試す。
  - ビルドキャッシュをクリア（Product → Clean Build Folder）。

- **InfoPlist.strings が効かない**：
  - ファイルのエンコーディングが UTF-8 であることを確認。
  - 正しいターゲットに追加されているか確認。

- **一部の文字列だけ日本語のまま**：
  - その文字列がまだ `L10n` に移行されていない可能性あり。`Localizable.swift` と使用箇所を確認。

## 6. 次のステップ（推奨）

- 上記手順完了後、実機で日英切り替えテストを実施。
- スクリーンショットを両言語で撮影。
- TestFlightで内部テスターに両言語で使ってもらいフィードバックをもらう。

---

**このドキュメントは `docs/Localization_Setup_Guide.md` として保存されています。**

これで2言語対応の技術的な完成度はかなり高くなりました。
残りは「実際にXcodeで組み込んでテストする」作業のみです。

何かこの手順で不明点があれば、具体的に教えてください。すぐに補足します。