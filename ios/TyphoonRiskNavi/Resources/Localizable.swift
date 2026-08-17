import Foundation
import SwiftUI

// MARK: - Localization Helper
extension String {
    /// Returns the localized string for the current key.
    /// Falls back to English if the key is missing in the current language.
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized string with format arguments.
    func localized(_ args: CVarArg...) -> String {
        String(format: self.localized, locale: .current, arguments: args)
    }
}

// MARK: - Localized String Keys
// Use these constants throughout the app for type safety and easy maintenance.

enum L10n {
    // Tabs
    static let tabMap = "tab.map".localized
    static let tabLocations = "tab.locations".localized
    static let tabSettings = "tab.settings".localized
    static let tabMood = "tab.mood".localized

    // General
    static let retry = "retry".localized
    static let errorDataFetchFailed = "error.data_fetch_failed".localized
    static let realData = "real_data".localized
    static let demoData = "demo_data".localized
    static let demoDataError = "demo_data_error".localized

    // Onboarding
    static let onboardingTitle = "onboarding.title".localized
    static let onboardingSkip = "onboarding.skip".localized
    static let onboardingStart = "onboarding.start".localized
    static let onboardingFootnote = "onboarding.footnote".localized
    static let onboardingMapTitle = "onboarding.map.title".localized
    static let onboardingMapMessage = "onboarding.map.message".localized
    static let onboardingLocationsTitle = "onboarding.locations.title".localized
    static let onboardingLocationsMessage = "onboarding.locations.message".localized
    static let onboardingDataTitle = "onboarding.data.title".localized
    static let onboardingDataMessage = "onboarding.data.message".localized
    static let onboardingPrivacyTitle = "onboarding.privacy.title".localized
    static let onboardingPrivacyMessage = "onboarding.privacy.message".localized
    
    // Precision Model
    static func precisionModel(_ percent: Double) -> String {
        String(format: "precision_model".localized, percent)
    }
    
    // Locations
    static let locationsEmptyTitle = "locations.empty.title".localized
    static let locationsEmptyDescription = "locations.empty.description".localized
    static let locationsAddManual = "locations.add_manual".localized
    static let locationsAddCurrent = "locations.add_current".localized
    static let locationsAddTitle = "locations.add.title".localized
    static let locationsEditTitle = "locations.edit.title".localized
    static let locationsCancel = "locations.cancel".localized
    static let locationsOpenSettings = "locations.open_settings".localized
    static let locationsRealDataFailure = "locations.real_data_failure".localized
    
    // Settings
    static let settingsCurrentlyUsing = "settings.currently_using".localized
    static let settingsRealDataDesc = "settings.real_data_desc".localized
    static let settingsDemoDataDesc = "settings.demo_data_desc".localized
    static let settingsDemoErrorDesc = "settings.demo_error_desc".localized
    static func settingsErrorPrefix(_ message: String) -> String {
        "settings.error_prefix".localized + message
    }
    static func settingsLastRealData(_ time: String) -> String {
        String(format: "settings.last_real_data".localized, time)
    }
    static let settingsNotificationsSection = "settings.notifications_section".localized
    static let settingsNotificationStrongWind = "settings.notification_strong_wind".localized
    static let settingsNotificationPathUpdate = "settings.notification_path_update".localized
    static let settingsNotificationNote = "settings.notification_note".localized
    static let notificationPermissionTitle = "notification.permission.title".localized
    static let notificationPermissionMessage = "notification.permission.message".localized
    static let notificationStrongWindTitle = "notification.strong_wind.title".localized
    static func notificationStrongWindBody(_ place: String, _ hours: Int) -> String {
        String(format: "notification.strong_wind.body".localized, place, hours)
    }
    static let notificationPathUpdateTitle = "notification.path_update.title".localized
    static func notificationPathUpdateBody(_ name: String) -> String {
        String(format: "notification.path_update.body".localized, name)
    }
    static let mapSummaryWarningTitle = "map.summary.warning.title".localized
    static let mapSummaryWarningEvacuationHint = "map.summary.warning.evacuation_hint".localized
    static let mapSummaryWarningUnavailable = "map.summary.warning.unavailable".localized
    static let mapSummaryOpenWarningDetail = "map.summary.open_warning_detail".localized
    static let warningNoneHeadline = "warning.none.headline".localized
    static let warningStaleNotice = "warning.stale_notice".localized
    static func warningLastReport(_ time: String) -> String {
        String(format: "warning.last_report".localized, time)
    }
    static let settingsReloadData = "settings.reload_data".localized
    static let settingsVersion = "settings.version".localized
    static let settingsBuild = "settings.build".localized
    static let settingsAppDescription = "settings.app_description".localized
    static let settingsPrecisionModelTitle = "settings.precision_model_title".localized
    static let settingsPrecisionModelDesc = "settings.precision_model_desc".localized
    static let settingsPrecisionModelDetail = "settings.precision_model_detail".localized
    
    // Map
    static let mapTitle = "map.title".localized
    static let mapRealData = "map.real_data".localized
    static let mapRealDataFailure = "map.real_data_failure".localized
    
