import Foundation
import CoreLocation

// MARK: - Shared Models (matching backend)

struct Typhoon: Codable, Identifiable {
    let id: String
    let name: String
    let nameJa: String?
    let source: String
    let status: String
    let currentCenter: Coordinate
    let maxWindSpeed: Double?
    let centralPressure: Int?
    let direction: Int?
    let speed: Double?
    let windRadii: WindRadii?   // 現在位置の風速半径（34/50/64kt）
    let forecasts: [ForecastPoint]
    let lastUpdated: String
}

struct Coordinate: Codable {
    let lat: Double
    let lon: Double
    
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct ForecastPoint: Codable {
    let validTime: String
    let center: Coordinate
    let radius: Double?           // 予報円半径 (km)
    let maxWindSpeed: Double?
    
    // 風速半径（34kt / 50kt / 64kt）
    let windRadii: WindRadii?
}

struct WindRadii: Codable {
    let radius34kt: Double?   // 34kt (強風域) の半径 km
    let radius50kt: Double?   // 50kt の半径 km
    let radius64kt: Double?   // 64kt (暴風域) の半径 km
}

struct SavedLocation: Codable, Identifiable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let notificationLevel: String?   // "LOW", "MEDIUM", "HIGH", "SEVERE"
}

struct RiskAssessment: Codable, Identifiable {
    let locationId: String
    let locationName: String
    let typhoonId: String
    let typhoonName: String
    
    let arrival34kt: ArrivalInfo?
    let arrival50kt: ArrivalInfo?
    let arrival64kt: ArrivalInfo?
    
    let estimatedClosestApproach: String?
    let distanceToClosestKm: Int?
    let currentDistanceKm: Int
    
    let riskLevel: String
    let source: String
    let calculatedAt: String
    let notes: [String]?
    
    var id: String { locationId }
    
    struct ArrivalInfo: Codable {
        let time: String
        let hours: Double
    }
}

// MARK: - API Response Models

struct DemoStateResponse: Codable {
    let typhoon: Typhoon
    let risks: [RiskAssessment]
    let savedLocations: [SavedLocation]
    let lastUpdated: String
}
