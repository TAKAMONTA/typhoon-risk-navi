import Foundation
import Combine

/// 保存場所を端末ローカルに永続化する観察可能ストア。
/// UserDefaults JSON でシンプルに持つ（数十件想定なので十分高速）。
///
/// 将来的に件数が多くなる、または iCloud 同期が欲しくなった時点で
/// SwiftData / CloudKit に移すパスが残るよう、I/F を Codable ベースに保つ。
@MainActor
final class LocalLocationStore: ObservableObject {

    static let shared = LocalLocationStore()

    @Published private(set) var locations: [SavedLocation] = []

    private let defaults: UserDefaults
    private let storeKey: String
    private let seedFlagKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storeKey: String = "saved_locations_v1",
        seedFlagKey: String = "has_seeded_demo_locations_v1"
    ) {
        self.defaults = defaults
        self.storeKey = storeKey
        self.seedFlagKey = seedFlagKey
        self.locations = load()
    }

    // MARK: - CRUD

    func add(name: String, lat: Double, lon: Double, notificationLevel: String? = nil) -> SavedLocation {
        let new = SavedLocation(
            id: UUID().uuidString,
            name: name,
            lat: lat,
            lon: lon,
            notificationLevel: notificationLevel
        )
        locations.append(new)
        save()
        return new
    }

    func delete(id: String) {
        locations.removeAll { $0.id == id }
        save()
    }

    func deleteAll(ids: [String]) {
        let set = Set(ids)
        locations.removeAll { set.contains($0.id) }
        save()
    }

    func update(
        id: String,
        name: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        notificationLevel: String? = nil
    ) -> SavedLocation? {
        guard let idx = locations.firstIndex(where: { $0.id == id }) else { return nil }
        let old = locations[idx]
        let updated = SavedLocation(
            id: old.id,
            name: name ?? old.name,
            lat: lat ?? old.lat,
            lon: lon ?? old.lon,
            notificationLevel: notificationLevel ?? old.notificationLevel
        )
        locations[idx] = updated
        save()
        return updated
    }

    func setNotificationLevel(id: String, level: String) -> SavedLocation? {
        return update(id: id, notificationLevel: level)
    }

    // MARK: - Demo Seed

    /// 初回起動時にデモ場所を投入する。冪等：既にシード済みフラグが立っていれば何もしない。
    func seedDemoLocationsIfNeeded() {
        guard !defaults.bool(forKey: seedFlagKey) else { return }
        // 既に何かしらの場所があれば（ユーザーがすでに使い始めていれば）シードしない
        guard locations.isEmpty else {
            defaults.set(true, forKey: seedFlagKey)
            return
        }
        locations = DemoData.seedLocations
        save()
        defaults.set(true, forKey: seedFlagKey)
    }

    // MARK: - Persistence

    private func load() -> [SavedLocation] {
        guard let data = defaults.data(forKey: storeKey) else { return [] }
        return (try? decoder.decode([SavedLocation].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(locations) else { return }
        defaults.set(data, forKey: storeKey)
    }
}