    // DataSourceStatusBanner
    static let bannerDemoInUse = "banner.demo_in_use".localized
    static let bannerNoTyphoon = "banner.no_typhoon".localized
    static let bannerNoTyphoonDetail = "banner.no_typhoon_detail".localized
    static let bannerRealDataFailure = "banner.real_data_failure".localized
    
    // LocationsView additional
    static let locationsPermissionRequired = "locations.permission_required".localized
    static func locationsHoursStrongWind(_ hours: Int) -> String {
        String(format: "locations.hours_strong_wind".localized, hours)
    }
    static func locationsHoursToLevel(_ level: String, _ hours: Int) -> String {
        String(format: "locations.hours_to_level".localized, level, hours)
    }
    static func locationsCurrentDistance(_ dist: Int) -> String {
        String(format: "locations.current_distance".localized, dist)
    }
    static let locationsNoRiskInfo = "locations.no_risk_info".localized
    static let locationsNotSet = "locations.not_set".localized
    
    // TyphoonMapView summary card
    static let mapSummaryMostUrgent = "map.summary.most_urgent".localized
    static let mapSummaryYourRisk = "map.summary.your_risk".localized
    static let mapSummaryNoRiskYet = "map.summary.no_risk_yet".localized
    static func mapSummaryHoursToGale(_ hours: Int) -> String {
        String(format: "map.summary.hours_to_gale".localized, hours)
    }
    static func mapSummaryHoursToStorm(_ hours: Int) -> String {
        String(format: "map.summary.hours_to_storm".localized, hours)
    }
    static let mapSummaryActionSevere = "map.summary.action.severe".localized
    static let mapSummaryActionHigh = "map.summary.action.high".localized
    static let mapSummaryActionMedium = "map.summary.action.medium".localized
    static let mapSummaryActionLow = "map.summary.action.low".localized
    static let mapSummaryNoLocations = "map.summary.no_locations".localized
    static let mapSummaryDemoLabel = "map.summary.demo_label".localized
    static let mapSummaryMunicipalityTitle = "map.summary.municipality.title".localized
    static func mapSummaryMunicipalityDistance(_ km: Int) -> String {
        String(format: "map.summary.municipality.distance".localized, km)
    }
    static func mapSummaryMunicipalityDistanceFromCurrent(_ km: Int) -> String {
        String(format: "map.summary.municipality.distance_from_current".localized, km)
    }
    static let mapSummaryMunicipalityHint = "map.summary.municipality.hint".localized
    static let mapSummaryMunicipalityNeedLocation = "map.summary.municipality.need_location".localized
    static let mapSummaryOpenDisaster = "map.summary.open_disaster".localized
    static let mapSummaryOpenEvacuation = "map.summary.open_evacuation".localized
    static let mapSummaryOpenPrefecture = "map.summary.open_prefecture".localized
    static let mapSummaryOpenJMA = "map.summary.open_jma".localized
    static func mapSummaryTyphoonPosition(_ anchorName: String, _ direction: String, _ km: Int) -> String {
        String(format: "map.summary.typhoon_position".localized, anchorName, direction, km)
    }
    static let mapAnchorOkinawa = "map.anchor.okinawa".localized
    static let mapSummaryTyphoonFarHint = "map.summary.typhoon_far_hint".localized
    static let mapSummaryExpand = "map.summary.expand".localized
    static let mapSummaryCollapse = "map.summary.collapse".localized

    // Data freshness
    static let lastRealDataJustNow = "last_real_data.just_now".localized
    static func lastRealData(_ relative: String) -> String {
        String(format: "last_real_data.relative".localized, relative)
    }

    // Map focus controls
    static let mapFocusHome = "map.focus.home".localized
    static let mapFocusTyphoon = "map.focus.typhoon".localized
    static let mapFocusCurrentLocation = "map.focus.current_location".localized

    /// 8方位。index は北=0 から時計回り。
    static func compassDirection(_ index: Int) -> String {
        let keys = [
            "compass.n", "compass.ne", "compass.e", "compass.se",
            "compass.s", "compass.sw", "compass.w", "compass.nw",
        ]
        guard keys.indices.contains(index) else { return "" }
        return keys[index].localized
    }
    static func riskLevelLabel(_ level: String) -> String {
        switch level {
        case "SEVERE": return "risk.level.severe".localized
        case "HIGH": return "risk.level.high".localized
        case "MEDIUM": return "risk.level.medium".localized
        case "LOW": return "risk.level.low".localized
        default: return level
        }
    }

    // Action guide (知る → 対策する)
    static let mapSummaryActionsTitle = "map.summary.actions.title".localized
    static let mapSummaryActionsQuietTitle = "map.summary.actions.quiet_title".localized
    static let actionSevere1 = "action.severe.1".localized
    static let actionSevere2 = "action.severe.2".localized
    static let actionSevere3 = "action.severe.3".localized
    static let actionSevere4 = "action.severe.4".localized
    static let actionHigh1 = "action.high.1".localized
    static let actionHigh2 = "action.high.2".localized
    static let actionHigh3 = "action.high.3".localized
    static let actionHigh4 = "action.high.4".localized
    static let actionMedium1 = "action.medium.1".localized
    static let actionMedium2 = "action.medium.2".localized
    static let actionMedium3 = "action.medium.3".localized
    static let actionLow1 = "action.low.1".localized
    static let actionLow2 = "action.low.2".localized
    static let actionLow3 = "action.low.3".localized
    static let actionQuiet1 = "action.quiet.1".localized
    static let actionQuiet2 = "action.quiet.2".localized
    static let actionQuiet3 = "action.quiet.3".localized

