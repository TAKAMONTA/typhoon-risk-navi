import SwiftUI
import MapKit

struct TyphoonMapView: View {
    @EnvironmentObject private var viewModel: TyphoonViewModel
    @StateObject private var locationHelper = LocationManagerHelper()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingLocationDeniedAlert = false

    /// すでにカメラを合わせた対象。タブを行き来しただけで手動操作を巻き戻さないために持つ。
    @State private var appliedFocusKey: String?

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
                    Map(position: $cameraPosition) {
                        // 現在地（許可済みのときだけ青い点を出す）
                        if locationHelper.isAuthorized {
                            UserAnnotation()
                        }

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
                        
                        // 台風の現在位置（一番目立つ）。台風がないときは描かない。
                        if let typhoon = state.typhoon {
                            // タイトルは空にして、下の吹き出しと二重表示になるのを防ぐ。
                            Annotation("", coordinate: typhoon.currentCenter.clLocation) {
                                VStack(spacing: 4) {
                                    Image(systemName: "hurricane.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.title)
                                        .shadow(radius: 2)

                                    Text(typhoon.nameJa ?? typhoon.name)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.red.opacity(0.9))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(typhoon.nameJa ?? typhoon.name)
                            }
                        }
                        
                        // 保存場所。台風がなくてリスクが空でもピンは必ず出す。
                        let risksById = Dictionary(
                            viewModel.displayRisks.map { ($0.locationId, $0) },
                            uniquingKeysWith: { first, _ in first }
                        )

                        ForEach(state.savedLocations) { loc in
                            Annotation(loc.name, coordinate: loc.coordinate) {
                                SavedLocationMarkerView(risk: risksById[loc.id], location: loc)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .onAppear { applyFocusIfNeeded(animated: false) }
                    .onChange(of: viewModel.mapFocusKey) { _, _ in
                        applyFocusIfNeeded(animated: true)
                    }
                    .overlay(alignment: .topLeading) {
                        mapFocusControls
                    }
                    .overlay(alignment: .topTrailing) {
                        // 凡例（風速半径の説明）。台風がないときは円も出ないので凡例も隠す。
                        if state.typhoon != nil {
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
                    }
                    .overlay(alignment: .bottom) {
                        if !isScreenshotMode {
                            RiskSummaryCard(viewModel: viewModel)
                                // iPad で横幅いっぱいに伸びて余白だらけになるのを防ぐ。
                                .frame(maxWidth: 560)
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
            .alert(L10n.alertLocationPermissionTitle, isPresented: $showingLocationDeniedAlert) {
                Button(L10n.locationsOpenSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(L10n.locationsCancel, role: .cancel) {}
            } message: {
                Text(L10n.locationsPermissionRequired)
            }
            .task {
                if !viewModel.hasData {
                    await viewModel.loadData()
                }
            }
        }
    }

    /// 台風や拠点が変わったときだけカメラを合わせ直す。
    /// 同じ対象のまま再表示・再読み込みしただけなら、ユーザーの操作位置を維持する。
    private func applyFocusIfNeeded(animated: Bool) {
        let key = viewModel.mapFocusKey
        guard appliedFocusKey != key else { return }
        appliedFocusKey = key

        let region = viewModel.mapRegion
        if animated {
            withAnimation { cameraPosition = .region(region) }
        } else {
            cameraPosition = .region(region)
        }
    }

    /// 地図の見る場所を切り替えるボタン群。
    /// 台風が沖縄から遠いときでも、ワンタップで台風／沖縄を行き来できるようにする。
    @ViewBuilder
    private var mapFocusControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            focusButton(title: L10n.mapFocusHome, systemImage: "house") {
                cameraPosition = .region(viewModel.homeRegion)
            }

            if viewModel.state?.typhoon != nil {
                focusButton(title: L10n.mapFocusTyphoon, systemImage: "hurricane") {
                    cameraPosition = .region(viewModel.typhoonRegion)
                }
            }

            focusButton(title: L10n.mapFocusCurrentLocation, systemImage: "location") {
                if locationHelper.isAuthorized {
                    cameraPosition = .userLocation(fallback: .region(viewModel.homeRegion))
                } else if locationHelper.isDenied {
                    // 無反応にせず、設定アプリで許可し直せることを伝える。
                    showingLocationDeniedAlert = true
                } else {
                    locationHelper.requestAuthorizationIfNeeded()
                }
            }
        }
        .padding(8)
    }

    private func focusButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Risk Summary Card

/// 起動直後に「台風を知る → 対策する → 自治体で確認」を一目で見られるカード。
struct RiskSummaryCard: View {
    @ObservedObject var viewModel: TyphoonViewModel

    /// 既定は折りたたみ。カードが地図を覆い隠さないようにする。
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusBadgeRow

            switch viewModel.dataSourceStatus {
            case .noTyphoon:
                noTyphoonContent
            case .demoDueToError(let message):
                errorContent(message: message)
            default:
                personalRiskSection
            }

            expandToggle

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        actionsSection

                        Divider()
                        officialWarningSection

                        Divider()
                        municipalitySection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // 背面でタップを吸収し、カードの余白を押したときに背後の地図
            // （Apple の法的情報リンクや POI）が反応するのを防ぐ。
            // 前面にあるボタン・リンクのほうが先に当たるので、そちらは通常どおり動く。
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .onTapGesture { }
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            Label(
                isExpanded ? L10n.mapSummaryCollapse : L10n.mapSummaryExpand,
                systemImage: isExpanded ? "chevron.down" : "chevron.up"
            )
            .font(.caption.bold())
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
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
    private var personalRiskSection: some View {
        Text(L10n.mapSummaryYourRisk)
            .font(.caption.bold())
            .foregroundStyle(.secondary)

        if let typhoon = viewModel.state?.typhoon {
            Text(typhoon.nameJa ?? typhoon.name)
                .font(.headline)
                .lineLimit(1)

            typhoonPositionLine
        }

        if let top = viewModel.topRiskAssessment {
            HStack(alignment: .center, spacing: 12) {
                riskLevelBadge(level: top.riskLevel)

                VStack(alignment: .leading, spacing: 4) {
                    Text(top.locationName)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    if let hoursLine = arrivalHoursLine(for: top) {
                        Text(hoursLine)
                            .font(.subheadline)
                            .foregroundStyle(top.riskColor)
                    }
                }
            }
        } else if let location = viewModel.representativeLocation {
            Text(location.name)
                .font(.subheadline.bold())
            Text(L10n.mapSummaryNoRiskYet)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(L10n.mapSummaryNoLocations)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// 台風が今どこにいるか（基準点からの方角と距離）。
    /// 遠方の台風は地図の初期表示に入らないので、文章で必ず伝える。
    @ViewBuilder
    private var typhoonPositionLine: some View {
        if let distance = viewModel.typhoonDistanceKm {
            let km = Int(distance.rounded())
            if let direction = viewModel.typhoonDirectionFromAnchor {
                Text(L10n.mapSummaryTyphoonPosition(viewModel.mapAnchorName, direction, km))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.isTyphoonFarAway {
                Text(L10n.mapSummaryTyphoonFarHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        let isQuiet = {
            if case .noTyphoon = viewModel.dataSourceStatus { return true }
            return false
        }()

        Text(isQuiet ? L10n.mapSummaryActionsQuietTitle : L10n.mapSummaryActionsTitle)
            .font(.caption.bold())
            .foregroundStyle(.secondary)

        let steps: [TyphoonActionGuide.Step] = {
            if isQuiet {
                return TyphoonActionGuide.quietPeriodSteps
            }
            if let level = viewModel.topRiskAssessment?.riskLevel {
                return TyphoonActionGuide.steps(forRiskLevel: level)
            }
            return TyphoonActionGuide.steps(forRiskLevel: "LOW")
        }()

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .trailing)
                    Text(step.text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var officialWarningSection: some View {
        Text(L10n.mapSummaryWarningTitle)
            .font(.caption.bold())
            .foregroundStyle(.secondary)

        if let warning = viewModel.primaryOfficialWarning {
            Text(warning.areaName)
                .font(.subheadline.bold())

            Text(warning.hasActiveWarning ? warning.headline : L10n.warningNoneHeadline)
                .font(.caption)
                .foregroundStyle(warning.hasActiveWarning ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !warning.warningNames.isEmpty {
                Text(warning.warningNames.joined(separator: "・"))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Text(L10n.mapSummaryWarningEvacuationHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: warning.detailURL) {
                Label(L10n.mapSummaryOpenWarningDetail, systemImage: "cloud.bolt")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Text(L10n.mapSummaryWarningUnavailable)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var municipalitySection: some View {
        Text(L10n.mapSummaryMunicipalityTitle)
            .font(.caption.bold())
            .foregroundStyle(.secondary)

        if let info = viewModel.nearestMunicipalityInfo {
            Text(info.municipality.name)
                .font(.subheadline.bold())
            Text(L10n.mapSummaryMunicipalityDistance(Int(info.distanceKm.rounded())))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(L10n.mapSummaryMunicipalityHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Link(destination: info.municipality.disasterInfoURL) {
                    Label(L10n.mapSummaryOpenDisaster, systemImage: "exclamationmark.shield")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Link(destination: info.municipality.evacuationInfoURL) {
                    Label(L10n.mapSummaryOpenEvacuation, systemImage: "figure.walk")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Link(destination: OkinawaMunicipalityCatalog.prefectureDisasterURL) {
                    Text(L10n.mapSummaryOpenPrefecture)
                        .font(.caption2)
                }
                Text("·")
                    .foregroundStyle(.tertiary)
                Link(destination: OkinawaMunicipalityCatalog.jmaTyphoonURL) {
                    Text(L10n.mapSummaryOpenJMA)
                        .font(.caption2)
                }
            }
            .foregroundStyle(.blue)
        } else {
            Text(L10n.mapSummaryMunicipalityNeedLocation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func riskLevelBadge(level: String) -> some View {
        let color = RiskAssessment.staticRiskColor(for: level)
        return Text(L10n.riskLevelLabel(level))
            .font(.caption.bold())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(minWidth: 72)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    /// 台風がないときは nil。ピン自体は常に描く。
    let risk: RiskAssessment?
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
                .fill(risk?.riskColor ?? .gray)
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
        if let risk, let hours = risk.hoursToStrongWind {
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
            Text(L10n.riskLevelLabel(level))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
        }
    }
}
