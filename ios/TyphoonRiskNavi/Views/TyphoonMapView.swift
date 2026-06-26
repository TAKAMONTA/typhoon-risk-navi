import SwiftUI
import MapKit

struct TyphoonMapView: View {
    @EnvironmentObject private var viewModel: TyphoonViewModel

    /// App Store スクショ撮影モードか。`-screenshotMode YES` で起動時に true。
    private var isScreenshotMode: Bool {
        UserDefaults.standard.bool(forKey: "screenshotMode")
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView(viewModel.loadingContext ?? "台風データを読み込み中...")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "データの取得に失敗しました",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .overlay(alignment: .bottom) {
                        Button {
                            Task { await viewModel.loadData() }
                        } label: {
                            Label(L10n.retry, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                    }
                } else if let state = viewModel.state {
                    Map(initialPosition: .region(viewModel.mapRegion)) {
                        // 予報進路ライン
                        if viewModel.trackCoordinates.count > 1 {
                            MapPolyline(coordinates: viewModel.trackCoordinates)
                                .stroke(.orange, lineWidth: 3)
                        }
                        
                        // 予報円（Forecast Circles）
                        ForEach(viewModel.forecastCircles) { circle in
                            MapCircle(center: circle.center, radius: circle.radius)
                                .foregroundStyle(.orange.opacity(0.12))
                                .stroke(.orange, lineWidth: 1)
                        }
                        
                        // 風速半径（Wind Radii） - 現在位置
                        ForEach(viewModel.currentWindRadii) { windCircle in
                            MapCircle(center: windCircle.center, radius: windCircle.radius)
                                .foregroundStyle(windCircle.color.opacity(0.18))
                                .stroke(windCircle.color, lineWidth: 2)
                        }
                        
                        // 風速半径（Wind Radii） - 将来の予報位置
                        ForEach(viewModel.forecastWindRadii) { windCircle in
                            MapCircle(center: windCircle.center, radius: windCircle.radius)
                                .foregroundStyle(windCircle.color.opacity(0.12))
                                .stroke(windCircle.color.opacity(0.6), lineWidth: 1.5)
                        }
                        
                        // 台風の現在位置（一番目立つ）
                        Annotation(state.typhoon.nameJa ?? state.typhoon.name, 
                                   coordinate: state.typhoon.currentCenter.clLocation) {
                            VStack(spacing: 4) {
                                Image(systemName: "hurricane.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.title)
                                    .shadow(radius: 2)
                                
                                Text(state.typhoon.nameJa ?? state.typhoon.name)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.red.opacity(0.9))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        // 保存場所 + リスク（実データ時はクライアント計算を優先）
                        let displayRisks = viewModel.displayRisks.isEmpty ? state.risks : viewModel.displayRisks
                        
                        ForEach(displayRisks) { risk in
                            if let loc = state.savedLocations.first(where: { $0.id == risk.locationId }) {
                                Annotation(risk.locationName, coordinate: loc.coordinate) {
                                    SavedLocationMarkerView(risk: risk, location: loc)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .overlay(alignment: .topTrailing) {
                        // 凡例
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.mapWindRadii)
                                .font(.caption.bold())
                            
                            HStack {
                                Circle().fill(.yellow.opacity(0.3)).frame(width: 8, height: 8)
                                Text(L10n.map34ktStrong)
                                    .font(.caption2)
                            }
                            HStack {
                                Circle().fill(.orange.opacity(0.3)).frame(width: 8, height: 8)
                                Text(L10n.map50kt)
                                    .font(.caption2)
                            }
                            HStack {
                                Circle().fill(.red.opacity(0.3)).frame(width: 8, height: 8)
                                Text(L10n.map64ktViolent)
                                    .font(.caption2)
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(8)
                    }
                    .overlay(alignment: .bottom) {
                        if !isScreenshotMode {
                            RiskSummaryCard(viewModel: viewModel)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                        }
                    }

                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "データを取得できません",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    ContentUnavailableView(
                        "データがありません",
                        systemImage: "cloud",
                        description: Text(L10n.errorDataFetchFailed)
                    )
                }
            }
            .navigationTitle(L10n.mapTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if case .demoDueToError = viewModel.dataSourceStatus {
                        Text(L10n.mapRealDataFailure)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if viewModel.isUsingRealData {
                        HStack(spacing: 6) {
                            Text(L10n.mapRealData)
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                            
                            if let decay = viewModel.currentDynamicDecayRate {
                                Text(L10n.precisionModel(decay))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.green.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if !viewModel.hasData {
                    await viewModel.loadData()
                }
            }
        }
    }
}

// MARK: - Risk Summary Card

/// 地図下部に「今日見るべきこと」をまとめて表示するカード。
struct RiskSummaryCard: View {
    @ObservedObject var viewModel: TyphoonViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusBadgeRow

            switch viewModel.dataSourceStatus {
            case .noTyphoon:
                noTyphoonContent
            case .demoDueToError(let message):
                errorContent(message: message)
            default:
                typhoonRiskContent
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    @ViewBuilder
    private var statusBadgeRow: some View {
        HStack(spacing: 8) {
            switch viewModel.dataSourceStatus {
            case .real:
                statusBadge(text: L10n.realData, color: .green)
            case .demo:
                statusBadge(text: L10n.mapSummaryDemoLabel, color: .gray)
            case .noTyphoon:
                statusBadge(text: L10n.bannerNoTyphoon, color: .blue)
            case .demoDueToError:
                statusBadge(text: L10n.demoDataError, color: .orange)
            }

            if let last = viewModel.lastRealDataDescription {
                Text(last)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var noTyphoonContent: some View {
        Text(L10n.bannerNoTyphoonDetail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func errorContent(message: String) -> some View {
        if let typhoon = viewModel.state?.typhoon {
            Text(typhoon.nameJa ?? typhoon.name)
                .font(.headline)
        }
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        Button {
            Task { await viewModel.loadData() }
        } label: {
            Label(L10n.retry, systemImage: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .controlSize(.small)
    }

    @ViewBuilder
    private var typhoonRiskContent: some View {
        if let typhoon = viewModel.state?.typhoon {
            Text(typhoon.nameJa ?? typhoon.name)
                .font(.headline)
                .lineLimit(2)
        }

        if let top = viewModel.topRiskAssessment {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.mapSummaryMostUrgent)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(top.locationName)
                        .font(.subheadline.bold())
                    Text(top.riskLevel)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(top.riskColor.opacity(0.2))
                        .foregroundStyle(top.riskColor)
                        .clipShape(Capsule())
                }

                if let hoursLine = arrivalHoursLine(for: top) {
                    Text(hoursLine)
                        .font(.subheadline)
                        .foregroundStyle(top.riskColor)
                }

                Text(actionAdvice(for: top.riskLevel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(L10n.mapSummaryNoLocations)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.85))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private func arrivalHoursLine(for risk: RiskAssessment) -> String? {
        if risk.riskLevel == "SEVERE", let hours = risk.arrival64kt?.hours, hours >= 0 {
            return L10n.mapSummaryHoursToStorm(Int(hours.rounded()))
        }
        if let hours = risk.arrival34kt?.hours, hours >= 0 {
            return L10n.mapSummaryHoursToGale(Int(hours.rounded()))
        }
        return nil
    }

    private func actionAdvice(for level: String) -> String {
        switch level {
        case "SEVERE": return L10n.mapSummaryActionSevere
        case "HIGH": return L10n.mapSummaryActionHigh
        case "MEDIUM": return L10n.mapSummaryActionMedium
        default: return L10n.mapSummaryActionLow
        }
    }
}

// Risk color / helpers are defined in LocationsView.swift (shared)

extension SavedLocation {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// 保存場所のマーカー描画。Map のインライン式が型推論タイムアウトするのを避けるため、
/// ViewBuilder の負荷を View 単位で分離している。
struct SavedLocationMarkerView: View {
    let risk: RiskAssessment
    let location: SavedLocation

    private var isHighPriority: Bool {
        location.notificationLevel == "HIGH" || location.notificationLevel == "SEVERE"
    }

    private var markerSize: CGFloat {
        isHighPriority ? 22 : 16
    }

    var body: some View {
        VStack(spacing: 2) {
            iconCircle
            arrivalBadge
            notificationLevelBadge
        }
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(risk.riskColor)
                .frame(width: markerSize, height: markerSize)
                .overlay(
                    Circle()
                        .stroke(isHighPriority ? Color.white : Color.white.opacity(0.7),
                                lineWidth: isHighPriority ? 3 : 2)
                )

            if isHighPriority {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var arrivalBadge: some View {
        if let hours = risk.hoursToStrongWind {
            Text(L10n.hoursSuffix(Int(hours)))
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .background(risk.riskColor.opacity(0.9))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var notificationLevelBadge: some View {
        if let level = location.notificationLevel {
            Text(level)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
        }
    }
}
