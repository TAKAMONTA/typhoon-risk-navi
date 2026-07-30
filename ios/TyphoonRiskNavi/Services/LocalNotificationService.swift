import Foundation
import UserNotifications

/// 通知の ON/OFF 設定（UserDefaults）。
enum NotificationPreferences {
    static let strongWindKey = "notifyStrongWindApproach"
    static let pathUpdateKey = "notifyTyphoonPathUpdate"

    static var strongWindEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: strongWindKey) }
        set { UserDefaults.standard.set(newValue, forKey: strongWindKey) }
    }

    static var pathUpdateEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: pathUpdateKey) }
        set { UserDefaults.standard.set(newValue, forKey: pathUpdateKey) }
    }
}

/// 端末内のローカル通知。サーバー不要。
/// - 強風域接近: 保存場所の到達予測に基づき予約
/// - 進路更新: 台風ID/中心が変わったときに即時通知
@MainActor
final class LocalNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let lastTyphoonSignatureKey = "lastNotifiedTyphoonSignature"

    override init() {
        super.init()
        center.delegate = self
    }

    /// 通知許可を求める。許可されれば true。
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    /// データ更新後に通知を組み直す。
    func refreshNotifications(
        risks: [RiskAssessment],
        typhoon: Typhoon?,
        dataSourceIsReal: Bool
    ) async {
        await cancelPending(withPrefix: "strong-wind-")

        guard !UserDefaults.standard.bool(forKey: "screenshotMode") else { return }

        if NotificationPreferences.strongWindEnabled {
            await scheduleStrongWindNotifications(risks: risks)
        }

        if NotificationPreferences.pathUpdateEnabled, dataSourceIsReal, let typhoon {
            await notifyPathUpdateIfNeeded(typhoon: typhoon)
        } else if typhoon == nil {
            UserDefaults.standard.removeObject(forKey: lastTyphoonSignatureKey)
        }
    }

    private func scheduleStrongWindNotifications(risks: [RiskAssessment]) async {
        let leadHours: [Double] = [24, 12, 6]
        let now = Date()

        for risk in risks {
            guard let hours = relevantHours(for: risk), hours > 0.5 else { continue }
            let arrivalDate = now.addingTimeInterval(hours * 3600)

            for lead in leadHours {
                let fireDate = arrivalDate.addingTimeInterval(-lead * 3600)
                guard fireDate > now.addingTimeInterval(60) else { continue }

                let id = "strong-wind-\(risk.locationId)-\(Int(lead))"
                let content = UNMutableNotificationContent()
                content.title = L10n.notificationStrongWindTitle
                content.body = L10n.notificationStrongWindBody(risk.locationName, Int(lead))
                content.sound = .default

                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    private func relevantHours(for risk: RiskAssessment) -> Double? {
        let candidates = [
            risk.arrival64kt?.hours,
            risk.arrival50kt?.hours,
            risk.arrival34kt?.hours
        ].compactMap { $0 }
        return candidates.min()
    }

    private func notifyPathUpdateIfNeeded(typhoon: Typhoon) async {
        let signature = "\(typhoon.id)|\(typhoon.currentCenter.lat),\(typhoon.currentCenter.lon)|\(typhoon.lastUpdated)"
        let previous = UserDefaults.standard.string(forKey: lastTyphoonSignatureKey)
        UserDefaults.standard.set(signature, forKey: lastTyphoonSignatureKey)

        guard let previous, previous != signature else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.notificationPathUpdateTitle
        content.body = L10n.notificationPathUpdateBody(typhoon.nameJa ?? typhoon.name)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "path-update-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func cancelPending(withPrefix prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
