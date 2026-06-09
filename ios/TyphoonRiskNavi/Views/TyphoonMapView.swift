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
                    .overlay(alignment: .bottomLeading) {
                        // App Store スクショ撮影モードでは下部ピル全体を非表示
                        if isScreenshotMode {
                            EmptyView()
                        } else {
                        // 地図ではコンパクトなステータスピル + エラー時は専用バナー
                        VStack(alignment: .leading, spacing: 8) {
                            // コンパクトステータス
                            HStack {
                                switch viewModel.dataSourceStatus {
                                case .real:
                                    Text(L10n.realData)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.green.opacity(0.85))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                case .demo:
                                    Text(L10n.demoData)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.gray.opacity(0.7))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                case .demoDueToError:
                                    Text(L10n.demoDataError)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.orange.opacity(0.9))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                
                                if let last = viewModel.lastRealDataDescription {
                                    Text(last)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // エラー詳細 + リトライ
                            if case .demoDueToError(let message) = viewModel.dataSourceStatus {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
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
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        } // else
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
