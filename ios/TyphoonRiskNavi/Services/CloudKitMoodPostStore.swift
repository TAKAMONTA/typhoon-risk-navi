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
            case .notSignedIn: return L10n.moodErrorNotSignedIn
            case .invalidRecord: return L10n.moodErrorInvalidRecord
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
        // CloudKit の resultsLimit は 0 を「サーバが返せるだけ返す」と解釈するため、
        // そのまま渡すと limit: 0 が全件取得になる。InMemoryMoodPostStore の
        // prefix(0) と挙動を揃えるため、ここで打ち切る。
        guard limit > 0 else { return [] }
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
