# 沖縄台風ナビ - App Store Connect 用メタデータ（初回TestFlight / v0.9）

このファイルに App Store Connect へ入力するすべての日本語テキストをまとめています。
コピー＆ペーストでそのまま使えます。

**アプリの方向性**: 沖縄県限定の台風予測・リスク可視化アプリです。

---

## 基本情報

**アプリ名 (日本語)**  
沖縄台風ナビ

**アプリ名 (English)**  
Okinawa Typhoon Navi

**サブタイトル (日本語)**（30文字以内推奨）  
沖縄のための実データ台風予測・リスク可視化

**サブタイトル (English)**  
Real-data typhoon prediction & risk for Okinawa

**プライマリカテゴリ**  
Weather

**セカンダリカテゴリ**  
Utilities

**価格**  
無料

**アプリ内課金**  
なし（初回）

---

## アプリの説明（日本語 / English）

**日本語（4000文字以内）**
沖縄県内の台風情報を、JTWC（米軍合同台風警報センター）と気象庁の実データで取得し、進路・風速半径（34kt/50kt/64kt）を地図上にわかりやすく表示します。

沖縄に住む・訪れる人のために特化。登録した場所（那覇、宜野湾、石垣、宮古など）ごとに「通知レベル」（LOW / MEDIUM / HIGH / SEVERE）を設定すると、強風域や暴風域が近づくまでの時間を、**台風自身のデータから自動で計算した動的減衰モデル**で予測します。

**English**
Typhoon information for Okinawa Prefecture is retrieved from real data by JTWC (Joint Typhoon Warning Center) and the Japan Meteorological Agency, and displayed clearly on the map showing track and wind radii (34kt/50kt/64kt).

Specialized for people living in or visiting Okinawa. Set a "notification level" (LOW / MEDIUM / HIGH / SEVERE) for each registered location (Naha, Ginowan, Ishigaki, Miyako, etc.) to predict when strong wind or violent wind areas will approach, using a **dynamic decay model calculated automatically from the typhoon’s own data**.

### 主な特徴
- 沖縄に最適化した地図表示
- 実データ優先取得（JTWC / JMA）
- 取得失敗時も自動でデモデータにフォールバック
- 動的減衰モデルによる沖縄上陸・接近時の現実的な到達時間予測
- 未来の風速半径も時間とともに自然に縮小して表示
- 保存場所の優先度管理（通知レベルによるソート・強調表示）

台風の多い沖縄で、事前にリスクを把握したい方に最適です。

---

## What's New（リリースノート）

沖縄限定アプリ「沖縄台風ナビ」としてリニューアル。

- 地図初期表示を沖縄本島周辺に最適化
- 沖縄の主要都市を意識したリスク管理
- 精度モデル「動的減衰」を導入（沖縄接近時のより現実的な予測）
- マップ上の未来風速半径も動的減衰を適用して表示
- 現在の予測モデルをツールバーで常に確認可能

---

## キーワード（100文字以内）

Okinawa,台風,typhoon,沖縄,リスク,risk,防災,disaster preparedness,JTWC,気象庁

---

## サポートURL
（未設定の場合はアプリ内のお問い合わせを想定）
https://example.com/support （後で実際のURLに置き換え）

## マーケティングURL
（任意）
https://example.com （後で設定）

---

## プライバシー

**データ収集の有無**  
- 位置情報（現在地追加機能で使用）
  - 収集されるが、第三者への共有なし
  - トラッキングなし

**連絡先情報**  
- なし

**位置情報**  
- アプリの機能提供のため（台風リスク計算）

---

## 年齢制限
4+

---

## 著作権
（あなたの名前または会社名）

---

## レビュー用メモ（App Store Connectの「レビュー用メモ」欄に）

このアプリは沖縄県民・沖縄在住者・沖縄を訪れる人を対象とした台風予測・リスク可視化ツールです。
沖縄に特化しており、実在の台風データ（JTWC/JMA）を使用しています。台風シーズン以外はデモデータで動作します。
TestFlightでのテストを想定しています。沖縄の場所を中心にリスク予測を行うアプリです。

---

## 提出時の注意点

- 初回は「TestFlightのみ」の内部テスト配布を推奨
- スクリーンショットは `docs/TestFlight_Screenshots_Guide.md` を参照
- リリースノートは同梱の `RELEASE_NOTES.md` を推奨
- PrivacyInfo.xcprivacy をXcodeプロジェクトに追加済みであることを確認

---

**このファイルは随時更新してください。**