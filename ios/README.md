# 沖縄台風ナビ (iOS)

> **🚀 一番簡単**: プロジェクトルートで `./run-dev.sh` を実行してください。
> バックエンドがホットリロード付きで自動起動し、iOS側の起動手順も表示されます。

## 現在の状態（MVP）

- SwiftUI + MapKit を使用したアプリ
- 実データ（JTWC/JMA）優先取得 + デモフォールバック
- 保存場所のSQLite永続化 + 通知レベル（LOW/MEDIUM/HIGH/SEVERE）の設定・編集
- 地図上で通知レベルが高い場所を視覚的に強調
- クライアント側での実データを使った到達時間簡易計算
- タブ構成（地図 / 保存場所 / 設定） + データソース状況の可視化

## 実行手順（推奨）

**最も簡単な方法**（ホットリロード付き）:

```bash
# typhoon-risk-navi/ ディレクトリで実行
./run-dev.sh
```

これだけでバックエンドが watch モードで起動します（ファイル保存で自動リロード）。

その後:
1. Xcode で `ios/TyphoonRiskNavi` を開く
2. シミュレータ/実機でビルド＆実行（⌘R）

---

**手動で起動する場合**:

1. バックエンド
   ```bash
   cd backend
   bun run dev     # ← ホットリロード推奨
   ```

2. Xcodeで `TyphoonRiskNavi` を開いてビルド＆実行（iOS 17+ 推奨）

## アーキテクチャ（MVP）

- **MVVM**（ViewModelは1つで地図・場所・設定で共有）
- **APIClient**：デバイスID付きのネットワーク層
- **データ取得戦略**：実データ（`/api/typhoons/active`）優先 → 取得失敗時は `/api/demo/state` にフォールバック
- **リスク計算**：
  - バックエンドで風速半径を考慮した本格計算
  - 実データ取得時はクライアント側でも通知レベルに基づく到達時間を簡易計算
- **保存場所**：SQLiteによるデバイス別永続化
- **通知レベル**：LOW / MEDIUM / HIGH / SEVERE（設定・編集・クイック変更対応）

## 現在の完成度

- 地図タブ：実データ優先の台風進路 + 風速半径可視化 + 「実データ/デモデータ」表示
- 場所タブ：永続化された保存場所 + 通知レベル設定/編集 + リスク表示 + 優先度ソート + 現在地追加
- 実データ取得時、クライアント側で通知レベルに基づく到達時間を計算
- 設定タブで現在のデータソース状況を確認可能
- ViewModel 共有によるデータ整合

## リリースに向けた次の作業（優先順）

- **TestFlight配布向け最終整備**（現在最優先）
  - 多言語対応のXcode組み込み（詳細手順: `docs/Localization_Setup_Guide.md`）
  - スクリーンショット撮影（詳細ガイド: `docs/TestFlight_Screenshots_Guide.md`） — 沖縄の場所を中心に + 日本語/英語両方推奨
  - リリースノート最終化（`RELEASE_NOTES.md` を App Store Connect にコピー）
  - PrivacyInfo.xcprivacy のXcodeプロジェクトへの追加
  - バージョン/ビルド番号の設定
- プッシュ通知の基盤実装（通知レベルを活かしたアラート）
- 沖縄ユーザー向けのさらなる体験向上（事前登録場所の強化など）
- 予測精度モデルのさらなる進化（不確実性コーンなど）

## ビルド時の注意

### プライバシー関連（App Store提出必須）

1. **Xcode の Info 設定**で以下を追加：
   - Privacy - Location When In Use Usage Description
     > 台風の接近リスクを計算するために現在地を使用します。

2. **PrivacyInfo.xcprivacy** をプロジェクトに追加してください。
   - `ios/TyphoonRiskNavi/Resources/PrivacyInfo.xcprivacy` をXcodeのプロジェクトにドラッグ＆ドロップ
   - Target Membership を正しく設定

詳細はプロジェクトルートの `RELEASE_CHECKLIST.md` と `docs/TestFlight_Screenshots_Guide.md` を参照。

## 開発Tips

実データが取れない場合やデバッグしたい場合は、プロジェクトルートの `DEBUGGING.md` を参照してください。