    // TyphoonMapView legend
    static let mapWindRadii = "map.wind_radii".localized
    static let map34ktStrong = "map.34kt_strong".localized
    static let map50kt = "map.50kt".localized
    static let map64ktViolent = "map.64kt_violent".localized
    
    // General additional
    static func hoursSuffix(_ hours: Int) -> String {
        String(format: "hours_suffix".localized, hours)
    }
    
    // Settings additional
    static let settingsDataSourceSection = "settings.data_source_section".localized
    static let settingsDemoData = "settings.demo_data".localized
    static let settingsDemoDataError = "settings.demo_data_error".localized
    static let settingsUsingDemoBecauseNoReal = "settings.using_demo_because_no_real".localized
    static let settingsNoTyphoonDesc = "settings.no_typhoon_desc".localized
    static let settingsUsingDemoBecauseFetchFailed = "settings.using_demo_because_fetch_failed".localized

    static let alertLocationPermissionTitle = "alert.location_permission_title".localized

    // Area Mood (みんな) - area names
    static func areaDisplayName(_ area: OkinawaArea) -> String {
        switch area {
        case .naha: return "area.naha".localized
        case .south: return "area.south".localized
        case .central: return "area.central".localized
        case .north: return "area.north".localized
        case .keramaAguni: return "area.kerama_aguni".localized
        case .kumejima: return "area.kumejima".localized
        case .miyako: return "area.miyako".localized
        case .ishigaki: return "area.ishigaki".localized
        case .yonaguni: return "area.yonaguni".localized
        case .daito: return "area.daito".localized
        }
    }

    // Area Mood (みんな) - mood level labels
    static func moodLevelLabel(_ level: MoodLevel) -> String {
        switch level {
        case .calm: return "mood.level.calm".localized
        case .breezy: return "mood.level.breezy".localized
        case .stormy: return "mood.level.stormy".localized
        case .dangerous: return "mood.level.dangerous".localized
        case .violent: return "mood.level.violent".localized
        }
    }

    // Area Mood (みんな) - phrase catalog
    static func moodPhraseText(_ id: String) -> String {
        "mood.phrase.\(id.lowercased())".localized
    }

    // Area Mood (みんな) - screen
    static let moodTitle = "mood.title".localized
    static let moodPostAction = "mood.post_action".localized
    static let moodDisclaimer = "mood.disclaimer".localized
    static let moodFetchFailed = "mood.fetch_failed".localized
    static func moodUpdatedAt(_ time: String) -> String {
        String(format: "mood.updated_at".localized, time)
    }
    static let moodNoPosts = "mood.no_posts".localized
    static func moodCellCaption(_ levelLabel: String, _ count: Int) -> String {
        String(format: "mood.cell_caption".localized, levelLabel, count)
    }
    static func moodCellAccessibilityLabel(_ areaName: String, _ caption: String) -> String {
        String(format: "mood.cell_accessibility_label".localized, areaName, caption)
    }

    // Area Mood (みんな) - detail sheet
    static let moodDetailNoRecentPosts = "mood.detail.no_recent_posts".localized
    static let moodDetailBreakdown = "mood.detail.breakdown".localized
    static let moodDetailRecentPosts = "mood.detail.recent_posts".localized
    static let moodTimeJustNow = "mood.time.just_now".localized
    static func moodTimeMinutesAgo(_ minutes: Int) -> String {
        String(format: "mood.time.minutes_ago".localized, minutes)
    }
    static func moodTimeHoursMinutesAgo(_ hours: Int, _ minutes: Int) -> String {
        String(format: "mood.time.hours_minutes_ago".localized, hours, minutes)
    }

    // Area Mood (みんな) - post sheet
    static let moodPostAreaSection = "mood.post.area_section".localized
    static let moodPostAreaPickerLabel = "mood.post.area_picker_label".localized
    static let moodPostSelectPlaceholder = "mood.post.select_placeholder".localized
    static let moodPostUseCurrentLocation = "mood.post.use_current_location".localized
    static let moodPostLevelSection = "mood.post.level_section".localized
    static let moodPostPhraseSection = "mood.post.phrase_section".localized
    static let moodPostTitle = "mood.post.title".localized
    static let moodPostSubmit = "mood.post.submit".localized

    // Area Mood (みんな) - errors
    static func moodRateLimited(_ minutes: Int) -> String {
        String(format: "mood.rate_limited".localized, minutes)
    }
    static let moodPostFailedGeneric = "mood.post_failed_generic".localized
    static let moodErrorNotSignedIn = "mood.error.not_signed_in".localized
    static let moodErrorInvalidRecord = "mood.error.invalid_record".localized
}