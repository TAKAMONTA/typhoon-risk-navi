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
        // 未保存のローカルレコードには creationDate が付かないため、
        // 実装は現在時刻に代替するはず（distantPast 等の固定デフォルトへのすり替えを検知する）。
        XCTAssertEqual(post?.createdAt.timeIntervalSinceNow ?? .infinity, 0, accuracy: 5)
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

    /// area と phraseID を取り違えていないか（値の形式が違うので、
    /// 入れ替わっていれば area のパースに失敗して nil になる）。
    func testAreaAndPhraseIDAreNotSwapped() {
        let record = makeRecord(area: "miyako", level: 2, phraseID: "L2_rain_started")
        let post = CloudKitMoodPostStore.post(from: record)
        XCTAssertEqual(post?.area, .miyako)
        XCTAssertEqual(post?.phraseID, "L2_rain_started")
    }
}
