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
        // queryCursor は意図的に破棄している。「直近の投稿」フィードは limit 件で打ち切れば十分で、
        // 続きを取りにいく UI（もっと見る等）が存在しないため、ページネーションはしない。
        let (results, _) = try await database.records(matching: query, resultsLimit: limit)
        return results.compactMap { recordID, result in
            switch result {
            case .success(let record):
                guard let post = Self.post(from: record) else {
                    // 未知の area/level（新バージョンが追加した値の可能性がある）で読めなかった場合。
                    // post(from:) のコメントの通り前方互換のための想定内の経路だが、
                    // 「投稿なし」に見えるだけで原因が追えなくならないよう記録しておく。
                    #if DEBUG
                    print("CloudKitMoodPostStore.fetchPosts: record \(recordID.recordName) has an unknown area/level (possibly a newer app version)")
                    #endif
                    return nil
                }
                return post
            case .failure(let error):
                #if DEBUG
                print("CloudKitMoodPostStore.fetchPosts: dropped record \(recordID.recordName): \(error)")
                #endif
                return nil
            }
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
        // save は既に成功している。ここから先で失敗を投げると「保存済みなのに失敗と表示され、
        // レート制限がリトライも塞ぐ」という状態になるため、変換に失敗し得ない材料だけで組み立てる。
        // area/level/phraseID は直前で有効な enum の rawValue から作った値そのものなので必ず有効。
        return AreaMoodPost(
            id: saved.recordID.recordName,
            area: area,
            level: level,
            phraseID: phraseID,
            createdAt: saved.creationDate ?? Date()
        )
    }

    /// CKRecord → AreaMoodPost 変換。未知のエリア・範囲外レベルは nil（呼び出し側で読み飛ばす）。
    /// 将来のバージョンがエリアやレベルを増やしても、旧バージョンがクラッシュせず無視できるようにする。
    /// creationDate は保存前のローカルレコードでは nil のため、現在時刻で代替する。
    /// この関数を呼ぶのは fetchPosts（サーバーから返る保存済みレコードなので creationDate は必ずある）
    /// だけなので、このフォールバックは実運用では実質到達不能（テストが未保存レコードを直接渡して検証している）。
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
