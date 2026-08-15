# みんなの体感リポート Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 沖縄10エリアの台風体感を、色・表情・定型フレーズの選択式で投稿・閲覧できる「みんな」タブを追加する。

**Architecture:** CloudKit Public Database をストアとし、`MoodPostStore` protocol で抽象化してテストは InMemory 実装で行う。集約（エリア別の最頻レベル）は純関数 `MoodAggregator` がクライアント側で計算する。既存コードへの変更は MainTabView へのタブ追加と L10n キー1個のみ。

**Tech Stack:** SwiftUI / CloudKit（標準フレームワークのみ、外部依存なし）/ XCTest / xcodegen

**Spec:** `docs/superpowers/specs/2026-08-15-area-mood-posts-design.md`

## Global Constraints

- iOS Deployment Target: **17.0** / Swift: **5.10**（project.yml 準拠）
- 外部 SPM パッケージを追加しない（現状ゼロを維持）
- プロジェクト定義は `ios/project.yml`。変更したら `cd ios && xcodegen generate` で .xcodeproj を再生成する。新規 Swift ファイルの追加時も再生成が必要
- UI 文言は日本語のみ。新規 View 内はハードコード可。ただしタブラベルだけは既存3タブに合わせ L10n キー（`tab.mood`）を使う
- 免責表示は一字一句この通り: **「みんなの体感（公式情報ではありません）」**
- 集約の時間窓 **3時間** / 取得上限 **200件** / 連投制限 **10分に1回** / 自動更新 **5分間隔**
- 精密な位置情報・ユーザー識別子を CloudKit に保存しない（area / level / phraseID の3フィールドのみ）
- テストは XCTest、`@testable import TyphoonRiskNavi`。テスト実行コマンド（ios/ ディレクトリから）:
  ```bash
  xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
  ```
  単一テストクラスは `-only-testing:TyphoonRiskNaviTests/<クラス名>` を付ける
- コミットは各タスク末尾で行う。実装は main ではなくフィーチャーブランチ（`feat/area-mood-posts`。スペックコミット済みの `feat/area-mood-posts-spec` から分岐してよい）

---

### Task 1: OkinawaArea enum とエリア割当

**Files:**
- Create: `ios/TyphoonRiskNavi/Services/OkinawaArea.swift`
- Test: `ios/TyphoonRiskNaviTests/OkinawaAreaTests.swift`

**Interfaces:**
- Consumes: `OkinawaMunicipality`（`ios/TyphoonRiskNavi/Services/OkinawaMunicipalityCatalog.swift` の既存 struct。`id: String` を持つ）
- Produces: `enum OkinawaArea: String, CaseIterable, Codable, Identifiable`（10ケース、`displayName: String`、`static let municipalityAreaMap: [String: OkinawaArea]`）、`OkinawaMunicipality.area: OkinawaArea?`（computed property）

- [ ] **Step 1: 失敗するテストを書く**

`ios/TyphoonRiskNaviTests/OkinawaAreaTests.swift` を作成:

```swift
import XCTest
@testable import TyphoonRiskNavi

/// 10エリア区分（気象庁 class15 準拠）と41自治体の割当のテスト。
/// スペック: docs/superpowers/specs/2026-08-15-area-mood-posts-design.md §4
final class OkinawaAreaTests: XCTestCase {

    func testCatalogHas41Municipalities() {
        XCTAssertEqual(OkinawaMunicipalityCatalog.all.count, 41)
    }

    /// 41自治体すべてがちょうど1エリアに属する（漏れなし）。
    func testAll41MunicipalitiesHaveAnArea() {
        for municipality in OkinawaMunicipalityCatalog.all {
            XCTAssertNotNil(
                municipality.area,
                "\(municipality.name) (\(municipality.id)) にエリアが割り当てられていない"
            )
        }
    }

    /// 対応表にカタログ外の孤児キーがない（typo 検出）。
    func testMappingHasNoOrphanEntries() {
        let catalogIDs = Set(OkinawaMunicipalityCatalog.all.map(\.id))
        for key in OkinawaArea.municipalityAreaMap.keys {
            XCTAssertTrue(catalogIDs.contains(key), "対応表のキー \(key) がカタログに存在しない")
        }
    }

    /// 全10エリアに1自治体以上が割り当てられている。
    func testEveryAreaHasAtLeastOneMunicipality() {
        let assignedAreas = Set(OkinawaArea.municipalityAreaMap.values)
        XCTAssertEqual(assignedAreas, Set(OkinawaArea.allCases))
    }

    /// 気象庁 class15 区分との照合（判断が分かれる自治体のスポットチェック）。
    func testJMAClass15SpotChecks() {
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["naha"], .naha)
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["urasoe"], .south)      // 浦添は気象庁区分では南部
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["iheya"], .north)       // 伊平屋は離島だが本島北部
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["ie"], .north)          // 伊江島も本島北部
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["tokashiki"], .keramaAguni)
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["tarama"], .miyako)     // 多良間は宮古
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["taketomi"], .ishigaki) // 竹富町は石垣
        XCTAssertEqual(OkinawaArea.municipalityAreaMap["minamidaito"], .daito)
    }

    func testDisplayNames() {
        XCTAssertEqual(OkinawaArea.keramaAguni.displayName, "慶良間・粟国")
        XCTAssertEqual(OkinawaArea.naha.displayName, "那覇")
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

まず `cd ios && xcodegen generate` で新規ファイルを .xcodeproj に反映してから:

Run（ios/ から）: `xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TyphoonRiskNaviTests/OkinawaAreaTests 2>&1 | tail -5`
Expected: **ビルドエラー**（`OkinawaArea` が未定義）

- [ ] **Step 3: 実装を書く**

`ios/TyphoonRiskNavi/Services/OkinawaArea.swift` を作成:

```swift
import Foundation

/// 沖縄の体感投稿エリア。気象庁の細分区域（class15）に従って10区分。
/// 慶良間・粟国は気象庁が本島中南部の中でも別区域として扱うため独立させる
/// （那覇に混ぜると4村の体感が市街の投稿に埋もれる）。
/// スペック: docs/superpowers/specs/2026-08-15-area-mood-posts-design.md §4
enum OkinawaArea: String, CaseIterable, Codable, Identifiable {
    case naha
    case south
    case central
    case north
    case keramaAguni
    case kumejima
    case miyako
    case ishigaki
    case yonaguni
    case daito

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .naha: return "那覇"
        case .south: return "南部"
        case .central: return "中部"
        case .north: return "北部"
        case .keramaAguni: return "慶良間・粟国"
        case .kumejima: return "久米島"
        case .miyako: return "宮古"
        case .ishigaki: return "石垣"
        case .yonaguni: return "与那国"
        case .daito: return "大東"
        }
    }

    /// 自治体ID（OkinawaMunicipalityCatalog の id）→ エリアの対応表。
    /// 気象庁 area.json の class15 区分に従う。浦添は地理的には中部寄りだが気象庁区分では南部。
    static let municipalityAreaMap: [String: OkinawaArea] = [
        "naha": .naha,
        // 南部
        "urasoe": .south, "itoman": .south, "tomigusuku": .south, "nanjo": .south,
        "nishihara": .south, "yonabaru": .south, "haebaru": .south, "yaese": .south,
        // 中部
        "ginowan": .central, "okinawa-city": .central, "uruma": .central, "yomitan": .central,
        "kadena": .central, "chatan": .central, "kitanakagusuku": .central, "nakagusuku": .central,
        // 北部（伊平屋・伊是名・伊江は離島だが気象庁も本島北部に含める）
        "nago": .north, "kunigami": .north, "ogimi": .north, "higashi": .north,
        "nakijin": .north, "motobu": .north, "ie": .north, "onna": .north,
        "ginoza": .north, "kin": .north, "iheya": .north, "izena": .north,
        // 慶良間・粟国諸島
        "tokashiki": .keramaAguni, "zamami": .keramaAguni, "aguni": .keramaAguni, "tonaki": .keramaAguni,
        // その他離島
        "kumejima": .kumejima,
        "miyakojima": .miyako, "tarama": .miyako,
        "ishigaki": .ishigaki, "taketomi": .ishigaki,
        "yonaguni": .yonaguni,
        "minamidaito": .daito, "kitadaito": .daito,
    ]
}

