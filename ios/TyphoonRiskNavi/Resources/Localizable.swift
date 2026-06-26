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
    
    // General
    static let retry = "retry".localized
    static let errorDataFetchFailed = "error.data_fetch_failed".localized
    static let realData = "real_data".localized
    static let demoData = "demo_data".localized
    static let demoDataError = "demo_data_error".localized
    
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
    static let settingsUsingDemoBecauseFetchFailed = "settings.using_demo_because_fetch_failed".localized

    static let alertLocationPermissionTitle = "alert.location_permission_title".localized
}