extension OkinawaMunicipality {
    /// この自治体が属する体感エリア。カタログ全41自治体が対応表に載っていることは
    /// OkinawaAreaTests が全数検査で保証する。
    var area: OkinawaArea? {
        OkinawaArea.municipalityAreaMap[id]
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: Step 2 と同じコマンド
Expected: PASS（6テスト）

- [ ] **Step 5: コミット**

```bash
git add ios/TyphoonRiskNavi/Services/OkinawaArea.swift ios/TyphoonRiskNaviTests/OkinawaAreaTests.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: add the ten mood areas mapped from all 41 municipalities"
```

---

### Task 2: MoodLevel・投稿モデル・定型フレーズカタログ

**Files:**
- Create: `ios/TyphoonRiskNavi/Models/AreaMoodModels.swift`
- Create: `ios/TyphoonRiskNavi/Services/MoodPhraseCatalog.swift`
- Test: `ios/TyphoonRiskNaviTests/MoodPhraseCatalogTests.swift`

**Interfaces:**
- Consumes: `OkinawaArea`（Task 1）
- Produces:
  - `enum MoodLevel: Int, CaseIterable, Codable, Comparable, Identifiable`（1〜5。`label: String` / `emoji: String` / `color: Color`）
  - `struct AreaMoodPost: Identifiable, Equatable`（`id: String, area: OkinawaArea, level: MoodLevel, phraseID: String, createdAt: Date`）
  - `struct AreaMoodSummary: Equatable`（`area: OkinawaArea, representativeLevel: MoodLevel?, postCount: Int`）
  - `struct MoodPhrase: Identifiable, Equatable`（`id: String, level: MoodLevel, text: String`）
  - `MoodPhraseCatalog.all: [MoodPhrase]` / `phrases(for: MoodLevel) -> [MoodPhrase]` / `phrase(for id: String) -> MoodPhrase?`

- [ ] **Step 1: 失敗するテストを書く**

`ios/TyphoonRiskNaviTests/MoodPhraseCatalogTests.swift` を作成:

```swift
import XCTest
@testable import TyphoonRiskNavi

/// 定型フレーズカタログの整合性テスト。
/// CloudKit には phraseID しか保存しないため、ID の一意性と全レベルの網羅が壊れると
/// 過去投稿の表示が壊れる。ここで固定する。
final class MoodPhraseCatalogTests: XCTestCase {

    func testPhraseIDsAreUnique() {
        let ids = MoodPhraseCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "phraseID が重複している")
    }

    /// 各レベルに4件のフレーズがある。
    func testEveryLevelHasFourPhrases() {
        for level in MoodLevel.allCases {
            XCTAssertEqual(
                MoodPhraseCatalog.phrases(for: level).count, 4,
                "レベル\(level.rawValue) のフレーズが4件でない"
            )
        }
    }

    /// 全フレーズが ID で引ける。
    func testAllPhrasesResolveByID() {
        for phrase in MoodPhraseCatalog.all {
            XCTAssertEqual(MoodPhraseCatalog.phrase(for: phrase.id), phrase)
        }
    }

    /// 未知の ID（将来バージョンのフレーズ等）は nil を返す。
    func testUnknownIDReturnsNil() {
        XCTAssertNil(MoodPhraseCatalog.phrase(for: "L9_unknown_future_phrase"))
    }

    /// フレーズはレベルのラベルと重複させない（画面に並べて表示するため）。
    func testPhrasesDoNotDuplicateLevelLabels() {
        let labels = Set(MoodLevel.allCases.map(\.label))
        for phrase in MoodPhraseCatalog.all {
            XCTAssertFalse(labels.contains(phrase.text), "フレーズ「\(phrase.text)」がレベルのラベルと重複")
        }
    }

    func testMoodLevelIsComparable() {
        XCTAssertTrue(MoodLevel.calm < MoodLevel.violent)
        XCTAssertEqual(MoodLevel(rawValue: 3), .stormy)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodegen generate && xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TyphoonRiskNaviTests/MoodPhraseCatalogTests 2>&1 | tail -5`
Expected: ビルドエラー（`MoodLevel` / `MoodPhraseCatalog` 未定義）

- [ ] **Step 3: モデルを実装する**

`ios/TyphoonRiskNavi/Models/AreaMoodModels.swift` を作成:

```swift
import SwiftUI

/// 体感レベル5段階。色・表情・ラベルはレベルと1対1。
/// 色覚多様性に配慮し、UI では色だけに頼らず表情と文字を常に併記する。
/// スペック: docs/superpowers/specs/2026-08-15-area-mood-posts-design.md §5
enum MoodLevel: Int, CaseIterable, Codable, Comparable, Identifiable {
    case calm = 1
    case breezy = 2
    case stormy = 3
    case dangerous = 4
    case violent = 5

    var id: Int { rawValue }

    static func < (lhs: MoodLevel, rhs: MoodLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .calm: return "おだやか"
        case .breezy: return "風が出てきた"
        case .stormy: return "雨風が強い"
        case .dangerous: return "外は危険"
        case .violent: return "暴風"
        }
    }

    var emoji: String {
        switch self {
        case .calm: return "😌"
        case .breezy: return "🙂"
        case .stormy: return "😟"
        case .dangerous: return "😨"
        case .violent: return "😱"
        }
    }

    var color: Color {
        switch self {
        case .calm: return .blue
        case .breezy: return .green
        case .stormy: return .yellow
        case .dangerous: return .orange
        case .violent: return .red
        }
    }
}

/// 1件の体感投稿（クライアント側モデル）。CloudKit レコードとの変換は CloudKitMoodPostStore が行う。
struct AreaMoodPost: Identifiable, Equatable {
    let id: String          // CKRecord.ID.recordName 由来。InMemory 実装では UUID
    let area: OkinawaArea
    let level: MoodLevel
    let phraseID: String
    let createdAt: Date
}

/// エリアの集約結果。representativeLevel が nil のときは期間内に投稿なし。
struct AreaMoodSummary: Equatable {
    let area: OkinawaArea
    let representativeLevel: MoodLevel?
    let postCount: Int
}
```

`ios/TyphoonRiskNavi/Services/MoodPhraseCatalog.swift` を作成:

```swift
import Foundation

struct MoodPhrase: Identifiable, Equatable {
    let id: String
    let level: MoodLevel
    let text: String
}

/// 定型フレーズの静的カタログ。CloudKit には phraseID のみ保存し、文言はここで解決する。
/// ID は文言と独立させ、文言を変えても過去投稿の意味が壊れないようにする。
/// フレーズはレベルのラベルと重複させない（画面に並べて表示するため）。
enum MoodPhraseCatalog {

    static let all: [MoodPhrase] = [
        // レベル1: おだやか
        MoodPhrase(id: "L1_still_quiet", level: .calm, text: "まだ静か"),
        MoodPhrase(id: "L1_gentle_wind", level: .calm, text: "風は穏やか"),
        MoodPhrase(id: "L1_no_rain", level: .calm, text: "雨は降っていない"),
        MoodPhrase(id: "L1_as_usual", level: .calm, text: "普段どおり"),
        // レベル2: 風が出てきた
        MoodPhrase(id: "L2_trees_swaying", level: .breezy, text: "木が揺れている"),
        MoodPhrase(id: "L2_rain_started", level: .breezy, text: "雨が降り始めた"),
        MoodPhrase(id: "L2_stocked_up", level: .breezy, text: "買い出しに行った"),
        MoodPhrase(id: "L2_still_walkable", level: .breezy, text: "まだ出歩ける"),
        // レベル3: 雨風が強い
        MoodPhrase(id: "L3_windows_rattling", level: .stormy, text: "窓が音を立てている"),
        MoodPhrase(id: "L3_staying_in", level: .stormy, text: "外出はやめた"),
        MoodPhrase(id: "L3_transport_disrupted", level: .stormy, text: "交通が乱れている"),
        MoodPhrase(id: "L3_umbrella_useless", level: .stormy, text: "傘がさせない"),
        // レベル4: 外は危険
        MoodPhrase(id: "L4_cannot_go_out", level: .dangerous, text: "外に出られない"),
        MoodPhrase(id: "L4_debris_flying", level: .dangerous, text: "物が飛んでいる"),
        MoodPhrase(id: "L4_power_outage", level: .dangerous, text: "停電しています"),
        MoodPhrase(id: "L4_water_outage", level: .dangerous, text: "断水しています"),
        // レベル5: 暴風
        MoodPhrase(id: "L5_roaring_wind", level: .violent, text: "風の音がすごい"),
        MoodPhrase(id: "L5_away_from_windows", level: .violent, text: "窓から離れている"),
        MoodPhrase(id: "L5_peak_ahead", level: .violent, text: "峠はまだ先"),
        MoodPhrase(id: "L5_maybe_past_peak", level: .violent, text: "峠を越えたかも"),
    ]

    static func phrases(for level: MoodLevel) -> [MoodPhrase] {
        all.filter { $0.level == level }
    }

    /// 未知の ID（将来のバージョンが追加したフレーズ等）は nil。表示側はレベルのラベルで代替する。
    static func phrase(for id: String) -> MoodPhrase? {
        all.first { $0.id == id }
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: Step 2 と同じコマンド
Expected: PASS（6テスト）

- [ ] **Step 5: コミット**

```bash
git add ios/TyphoonRiskNavi/Models/AreaMoodModels.swift ios/TyphoonRiskNavi/Services/MoodPhraseCatalog.swift ios/TyphoonRiskNaviTests/MoodPhraseCatalogTests.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: add mood levels, the post model, and the fixed phrase catalog"
```

---

### Task 3: MoodAggregator（集約の純関数）

**Files:**
- Create: `ios/TyphoonRiskNavi/Services/MoodAggregator.swift`
- Test: `ios/TyphoonRiskNaviTests/MoodAggregatorTests.swift`

**Interfaces:**
- Consumes: `AreaMoodPost` / `AreaMoodSummary` / `MoodLevel` / `OkinawaArea`（Task 1, 2）
- Produces: `MoodAggregator.window: TimeInterval`（3時間）、`MoodAggregator.summarize(posts: [AreaMoodPost], now: Date) -> [OkinawaArea: AreaMoodSummary]`

- [ ] **Step 1: 失敗するテストを書く**

`ios/TyphoonRiskNaviTests/MoodAggregatorTests.swift` を作成:

```swift
import XCTest
@testable import TyphoonRiskNavi

/// エリア別集約の純関数テスト。
/// 代表値 = 時間窓内の最頻レベル、同数なら高いレベル（防災文脈では過剰側に倒す）。
final class MoodAggregatorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func post(
        _ area: OkinawaArea, _ level: MoodLevel, minutesAgo: Double
    ) -> AreaMoodPost {
        AreaMoodPost(id: UUID().uuidString, area: area, level: level, phraseID: "L1_still_quiet",
                     createdAt: now.addingTimeInterval(-minutesAgo * 60))
    }

    /// 最頻レベルが代表値になる。
    func testModeWins() {
        let posts = [
            post(.naha, .stormy, minutesAgo: 10),
            post(.naha, .stormy, minutesAgo: 20),
            post(.naha, .calm, minutesAgo: 30),
        ]
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.naha]?.representativeLevel, .stormy)
        XCTAssertEqual(result[.naha]?.postCount, 3)
    }

    /// 同数のときは高いレベルに倒す。
    func testTieBreaksToHigherLevel() {
        let posts = [
            post(.miyako, .calm, minutesAgo: 10),
            post(.miyako, .violent, minutesAgo: 20),
        ]
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.miyako]?.representativeLevel, .violent)
    }

    /// 時間窓の境界: ちょうど3時間前（180分）は含み、181分前は除外する。
    func testWindowBoundary() {
        let boundary = [
            post(.daito, .violent, minutesAgo: 180),
            post(.daito, .calm, minutesAgo: 181),
        ]
        let result = MoodAggregator.summarize(posts: boundary, now: now)
        XCTAssertEqual(result[.daito]?.postCount, 1)
        XCTAssertEqual(result[.daito]?.representativeLevel, .violent)
    }

    /// 投稿ゼロのエリアも postCount 0・representativeLevel nil で全10件返る。
    func testAllAreasPresentEvenWithNoPosts() {
        let result = MoodAggregator.summarize(posts: [], now: now)
        XCTAssertEqual(result.count, OkinawaArea.allCases.count)
        for area in OkinawaArea.allCases {
            XCTAssertEqual(result[area]?.postCount, 0)
            XCTAssertNil(result[area]?.representativeLevel)
        }
    }

    /// エリアをまたいで混ざらない。
    func testAreasAreIndependent() {
        let posts = [
            post(.naha, .violent, minutesAgo: 5),
            post(.ishigaki, .calm, minutesAgo: 5),
        ]
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.naha]?.representativeLevel, .violent)
        XCTAssertEqual(result[.ishigaki]?.representativeLevel, .calm)
        XCTAssertEqual(result[.kumejima]?.postCount, 0)
    }

    /// 端末時計より未来の createdAt（サーバー時刻とのずれ）も除外しない。
    /// 投稿直後の楽観的反映が時計ずれで消えると、投稿が失敗したように見えるため。
    func testFuturePostsAreIncluded() {
        let posts = [post(.naha, .stormy, minutesAgo: -1)]   // 1分未来
        let result = MoodAggregator.summarize(posts: posts, now: now)
        XCTAssertEqual(result[.naha]?.postCount, 1)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodegen generate && xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TyphoonRiskNaviTests/MoodAggregatorTests 2>&1 | tail -5`
Expected: ビルドエラー（`MoodAggregator` 未定義）

- [ ] **Step 3: 実装を書く**

`ios/TyphoonRiskNavi/Services/MoodAggregator.swift` を作成:

```swift
import Foundation

/// 投稿列からエリア別の代表体感を集約する純関数。
enum MoodAggregator {

    /// 集約に使う時間窓（3時間）。これより古い投稿は無視する。
    static let window: TimeInterval = 3 * 60 * 60

    /// 全10エリア分のサマリーを返す（投稿が無いエリアも postCount 0 で含む）。
    /// 代表値は時間窓内の最頻レベル。同数の場合は高いレベル側に倒す
    /// （防災文脈では見逃しより過剰の方が安全）。
    /// createdAt が now より未来の投稿は除外しない。サーバー時刻と端末時計のずれで
    /// 投稿直後の楽観的反映が消えると、投稿が失敗したように見えるため。
    static func summarize(posts: [AreaMoodPost], now: Date = Date()) -> [OkinawaArea: AreaMoodSummary] {
        let cutoff = now.addingTimeInterval(-window)
        let recent = posts.filter { $0.createdAt >= cutoff }
        let grouped = Dictionary(grouping: recent, by: \.area)

        var result: [OkinawaArea: AreaMoodSummary] = [:]
        for area in OkinawaArea.allCases {
            let areaPosts = grouped[area] ?? []
            let counts = Dictionary(grouping: areaPosts, by: \.level).mapValues(\.count)
            let representative = counts.max { a, b in
                if a.value != b.value { return a.value < b.value }
                return a.key < b.key   // 同数なら高いレベルを採る
            }?.key
            result[area] = AreaMoodSummary(
                area: area,
                representativeLevel: representative,
                postCount: areaPosts.count
            )
        }
        return result
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: Step 2 と同じコマンド
Expected: PASS（6テスト）

- [ ] **Step 5: コミット**

```bash
git add ios/TyphoonRiskNavi/Services/MoodAggregator.swift ios/TyphoonRiskNaviTests/MoodAggregatorTests.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: aggregate area moods by mode with a severity-first tie break"
```

---

### Task 4: MoodPostRateLimiter（連投制限）

**Files:**
- Create: `ios/TyphoonRiskNavi/Services/MoodPostRateLimiter.swift`
- Test: `ios/TyphoonRiskNaviTests/MoodPostRateLimiterTests.swift`

**Interfaces:**
- Consumes: なし（Foundation のみ）
- Produces: `struct MoodPostRateLimiter`（`init(defaults: UserDefaults = .standard, interval: TimeInterval = MoodPostRateLimiter.defaultInterval)` / `canPost(now: Date) -> Bool` / `remainingSeconds(now: Date) -> TimeInterval` / `recordPost(now: Date)`）

- [ ] **Step 1: 失敗するテストを書く**

`ios/TyphoonRiskNaviTests/MoodPostRateLimiterTests.swift` を作成:

```swift
import XCTest
@testable import TyphoonRiskNavi

/// 連投制限（10分に1回）のテスト。UserDefaults はテスト用スイートを注入する。
final class MoodPostRateLimiterTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "MoodPostRateLimiterTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testCanPostWhenNeverPosted() {
        let limiter = MoodPostRateLimiter(defaults: defaults)
        XCTAssertTrue(limiter.canPost(now: Date()))
        XCTAssertEqual(limiter.remainingSeconds(now: Date()), 0)
    }

    func testBlockedJustAfterPosting() {
        let limiter = MoodPostRateLimiter(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        limiter.recordPost(now: now)
        XCTAssertFalse(limiter.canPost(now: now.addingTimeInterval(1)))
        XCTAssertEqual(limiter.remainingSeconds(now: now.addingTimeInterval(60)), 540, accuracy: 0.5)
    }

    /// 10分ちょうどで解除される。
    func testUnblockedAtExactlyTenMinutes() {
        let limiter = MoodPostRateLimiter(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        limiter.recordPost(now: now)
        XCTAssertFalse(limiter.canPost(now: now.addingTimeInterval(599)))
        XCTAssertTrue(limiter.canPost(now: now.addingTimeInterval(600)))
    }

    /// interval を注入できる（テストや将来の調整用）。
    func testCustomInterval() {
        let limiter = MoodPostRateLimiter(defaults: defaults, interval: 60)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        limiter.recordPost(now: now)
        XCTAssertFalse(limiter.canPost(now: now.addingTimeInterval(30)))
        XCTAssertTrue(limiter.canPost(now: now.addingTimeInterval(60)))
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodegen generate && xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TyphoonRiskNaviTests/MoodPostRateLimiterTests 2>&1 | tail -5`
Expected: ビルドエラー（`MoodPostRateLimiter` 未定義）

- [ ] **Step 3: 実装を書く**

`ios/TyphoonRiskNavi/Services/MoodPostRateLimiter.swift` を作成:

```swift
import Foundation

/// 連投制限。同一端末からの体感投稿を interval（既定10分）に1回に制限する。
/// UserDefaults に最終投稿時刻を持つだけの端末ローカル制限
/// （CloudKit Public Database にはサーバー側のレート制限を書けないため）。
struct MoodPostRateLimiter {
    static let defaultInterval: TimeInterval = 10 * 60
    static let lastPostKey = "area_mood_last_post_at_v1"

    private let defaults: UserDefaults
    private let interval: TimeInterval

    init(defaults: UserDefaults = .standard, interval: TimeInterval = MoodPostRateLimiter.defaultInterval) {
        self.defaults = defaults
        self.interval = interval
    }

    func canPost(now: Date = Date()) -> Bool {
        remainingSeconds(now: now) <= 0
    }

    /// 次に投稿できるまでの残り秒数。投稿可能なら 0。
    func remainingSeconds(now: Date = Date()) -> TimeInterval {
        guard let last = defaults.object(forKey: Self.lastPostKey) as? Date else { return 0 }
        return max(0, interval - now.timeIntervalSince(last))
    }

    func recordPost(now: Date = Date()) {
        defaults.set(now, forKey: Self.lastPostKey)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: Step 2 と同じコマンド
Expected: PASS（4テスト）

- [ ] **Step 5: コミット**

```bash
git add ios/TyphoonRiskNavi/Services/MoodPostRateLimiter.swift ios/TyphoonRiskNaviTests/MoodPostRateLimiterTests.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: limit mood posts to one per ten minutes per device"
```

---

### Task 5: MoodPostStore protocol と InMemory 実装

**Files:**
- Create: `ios/TyphoonRiskNavi/Services/MoodPostStore.swift`
- Test: `ios/TyphoonRiskNaviTests/InMemoryMoodPostStoreTests.swift`

**Interfaces:**
- Consumes: `AreaMoodPost` / `OkinawaArea` / `MoodLevel`（Task 1, 2）、`MoodAggregator.window`（Task 3、テスト内でのみ）
- Produces:
  - `protocol MoodPostStore { func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost]; func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost }`
  - `final class InMemoryMoodPostStore: MoodPostStore`（`posts: [AreaMoodPost]` / `fetchError: Error?` / `submitError: Error?` / `now: () -> Date`）
  - `InMemoryMoodPostStore.screenshotSamples(now: Date) -> InMemoryMoodPostStore`

- [ ] **Step 1: 失敗するテストを書く**

`ios/TyphoonRiskNaviTests/InMemoryMoodPostStoreTests.swift` を作成:

```swift
import XCTest
@testable import TyphoonRiskNavi

/// テスト用 InMemory ストアの挙動を固定する（ViewModel テストの土台になるため）。
final class InMemoryMoodPostStoreTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFetchFiltersSortsAndLimits() async throws {
        let old = AreaMoodPost(id: "old", area: .naha, level: .calm, phraseID: "L1_still_quiet",
                               createdAt: now.addingTimeInterval(-7200))
        let newer = AreaMoodPost(id: "newer", area: .naha, level: .stormy, phraseID: "L3_staying_in",
                                 createdAt: now.addingTimeInterval(-60))
        let tooOld = AreaMoodPost(id: "tooOld", area: .naha, level: .calm, phraseID: "L1_as_usual",
                                  createdAt: now.addingTimeInterval(-20_000))
        let store = InMemoryMoodPostStore(posts: [old, newer, tooOld])

        let fetched = try await store.fetchPosts(since: now.addingTimeInterval(-10_800), limit: 10)
        XCTAssertEqual(fetched.map(\.id), ["newer", "old"])   // 新しい順・窓外は除外

        let limited = try await store.fetchPosts(since: now.addingTimeInterval(-10_800), limit: 1)
        XCTAssertEqual(limited.map(\.id), ["newer"])
    }

    func testSubmitAppendsWithInjectedClock() async throws {
        let store = InMemoryMoodPostStore(now: { self.now })
        let saved = try await store.submit(area: .miyako, level: .dangerous, phraseID: "L4_power_outage")
        XCTAssertEqual(saved.area, .miyako)
        XCTAssertEqual(saved.createdAt, now)
        XCTAssertEqual(store.posts.count, 1)
    }

    func testErrorsPropagate() async {
        struct Boom: Error {}
        let store = InMemoryMoodPostStore()
        store.fetchError = Boom()
        do {
            _ = try await store.fetchPosts(since: .distantPast, limit: 10)
            XCTFail("fetchError が伝播していない")
        } catch {}
        store.submitError = Boom()
        do {
            _ = try await store.submit(area: .naha, level: .calm, phraseID: "L1_still_quiet")
            XCTFail("submitError が伝播していない")
        } catch {}
    }

    /// スクショ用サンプルは全エリアに1件以上あり、phraseID がカタログで解決できる。
    func testScreenshotSamplesAreWellFormed() async throws {
        let store = InMemoryMoodPostStore.screenshotSamples(now: now)
        let posts = try await store.fetchPosts(since: now.addingTimeInterval(-MoodAggregator.window), limit: 200)
        let coveredAreas = Set(posts.map(\.area))
        XCTAssertEqual(coveredAreas, Set(OkinawaArea.allCases), "サンプルが全エリアを覆っていない")
        for post in posts {
            XCTAssertNotNil(MoodPhraseCatalog.phrase(for: post.phraseID),
                            "サンプルの phraseID \(post.phraseID) がカタログに無い")
            XCTAssertEqual(MoodPhraseCatalog.phrase(for: post.phraseID)?.level, post.level,
                           "サンプルの phraseID とレベルが食い違っている")
        }
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodegen generate && xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TyphoonRiskNaviTests/InMemoryMoodPostStoreTests 2>&1 | tail -5`
Expected: ビルドエラー（`MoodPostStore` 未定義）

- [ ] **Step 3: 実装を書く**

`ios/TyphoonRiskNavi/Services/MoodPostStore.swift` を作成:

```swift
import Foundation

/// 体感投稿の取得・送信を抽象化する。本番は CloudKit 実装、テストとスクショモードは InMemory 実装。
protocol MoodPostStore {
    /// since 以降の投稿を新しい順で返す。limit 件で打ち切る。
    func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost]
    /// 投稿を1件保存し、保存されたレコードを返す。
    func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost
}

/// テスト・スクリーンショットモード用のインメモリ実装。
final class InMemoryMoodPostStore: MoodPostStore {
    private(set) var posts: [AreaMoodPost]
    /// テストでエラー経路を検証するためのフック。
    var fetchError: Error?
    var submitError: Error?
    /// 時刻を注入可能にする（テストの決定性のため）。
    var now: () -> Date

    init(posts: [AreaMoodPost] = [], now: @escaping () -> Date = { Date() }) {
        self.posts = posts
        self.now = now
    }

    func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost] {
        if let fetchError { throw fetchError }
        return posts
            .filter { $0.createdAt >= since }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost {
        if let submitError { throw submitError }
        let post = AreaMoodPost(
            id: UUID().uuidString, area: area, level: level, phraseID: phraseID, createdAt: now()
        )
        posts.append(post)
        return post
    }
}

extension InMemoryMoodPostStore {
    /// App Store スクリーンショット用のサンプル投稿。台風接近中の見え方を再現する。
    /// スクショモードでは CloudKit には一切書かない（既存のデモデータ方針を踏襲）。
    static func screenshotSamples(now: Date = Date()) -> InMemoryMoodPostStore {
        func sample(_ area: OkinawaArea, _ level: MoodLevel, _ phraseID: String, minutesAgo: Double) -> AreaMoodPost {
            AreaMoodPost(id: UUID().uuidString, area: area, level: level, phraseID: phraseID,
                         createdAt: now.addingTimeInterval(-minutesAgo * 60))
        }
        return InMemoryMoodPostStore(posts: [
            sample(.naha, .stormy, "L3_windows_rattling", minutesAgo: 8),
            sample(.naha, .stormy, "L3_staying_in", minutesAgo: 25),
            sample(.south, .dangerous, "L4_power_outage", minutesAgo: 12),
            sample(.central, .stormy, "L3_transport_disrupted", minutesAgo: 18),
            sample(.north, .breezy, "L2_trees_swaying", minutesAgo: 30),
            sample(.keramaAguni, .dangerous, "L4_cannot_go_out", minutesAgo: 15),
            sample(.kumejima, .violent, "L5_roaring_wind", minutesAgo: 5),
            sample(.miyako, .breezy, "L2_rain_started", minutesAgo: 40),
            sample(.ishigaki, .calm, "L1_still_quiet", minutesAgo: 50),
            sample(.yonaguni, .calm, "L1_as_usual", minutesAgo: 65),
            sample(.daito, .stormy, "L3_umbrella_useless", minutesAgo: 22),
        ])
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: Step 2 と同じコマンド
Expected: PASS（4テスト）

- [ ] **Step 5: コミット**

```bash
git add ios/TyphoonRiskNavi/Services/MoodPostStore.swift ios/TyphoonRiskNaviTests/InMemoryMoodPostStoreTests.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: add the mood post store protocol with an in-memory double"
```

---

### Task 6: CloudKit entitlements と CloudKitMoodPostStore

**Files:**
- Create: `ios/TyphoonRiskNavi/TyphoonRiskNavi.entitlements`
- Modify: `ios/project.yml`（targets.TyphoonRiskNavi.settings.base に1行追加）
- Create: `ios/TyphoonRiskNavi/Services/CloudKitMoodPostStore.swift`
- Test: `ios/TyphoonRiskNaviTests/CloudKitMoodPostStoreTests.swift`

**Interfaces:**
- Consumes: `MoodPostStore` / `AreaMoodPost` / `OkinawaArea` / `MoodLevel`（Task 1, 2, 5）
- Produces: `final class CloudKitMoodPostStore: MoodPostStore`（`init(container: CKContainer = .default())`）、`CloudKitMoodPostStore.recordType: String`、`CloudKitMoodPostStore.post(from: CKRecord) -> AreaMoodPost?`（static、変換関数）、`CloudKitMoodPostStore.StoreError`（`.notSignedIn` / `.invalidRecord`、`LocalizedError` 準拠）

- [ ] **Step 1: entitlements ファイルを作成**

`ios/TyphoonRiskNavi/TyphoonRiskNavi.entitlements` を作成:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.icloud-services</key>
	<array>
		<string>CloudKit</string>
	</array>
	<key>com.apple.developer.icloud-container-identifiers</key>
	<array>
		<string>iCloud.com.example.OkinawaTyphoonNavi</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: project.yml に entitlements を紐付け、再生成**

`ios/project.yml` の `targets.TyphoonRiskNavi.settings.base`（`INFOPLIST_FILE: TyphoonRiskNavi/Info.plist` があるブロック）に1行追加:

```yaml
        CODE_SIGN_ENTITLEMENTS: TyphoonRiskNavi/TyphoonRiskNavi.entitlements
```

Run: `cd ios && xcodegen generate`
Expected: `Created project` のログ（xcodegen が `.xcodeproj.bak.*` を作ることがあるが git 追跡外なので無視）

- [ ] **Step 3: 失敗するテストを書く**

CloudKit のネットワーク層はユニットテストできないため、**CKRecord → AreaMoodPost の変換関数だけをテストする**（CKRecord はネットワークなしでインスタンス化できる）。通信そのもの（保存・取得）は Task 11 のシミュレータ手動確認とする。

`ios/TyphoonRiskNaviTests/CloudKitMoodPostStoreTests.swift` を作成:

```swift
import XCTest
import CloudKit
@testable import TyphoonRiskNavi

/// CKRecord → AreaMoodPost 変換のテスト。ネットワークには一切触れない。
final class CloudKitMoodPostStoreTests: XCTestCase {

    private func makeRecord(area: String?, level: Int?, phraseID: String?) -> CKRecord {
        let record = CKRecord(recordType: CloudKitMoodPostStore.recordType)
        if let area { record["area"] = area as CKRecordValue }
        if let level { record["level"] = level as CKRecordValue }
        if let phraseID { record["phraseID"] = phraseID as CKRecordValue }
        return record
    }

    func testValidRecordConverts() {
        let record = makeRecord(area: "keramaAguni", level: 4, phraseID: "L4_power_outage")
        let post = CloudKitMoodPostStore.post(from: record)
        XCTAssertEqual(post?.area, .keramaAguni)
        XCTAssertEqual(post?.level, .dangerous)
        XCTAssertEqual(post?.phraseID, "L4_power_outage")
        XCTAssertEqual(post?.id, record.recordID.recordName)
    }

    /// 未知のエリア（将来のバージョンが増やした等）は読み飛ばす（nil）。
    func testUnknownAreaReturnsNil() {
        let record = makeRecord(area: "atlantis", level: 3, phraseID: "L3_staying_in")
        XCTAssertNil(CloudKitMoodPostStore.post(from: record))
    }

    /// 範囲外レベルは読み飛ばす。
    func testOutOfRangeLevelReturnsNil() {
        XCTAssertNil(CloudKitMoodPostStore.post(from: makeRecord(area: "naha", level: 6, phraseID: "x")))
        XCTAssertNil(CloudKitMoodPostStore.post(from: makeRecord(area: "naha", level: 0, phraseID: "x")))
    }

    /// 必須フィールド欠落は読み飛ばす。phraseID だけは欠けても空文字で許容
    /// （表示側がレベルのラベルで代替できるため）。
    func testMissingFields() {
        XCTAssertNil(CloudKitMoodPostStore.post(from: makeRecord(area: nil, level: 3, phraseID: "x")))
        XCTAssertNil(CloudKitMoodPostStore.post(from: makeRecord(area: "naha", level: nil, phraseID: "x")))
        let noPhrase = CloudKitMoodPostStore.post(from: makeRecord(area: "naha", level: 3, phraseID: nil))
        XCTAssertEqual(noPhrase?.phraseID, "")
    }
}
```

- [ ] **Step 4: テストが失敗することを確認**

Run: `xcodegen generate && xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TyphoonRiskNaviTests/CloudKitMoodPostStoreTests 2>&1 | tail -5`
Expected: ビルドエラー（`CloudKitMoodPostStore` 未定義）

- [ ] **Step 5: 実装を書く**

`ios/TyphoonRiskNavi/Services/CloudKitMoodPostStore.swift` を作成:

```swift
import CloudKit
import Foundation

/// CloudKit Public Database に体感投稿を保存・取得する本番実装。
/// レコードタイプ AreaMoodPost: area (String) / level (Int64) / phraseID (String)。
/// 時刻はシステムの creationDate を使い、精密位置・ユーザー識別子は保存しない。
///
/// 運用ノート: 初回リリース前に CloudKit コンソールで
/// (1) creationDate に Sortable + Queryable インデックスを付ける
/// (2) スキーマを Production へデプロイする
/// を忘れないこと（実装計画 Task 11 参照）。
final class CloudKitMoodPostStore: MoodPostStore {

    static let recordType = "AreaMoodPost"

    enum StoreError: LocalizedError {
        case notSignedIn
        case invalidRecord

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "投稿には iCloud サインインが必要です。設定アプリからサインインしてください"
            case .invalidRecord: return "投稿データを読み取れませんでした"
            }
        }
    }

    private let container: CKContainer
    private let database: CKDatabase

    init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.publicCloudDatabase
    }

    func fetchPosts(since: Date, limit: Int) async throws -> [AreaMoodPost] {
        let predicate = NSPredicate(format: "creationDate >= %@", since as NSDate)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let (results, _) = try await database.records(matching: query, resultsLimit: limit)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Self.post(from: record)
        }
    }

    func submit(area: OkinawaArea, level: MoodLevel, phraseID: String) async throws -> AreaMoodPost {
        // 未サインインのまま save すると分かりにくいエラーで落ちるため、先に状態を確かめて明確に伝える。
        let status = try await container.accountStatus()
        guard status == .available else { throw StoreError.notSignedIn }

        let record = CKRecord(recordType: Self.recordType)
        record["area"] = area.rawValue as CKRecordValue
        record["level"] = level.rawValue as CKRecordValue
        record["phraseID"] = phraseID as CKRecordValue
        let saved = try await database.save(record)
        guard let post = Self.post(from: saved) else { throw StoreError.invalidRecord }
        return post
    }

    /// CKRecord → AreaMoodPost 変換。未知のエリア・範囲外レベルは nil（呼び出し側で読み飛ばす）。
    /// 将来のバージョンがエリアやレベルを増やしても、旧バージョンがクラッシュせず無視できるようにする。
    /// creationDate は保存前のローカルレコードでは nil のため、現在時刻で代替する
    /// （submit 直後の楽観的反映で使われるだけで、次回 fetch でサーバー時刻に置き換わる）。
    static func post(from record: CKRecord) -> AreaMoodPost? {
        guard
            let areaRaw = record["area"] as? String,
            let area = OkinawaArea(rawValue: areaRaw),
            let levelRaw = record["level"] as? Int,
            let level = MoodLevel(rawValue: levelRaw)
        else { return nil }
        let phraseID = record["phraseID"] as? String ?? ""
        return AreaMoodPost(
            id: record.recordID.recordName,
            area: area,
            level: level,
            phraseID: phraseID,
            createdAt: record.creationDate ?? Date()
        )
    }
}
```

- [ ] **Step 6: テストが通ることを確認**

Run: Step 4 と同じコマンド
Expected: PASS（4テスト）

- [ ] **Step 7: コミット**

```bash
git add ios/TyphoonRiskNavi/TyphoonRiskNavi.entitlements ios/project.yml ios/TyphoonRiskNavi/Services/CloudKitMoodPostStore.swift ios/TyphoonRiskNaviTests/CloudKitMoodPostStoreTests.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: store mood posts in CloudKit's public database"
```

---

### Task 7: AreaMoodViewModel

**Files:**
- Create: `ios/TyphoonRiskNavi/ViewModels/AreaMoodViewModel.swift`
- Test: `ios/TyphoonRiskNaviTests/AreaMoodViewModelTests.swift`

**Interfaces:**
- Consumes: `MoodPostStore` / `InMemoryMoodPostStore`（Task 5）、`MoodAggregator`（Task 3）、`MoodPostRateLimiter`（Task 4）、`CloudKitMoodPostStore`（Task 6）、`OkinawaMunicipalityCatalog.nearest(to:)`（既存）、`OkinawaMunicipality.area`（Task 1）
- Produces: `@MainActor final class AreaMoodViewModel: ObservableObject`
  - `@Published summaries: [OkinawaArea: AreaMoodSummary]` / `recentPosts: [AreaMoodPost]` / `isLoading: Bool` / `lastUpdated: Date?` / `fetchFailed: Bool` / `postError: String?`
  - `init(store: MoodPostStore, rateLimiter: MoodPostRateLimiter = MoodPostRateLimiter(), now: @escaping () -> Date = { Date() })`
  - `static func live() -> AreaMoodViewModel`（スクショモード分岐）
  - `func refresh() async` / `func post(area: OkinawaArea, level: MoodLevel, phraseID: String) async -> Bool` / `var postingBlockedReason: String?`
  - `func startAutoRefresh()` / `func stopAutoRefresh()`
  - `static func area(for coordinate: CLLocationCoordinate2D) -> OkinawaArea?`

- [ ] **Step 1: 失敗するテストを書く**

`ios/TyphoonRiskNaviTests/AreaMoodViewModelTests.swift` を作成:

```swift
import XCTest
import CoreLocation
@testable import TyphoonRiskNavi

/// AreaMoodViewModel のテスト。ストアは InMemory、UserDefaults はテスト用スイート、時刻は固定注入。
@MainActor
final class AreaMoodViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "AreaMoodViewModelTests"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeViewModel(store: InMemoryMoodPostStore) -> AreaMoodViewModel {
        AreaMoodViewModel(
            store: store,
            rateLimiter: MoodPostRateLimiter(defaults: defaults),
            now: { self.now }
        )
    }

    func testRefreshPopulatesSummaries() async {
        let store = InMemoryMoodPostStore(posts: [
            AreaMoodPost(id: "1", area: .naha, level: .stormy, phraseID: "L3_staying_in",
                         createdAt: now.addingTimeInterval(-600)),
        ])
        let viewModel = makeViewModel(store: store)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.summaries[.naha]?.representativeLevel, .stormy)
        XCTAssertEqual(viewModel.summaries.count, OkinawaArea.allCases.count)
        XCTAssertEqual(viewModel.lastUpdated, now)
        XCTAssertFalse(viewModel.fetchFailed)
    }

    /// 取得失敗時は前回の結果を保持し、fetchFailed を立てる（無言で失敗させない）。
    func testFetchFailureKeepsPreviousResults() async {
        let store = InMemoryMoodPostStore(posts: [
            AreaMoodPost(id: "1", area: .miyako, level: .violent, phraseID: "L5_roaring_wind",
                         createdAt: now.addingTimeInterval(-60)),
        ])
        let viewModel = makeViewModel(store: store)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.summaries[.miyako]?.representativeLevel, .violent)

        struct Boom: Error {}
        store.fetchError = Boom()
        await viewModel.refresh()
        XCTAssertTrue(viewModel.fetchFailed)
        XCTAssertEqual(viewModel.summaries[.miyako]?.representativeLevel, .violent, "前回の結果が消えた")
    }

    /// 投稿成功で楽観的に反映され、レート制限が記録される。
    func testPostSuccessAppliesOptimistically() async {
        let store = InMemoryMoodPostStore(now: { self.now })
        let viewModel = makeViewModel(store: store)
        let succeeded = await viewModel.post(area: .daito, level: .dangerous, phraseID: "L4_cannot_go_out")
        XCTAssertTrue(succeeded)
        XCTAssertEqual(viewModel.summaries[.daito]?.representativeLevel, .dangerous)
        XCTAssertEqual(viewModel.summaries[.daito]?.postCount, 1)
        XCTAssertNil(viewModel.postError)
        XCTAssertNotNil(viewModel.postingBlockedReason, "投稿直後はレート制限がかかるはず")
    }

    /// レート制限中は投稿がブロックされ、ストアに書かれない。
    func testPostBlockedByRateLimit() async {
        let store = InMemoryMoodPostStore(now: { self.now })
        let viewModel = makeViewModel(store: store)
        _ = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        let second = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_as_usual")
        XCTAssertFalse(second)
        XCTAssertNotNil(viewModel.postError)
        XCTAssertEqual(store.posts.count, 1, "ブロック中にストアへ書かれた")
    }

    /// 投稿失敗時はエラーを表示し、レート制限を記録しない（再送できるように）。
    func testPostFailureDoesNotRecordRateLimit() async {
        struct Boom: Error {}
        let store = InMemoryMoodPostStore(now: { self.now })
        store.submitError = Boom()
        let viewModel = makeViewModel(store: store)
        let succeeded = await viewModel.post(area: .naha, level: .calm, phraseID: "L1_still_quiet")
        XCTAssertFalse(succeeded)
        XCTAssertNotNil(viewModel.postError)
        XCTAssertNil(viewModel.postingBlockedReason, "失敗したのにレート制限が記録された")
    }

    /// 座標→エリア判定は最寄り自治体経由（那覇市役所付近 → 那覇、石垣市役所付近 → 石垣）。
    func testAreaForCoordinate() {
        let naha = CLLocationCoordinate2D(latitude: 26.2124, longitude: 127.6809)
        XCTAssertEqual(AreaMoodViewModel.area(for: naha), .naha)
        let ishigaki = CLLocationCoordinate2D(latitude: 24.3444, longitude: 124.1572)
        XCTAssertEqual(AreaMoodViewModel.area(for: ishigaki), .ishigaki)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodegen generate && xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TyphoonRiskNaviTests/AreaMoodViewModelTests 2>&1 | tail -5`
Expected: ビルドエラー（`AreaMoodViewModel` 未定義）

- [ ] **Step 3: 実装を書く**

`ios/TyphoonRiskNavi/ViewModels/AreaMoodViewModel.swift` を作成:

```swift
import Combine
import CoreLocation
import Foundation

/// 「みんな」タブの状態管理。取得→集約→表示と、投稿（楽観的反映つき）を担う。
@MainActor
final class AreaMoodViewModel: ObservableObject {

    /// 1回の取得で読む最大件数。10エリア×直近20件相当で、代表値の決定には十分。
    static let fetchLimit = 200
    /// 表示中の自動更新間隔。
    static let refreshInterval: TimeInterval = 5 * 60

    @Published private(set) var summaries: [OkinawaArea: AreaMoodSummary]
    @Published private(set) var recentPosts: [AreaMoodPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var fetchFailed = false
    @Published var postError: String?

    private let store: MoodPostStore
    private let rateLimiter: MoodPostRateLimiter
    private let now: () -> Date
    private var refreshTask: Task<Void, Never>?

    init(
        store: MoodPostStore,
        rateLimiter: MoodPostRateLimiter = MoodPostRateLimiter(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.rateLimiter = rateLimiter
        self.now = now
        // 初期状態でも全エリアのセルが描けるよう、空の集約で埋めておく。
        self.summaries = MoodAggregator.summarize(posts: [], now: now())
    }

    /// 実運用は CloudKit、スクリーンショットモード（-screenshotMode YES）はサンプル入り InMemory。
    static func live() -> AreaMoodViewModel {
        if UserDefaults.standard.bool(forKey: "screenshotMode") {
            return AreaMoodViewModel(store: InMemoryMoodPostStore.screenshotSamples())
        }
        return AreaMoodViewModel(store: CloudKitMoodPostStore())
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let current = now()
        do {
            let posts = try await store.fetchPosts(
                since: current.addingTimeInterval(-MoodAggregator.window),
                limit: Self.fetchLimit
            )
            recentPosts = posts
            summaries = MoodAggregator.summarize(posts: posts, now: current)
            lastUpdated = current
            fetchFailed = false
        } catch {
            // 前回の結果を保持したまま、失敗だけ知らせる（無言で失敗させない）。
            // CloudKit のレート制限（CKError.requestRateLimited）もここに落ちる。即時再試行はせず、
            // 次の再試行はユーザー操作（再試行ボタン/プルリフレッシュ）か5分後の自動更新のみ。
            // retryAfter は通常数秒〜数十秒のため、この間隔はサーバーの指示より常に保守的で、
            // スペック §10「retryAfter を尊重して再試行する」を満たす。
            fetchFailed = true
        }
    }

    /// 投稿できない理由。nil なら投稿可能。
    var postingBlockedReason: String? {
        let remaining = rateLimiter.remainingSeconds(now: now())
        guard remaining > 0 else { return nil }
        let minutes = Int(ceil(remaining / 60))
        return "連続投稿はできません（あと約\(minutes)分）"
    }

    /// 投稿して楽観的に反映する。成功なら true。
    /// レート制限の記録は成功後のみ（失敗時に10分待たせない）。
    func post(area: OkinawaArea, level: MoodLevel, phraseID: String) async -> Bool {
        if let reason = postingBlockedReason {
            postError = reason
            return false
        }
        do {
            let saved = try await store.submit(area: area, level: level, phraseID: phraseID)
            rateLimiter.recordPost(now: now())
            recentPosts.insert(saved, at: 0)
            summaries = MoodAggregator.summarize(posts: recentPosts, now: now())
            postError = nil
            return true
        } catch {
            postError = (error as? LocalizedError)?.errorDescription
                ?? "投稿できませんでした。時間をおいて再度お試しください"
            return false
        }
    }

    /// タブ表示中の自動更新を開始する。多重起動しない。
    func startAutoRefresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.refreshInterval * 1_000_000_000))
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// 座標からエリアを推定する（既存の最寄り自治体判定を経由）。
    static func area(for coordinate: CLLocationCoordinate2D) -> OkinawaArea? {
        OkinawaMunicipalityCatalog.nearest(to: coordinate)?.municipality.area
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: Step 2 と同じコマンド
Expected: PASS（7テスト）

- [ ] **Step 5: コミット**

```bash
git add ios/TyphoonRiskNavi/ViewModels/AreaMoodViewModel.swift ios/TyphoonRiskNaviTests/AreaMoodViewModelTests.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: drive the mood tab with fetch, aggregate, and optimistic posting"
```

---

### Task 8: AreaMoodView（グリッド）と MainTabView 統合

**Files:**
- Create: `ios/TyphoonRiskNavi/Views/AreaMoodView.swift`
- Modify: `ios/TyphoonRiskNavi/Views/MainTabView.swift:34-39`（設定タブの `.tag(2)` の直後にタブ追加）
- Modify: `ios/TyphoonRiskNavi/Resources/Localizable.swift`（`tabMap` の並びに `tabMood` キー追加）
- Modify: `ios/TyphoonRiskNavi/Resources/ja.lproj/Localizable.strings`（`tab.mood` 追加）
- Modify: `ios/TyphoonRiskNavi/Resources/en.lproj/Localizable.strings`（`tab.mood` 追加）

**Interfaces:**
- Consumes: `AreaMoodViewModel.live()` / `summaries` / `refresh()` / `startAutoRefresh()` / `stopAutoRefresh()` / `fetchFailed` / `lastUpdated`（Task 7）、`MoodLevel.emoji/.color/.label`（Task 2）
- Produces: `struct AreaMoodView: View`。Task 9 が `AreaMoodDetailView(area:posts:)` と `AreaMoodPostSheet(viewModel:)` を実装するまでは、シート2つはプレースホルダの `Text` を出す（Task 9 で差し替え）

- [ ] **Step 1: View を実装する**

`ios/TyphoonRiskNavi/Views/AreaMoodView.swift` を作成:

```swift
import SwiftUI

/// 「みんな」タブ。10エリアの体感を地理配置に沿ったグリッドで表示する。
/// 3列グリッドの中央列が本島（北→南）、左列が西の離島、右上が大東、最下段が先島（西→東）。
struct AreaMoodView: View {
    @StateObject private var viewModel = AreaMoodViewModel.live()
    @State private var selectedArea: OkinawaArea?
    @State private var isShowingPostSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    disclaimer
                    if viewModel.fetchFailed {
                        fetchFailedBanner
                    }
                    areaGrid
                    if let lastUpdated = viewModel.lastUpdated {
                        Text("更新 \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("みんなの体感")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingPostSheet = true
                    } label: {
                        Label("投稿", systemImage: "plus.bubble")
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .task {
                await viewModel.refresh()
                viewModel.startAutoRefresh()
            }
            .onDisappear { viewModel.stopAutoRefresh() }
            .sheet(item: $selectedArea) { area in
                // Task 9 で AreaMoodDetailView に差し替える
                Text(area.displayName)
            }
            .sheet(isPresented: $isShowingPostSheet) {
                // Task 9 で AreaMoodPostSheet に差し替える
                Text("投稿")
            }
        }
    }

    /// 常時表示の免責。公式情報と誤認させない（スペック §1）。
    private var disclaimer: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2")
            Text("みんなの体感（公式情報ではありません）")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// 取得失敗時のバナー。前回の結果は出したまま、失敗だけ知らせる
    /// （DataSourceStatusBanner と同じ流儀）。
    private var fetchFailedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("更新できませんでした")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("再試行") {
                Task { await viewModel.refresh() }
            }
            .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    /// 地理関係のラフな再現:
    /// 　　　　　　　　［北部］
    /// ［久米島］　　　［中部］［大東］
    /// ［慶良間・粟国］［那覇］
    /// 　　　　　　　　［南部］
    /// ［与那国］　　　［石垣］［宮古］
    private var areaGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                spacerCell
                cell(.north)
                spacerCell
            }
            GridRow {
                cell(.kumejima)
                cell(.central)
                cell(.daito)
            }
            GridRow {
                cell(.keramaAguni)
                cell(.naha)
                spacerCell
            }
            GridRow {
                spacerCell
                cell(.south)
                spacerCell
            }
            GridRow {
                cell(.yonaguni)
                cell(.ishigaki)
                cell(.miyako)
            }
        }
    }

    private var spacerCell: some View {
        Color.clear
            .gridCellUnsizedAxes([.horizontal, .vertical])
    }

    private func cell(_ area: OkinawaArea) -> some View {
        let summary = viewModel.summaries[area]
        let level = summary?.representativeLevel
        return Button {
            selectedArea = area
        } label: {
            VStack(spacing: 4) {
                Text(level?.emoji ?? "－")
                    .font(.title2)
                Text(area.displayName)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(cellCaption(summary))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background((level?.color ?? Color.gray).opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke((level?.color ?? Color.gray).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func cellCaption(_ summary: AreaMoodSummary?) -> String {
        guard let summary, summary.postCount > 0, let level = summary.representativeLevel else {
            return "投稿なし"
        }
        return "\(level.label)・\(summary.postCount)件"
    }
}
```

- [ ] **Step 2: L10n キーとタブを追加する**

`ios/TyphoonRiskNavi/Resources/Localizable.swift` の `static let tabMap = "tab.map".localized` の並びに追加:

```swift
    static let tabMood = "tab.mood".localized
```

`ios/TyphoonRiskNavi/Resources/ja.lproj/Localizable.strings` に追加（既存の `"tab.map"` 等の並び）:

```
"tab.mood" = "みんな";
```

`ios/TyphoonRiskNavi/Resources/en.lproj/Localizable.strings` にも同じ行を追加（v1 は日本語のみの方針のため英語でも同文言）:

```
"tab.mood" = "みんな";
```

`ios/TyphoonRiskNavi/Views/MainTabView.swift` の `SettingsView()` ブロック（`.tag(2)` まで）の直後に追加:

```swift
            AreaMoodView()
                .tabItem {
                    Label(L10n.tabMood, systemImage: "person.3")
                }
                .tag(3)
```

注意: `AreaMoodView` は自前の `AreaMoodViewModel` を持つため `.environmentObject(viewModel)` は不要。

- [ ] **Step 3: ビルドが通ることを確認**

Run（ios/ から）: `xcodegen generate && xcodebuild build -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: 既存テストが全て通ることを確認（回帰チェック）**

Run: `xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: 全テスト PASS（既存92 + Task 1〜7 の新規分）

- [ ] **Step 5: スクショモードで見た目を確認**

シミュレータにインストールし `-screenshotMode YES` で起動、「みんな」タブを開く。
Expected: 10エリアのグリッドが表示され、全エリアに色・表情・件数が付く（サンプルデータ）。免責表示「みんなの体感（公式情報ではありません）」が出ている。

- [ ] **Step 6: コミット**

```bash
git add ios/TyphoonRiskNavi/Views/AreaMoodView.swift ios/TyphoonRiskNavi/Views/MainTabView.swift ios/TyphoonRiskNavi/Resources/Localizable.swift ios/TyphoonRiskNavi/Resources/ja.lproj/Localizable.strings ios/TyphoonRiskNavi/Resources/en.lproj/Localizable.strings ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: add the minna tab with the ten-area mood grid"
```

---

### Task 9: エリア詳細シートと投稿シート

**Files:**
- Create: `ios/TyphoonRiskNavi/Views/AreaMoodDetailView.swift`
- Create: `ios/TyphoonRiskNavi/Views/AreaMoodPostSheet.swift`
- Modify: `ios/TyphoonRiskNavi/Views/AreaMoodView.swift`（プレースホルダの sheet 2つを差し替え）

**Interfaces:**
- Consumes: `AreaMoodViewModel`（`post(area:level:phraseID:)` / `postError` / `postingBlockedReason` / `recentPosts`、Task 7）、`MoodPhraseCatalog`（Task 2）、`LocationManagerHelper`（既存: `requestLocation()` / `onLocation: ((CLLocation) -> Void)?` / `onFailure: (() -> Void)?` / `isAuthorized: Bool`）
- Produces: `struct AreaMoodDetailView: View`（`init(area: OkinawaArea, posts: [AreaMoodPost])`）、`struct AreaMoodPostSheet: View`（`init(viewModel: AreaMoodViewModel)`）

- [ ] **Step 1: 詳細シートを実装する**

`ios/TyphoonRiskNavi/Views/AreaMoodDetailView.swift` を作成:

```swift
import SwiftUI

/// エリアの体感内訳シート。レベル分布バーと直近投稿のリスト。
struct AreaMoodDetailView: View {
    let area: OkinawaArea
    let posts: [AreaMoodPost]   // 呼び出し側でこのエリアの直近3時間分に絞って渡す

    var body: some View {
        NavigationStack {
            List {
                if posts.isEmpty {
                    Text("直近3時間の投稿はありません")
                        .foregroundStyle(.secondary)
                } else {
                    Section("体感の内訳") {
                        distribution
                    }
                    Section("最近の投稿") {
                        ForEach(posts) { post in
                            HStack(spacing: 10) {
                                Text(post.level.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    // 未知の phraseID（将来バージョンのフレーズ）はレベルのラベルで代替
                                    Text(MoodPhraseCatalog.phrase(for: post.phraseID)?.text ?? post.level.label)
                                        .font(.subheadline)
                                    Text(relativeTime(post.createdAt))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(area.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    /// レベル5→1の順（重い方を上）に、件数を横棒で示す。
    private var distribution: some View {
        let counts = Dictionary(grouping: posts, by: \.level).mapValues(\.count)
        let maxCount = max(counts.values.max() ?? 1, 1)
        return ForEach(MoodLevel.allCases.reversed()) { level in
            let count = counts[level] ?? 0
            HStack(spacing: 8) {
                Text(level.emoji)
                Text(level.label)
                    .font(.caption)
                    .frame(width: 88, alignment: .leading)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level.color.opacity(0.6))
                        .frame(width: max(2, geo.size.width * CGFloat(count) / CGFloat(maxCount)))
                }
                .frame(height: 10)
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "たった今" }
        if minutes < 60 { return "\(minutes)分前" }
        return "\(minutes / 60)時間\(minutes % 60)分前"
    }
}
```

- [ ] **Step 2: 投稿シートを実装する**

`ios/TyphoonRiskNavi/Views/AreaMoodPostSheet.swift` を作成:

```swift
import SwiftUI

/// 体感の投稿シート。エリア → レベル → フレーズの3選択で完了する。
/// 位置情報の許可要求はユーザー操作（「現在地から選ぶ」ボタン）のときだけ行う（既存方針）。
/// 許可済みならシート表示時に黙って現在地からエリアを初期選択する（プロンプトは出ないため安全）。
struct AreaMoodPostSheet: View {
    @ObservedObject var viewModel: AreaMoodViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var locationHelper = LocationManagerHelper()
    @State private var selectedArea: OkinawaArea?
    @State private var selectedLevel: MoodLevel?
    @State private var selectedPhraseID: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("どのエリア？") {
                    Picker("エリア", selection: $selectedArea) {
                        Text("選択してください").tag(OkinawaArea?.none)
                        ForEach(OkinawaArea.allCases) { area in
                            Text(area.displayName).tag(OkinawaArea?.some(area))
                        }
                    }
                    Button {
                        detectAreaFromCurrentLocation()
                    } label: {
                        Label("現在地から選ぶ", systemImage: "location")
                    }
                }

                Section("いまの体感は？") {
                    ForEach(MoodLevel.allCases) { level in
                        Button {
                            selectedLevel = level
                            // レベルを変えたら、他レベルのフレーズ選択は無効にする
                            if let phraseID = selectedPhraseID,
                               MoodPhraseCatalog.phrase(for: phraseID)?.level != level {
                                selectedPhraseID = nil
                            }
                        } label: {
                            HStack {
                                Text(level.emoji)
                                Text(level.label)
                                Spacer()
                                if selectedLevel == level {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(level.color)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .listRowBackground(level.color.opacity(selectedLevel == level ? 0.25 : 0.06))
                    }
                }

                if let level = selectedLevel {
                    Section("ひとことで言うと？") {
                        ForEach(MoodPhraseCatalog.phrases(for: level)) { phrase in
                            Button {
                                selectedPhraseID = phrase.id
                            } label: {
                                HStack {
                                    Text(phrase.text)
                                    Spacer()
                                    if selectedPhraseID == phrase.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                if let message = viewModel.postError {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("体感を投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿する") { submit() }
                        .disabled(selectedArea == nil || selectedLevel == nil
                                  || selectedPhraseID == nil || isSubmitting)
                }
            }
            .onAppear {
                // レート制限中なら開いた時点で残り時間を見せる
                viewModel.postError = viewModel.postingBlockedReason
                // 許可済みなら黙って初期選択（未許可ならボタン操作まで何もしない）
                if locationHelper.isAuthorized, selectedArea == nil {
                    detectAreaFromCurrentLocation()
                }
            }
        }
        .presentationDetents([.large])
    }

    private func detectAreaFromCurrentLocation() {
        locationHelper.onLocation = { location in
            if let area = AreaMoodViewModel.area(for: location.coordinate) {
                selectedArea = area
            }
        }
        locationHelper.onFailure = {
            // 拒否・失敗時は自動選択しない（手動で選んでもらう）。スペック §10
        }
        locationHelper.requestLocation()
    }

    private func submit() {
        guard let area = selectedArea, let level = selectedLevel, let phraseID = selectedPhraseID else { return }
        isSubmitting = true
        Task {
            let succeeded = await viewModel.post(area: area, level: level, phraseID: phraseID)
            isSubmitting = false
            if succeeded { dismiss() }
        }
    }
}
```

- [ ] **Step 3: AreaMoodView のプレースホルダを差し替える**

`ios/TyphoonRiskNavi/Views/AreaMoodView.swift` の sheet 2つを差し替え（`// Task 9 で〜差し替える` コメントと `Text(...)` プレースホルダは削除）:

```swift
            .sheet(item: $selectedArea) { area in
                AreaMoodDetailView(
                    area: area,
                    posts: viewModel.recentPosts.filter { $0.area == area }
                )
            }
            .sheet(isPresented: $isShowingPostSheet) {
                AreaMoodPostSheet(viewModel: viewModel)
            }
```

- [ ] **Step 4: ビルドと全テストが通ることを確認**

Run: `xcodegen generate && xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: 全テスト PASS

- [ ] **Step 5: スクショモードで動作確認**

シミュレータで `-screenshotMode YES` 起動 →「みんな」タブ:
- エリアセルをタップ → 詳細シートに分布バーと投稿リストが出る
- 「投稿」→ シートでエリア・レベル・フレーズを選ぶと「投稿する」が有効になる
- 投稿する → シートが閉じ、グリッドに反映される（InMemory なので CloudKit には書かれない）
- 続けてもう一度投稿しようとすると「連続投稿はできません（あと約10分）」が出る

- [ ] **Step 6: コミット**

```bash
git add ios/TyphoonRiskNavi/Views/AreaMoodDetailView.swift ios/TyphoonRiskNavi/Views/AreaMoodPostSheet.swift ios/TyphoonRiskNavi/Views/AreaMoodView.swift ios/TyphoonRiskNavi.xcodeproj
git commit -m "feat: add the area detail sheet and the three-tap post flow"
```

---

### Task 10: Privacy Manifest 更新

**Files:**
- Modify: `ios/TyphoonRiskNavi/Resources/PrivacyInfo.xcprivacy:21-35`（`NSPrivacyCollectedDataTypes` 配列に1項目追加）

**Interfaces:**
- Consumes: なし
- Produces: なし（宣言ファイルのみ）

- [ ] **Step 1: 収集データ型を追加する**

`NSPrivacyCollectedDataTypes` の配列内、既存の Location dict（`NSPrivacyCollectedDataTypeLocation`）の後に追加:

```xml
		<dict>
			<!-- 体感投稿のエリア（沖縄10区分の粗い位置に相当）。ユーザーが選択した区分値のみを
			     CloudKit に送信し、精密な位置情報・ユーザー識別子は送らない -->
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeCoarseLocation</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<false/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
			</array>
		</dict>
```

- [ ] **Step 2: plist が壊れていないことを確認**

Run: `plutil -lint ios/TyphoonRiskNavi/Resources/PrivacyInfo.xcprivacy`
Expected: `OK`

- [ ] **Step 3: コミット**

```bash
git add ios/TyphoonRiskNavi/Resources/PrivacyInfo.xcprivacy
git commit -m "docs: declare the coarse-location mood area in the privacy manifest"
```

---

### Task 11: CloudKit 手動セットアップと全体検証（手動チェックポイント）

**Files:**
- Modify: `MEMORY.md`（リリース前チェックリスト追記のみ）

このタスクは **Apple Developer アカウントでの手動操作を含む**。エージェントは実施できる範囲で行い、できない項目はユーザーに明確に依頼して停止すること。

- [ ] **Step 1: CloudKit コンテナの作成**

Xcode でプロジェクトを開き、TyphoonRiskNavi ターゲットでビルド（Automatic signing が entitlements の `iCloud.com.example.OkinawaTyphoonNavi` コンテナを Developer アカウントに登録する）。コマンドラインの場合: `xcodebuild build -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -allowProvisioningUpdates`。署名エラーが出る場合はユーザーに Xcode での初回ビルドを依頼する。

- [ ] **Step 2: Development スキーマの作成とインデックス設定**

[CloudKit Console](https://icloud.developer.apple.com/) → コンテナ `iCloud.com.example.OkinawaTyphoonNavi` → Development 環境（ユーザーに依頼）:
1. Record Type `AreaMoodPost` を作成（またはシミュレータから1件投稿して just-in-time で自動作成）。フィールド: `area` (String) / `level` (Int64) / `phraseID` (String)
2. Indexes で `creationDate` に **Sortable** と **Queryable** を追加、`recordName` に **Queryable** を追加（これが無いと fetchPosts のクエリが `Field 'creationDate' is not marked queryable` で失敗する）

- [ ] **Step 3: シミュレータで CloudKit 経由の実投稿を確認**

シミュレータに iCloud サインイン（設定アプリ → サインイン）した状態で、スクショモード**なし**で起動:
- 「みんな」タブで投稿 → CloudKit Console の Development データに1件増える
- **アプリを再起動しても**投稿が取得・表示される（検証条件は過去の教訓どおり「既存データあり・再起動後」を標準とする）
- iCloud 未サインインのシミュレータでは投稿時に「投稿には iCloud サインインが必要です。設定アプリからサインインしてください」が出る（閲覧は可能）

- [ ] **Step 4: 全テスト実行（回帰）**

Run: `xcodebuild test -project TyphoonRiskNavi.xcodeproj -scheme TyphoonRiskNavi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: 全テスト PASS（既存92 + 新規37: Task1=6, Task2=6, Task3=6, Task4=4, Task5=4, Task6=4, Task7=7）

- [ ] **Step 5: リリース前チェックリストを記録**

`MEMORY.md` の末尾に本機能のリリース手順として以下を追記する（リリース作業自体はこの計画の範囲外）:

```markdown
## みんなの体感リポート: リリース前チェックリスト（未リリース）
- [ ] CloudKit Console でスキーマを **Deploy Schema Changes to Production**（忘れると審査環境・本番で機能が全く動かない）
- [ ] App Store Connect の App Privacy 回答に「おおよその位置情報（非リンク・非トラッキング・アプリ機能）」を追加
- [ ] MARKETING_VERSION と CURRENT_PROJECT_VERSION をセットで上げる（0.9.5 → 0.9.6 等。トレイン閉鎖の教訓）
```

- [ ] **Step 6: コミット**

```bash
git add MEMORY.md
git commit -m "docs: record the CloudKit production-deploy checklist for mood posts"
```

---

## 実行順序と依存関係

```
Task 1 (エリア) ──→ Task 2 (モデル・フレーズ) ──┬─→ Task 3 (集約)
                                                ├─→ Task 5 (Store protocol + InMemory) ←─ Task 3（テストで window を参照）
                                                │        │
                                                │        ├─→ Task 6 (CloudKit + entitlements)
                                                │        └─→ Task 7 (ViewModel) ←─ Task 3, 4, 6
                                                │                 │
                                                │                 ├─→ Task 8 (グリッド + タブ)
                                                │                 └─→ Task 9 (シート2種) ←─ Task 8
Task 4 (レート制限) は独立（いつでも可）
Task 10 (Privacy Manifest) は独立（いつでも可）
Task 11 (手動セットアップ・検証) は最後
```

Task 1〜7 は純ロジックでシミュレータのテストのみで完結する。Task 8〜9 は UI で、ビルド＋スクショモードの目視確認を検証手段とする。Task 11 のみ Apple Developer アカウントの手動操作を含む。
