import SwiftUI
import CoreLocation

struct LocationsView: View {
    @EnvironmentObject private var viewModel: TyphoonViewModel
    @State private var showingAddSheet = false
    @State private var showingLocationAlert = false
    @State private var showingEditSheet = false
    @State private var selectedLocation: SavedLocation? = nil
    @State private var locationManager = CLLocationManager()
    
    private var locations: [SavedLocation] {
        let all = viewModel.state?.savedLocations ?? []
        let priority: [String: Int] = ["SEVERE": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1]
        return all.sorted { lhs, rhs in
            let p1 = priority[lhs.notificationLevel ?? ""] ?? 0
            let p2 = priority[rhs.notificationLevel ?? ""] ?? 0
            if p1 != p2 { return p1 > p2 }
            return lhs.name < rhs.name
        }
    }
    
    private var risksByLocationId: [String: RiskAssessment] {
        // Prefer client-computed risks when using real data
        if case .real = viewModel.dataSourceStatus, !viewModel.computedUserRisks.isEmpty {
            return Dictionary(uniqueKeysWithValues: viewModel.computedUserRisks.map { ($0.locationId, $0) })
        }
        
        // Fallback to whatever the backend provided
        guard let risks = viewModel.state?.risks else { return [:] }
        return Dictionary(uniqueKeysWithValues: risks.map { ($0.locationId, $0) })
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && locations.isEmpty {
                    ProgressView(viewModel.loadingContext ?? "読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            Label("再試行", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                    }
                } else if locations.isEmpty {
                    ContentUnavailableView(
                        L10n.locationsEmptyTitle,
                        systemImage: "mappin.slash",
                        description: Text(L10n.locationsEmptyDescription)
                    )
                } else {
                    List {
                        // 実データ / エラー時のステータスバナー
                        DataSourceStatusBanner(viewModel: viewModel)
                        
                        ForEach(locations) { location in
                            LocationRiskRow(
                                location: location,
                                risk: risksByLocationId[location.id]
                            )
                            .onLongPressGesture {
                                selectedLocation = location
                                showingEditSheet = true
                            }
                        }
                        .onDelete(perform: deleteLocations)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L10n.tabLocations)
            .toolbar {
                // 中央にデータソースステータス
                ToolbarItem(placement: .principal) {
                    if case .demoDueToError = viewModel.dataSourceStatus {
                        Text(L10n.locationsRealDataFailure)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if viewModel.isUsingRealData {
                        HStack(spacing: 6) {
                            Text(L10n.realData)
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
                
                // 右上メニュー
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Label(L10n.locationsAddManual, systemImage: "pencil")
                        }
                        
                        Button {
                            requestCurrentLocationAndSave()
                        } label: {
                            Label(L10n.locationsAddCurrent, systemImage: "location.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                // 左上リロード
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await viewModel.loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddLocationViewManual { name, lat, lon, level in
                    addLocation(name: name, lat: lat, lon: lon, notificationLevel: level)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let location = selectedLocation {
                    EditLocationView(location: location) { name, lat, lon, level in
                        updateLocation(location: location, name: name, lat: lat, lon: lon, notificationLevel: level)
                    }
                }
            }
            .alert(L10n.alertLocationPermissionTitle, isPresented: $showingLocationAlert) {
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
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
    
    private func addLocation(name: String, lat: Double, lon: Double, notificationLevel: String? = nil) {
        // ローカルストアに追加。@Published の locations 経由で ViewModel がリスクを再計算する。
        _ = viewModel.locationStore.add(name: name, lat: lat, lon: lon, notificationLevel: notificationLevel)
    }

    private func deleteLocations(at offsets: IndexSet) {
        let idsToDelete = offsets.map { locations[$0].id }
        viewModel.locationStore.deleteAll(ids: idsToDelete)
    }

    private func updateLocation(location: SavedLocation, name: String?, lat: Double?, lon: Double?, notificationLevel: String?) {
        _ = viewModel.locationStore.update(
            id: location.id,
            name: name,
            lat: lat,
            lon: lon,
            notificationLevel: notificationLevel
        )
    }
    
    // 現在地を取得してすぐに保存するフロー
    private func requestCurrentLocationAndSave() {
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // 少し待ってから再試行（実アプリでは delegate を使うべき）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.trySaveCurrentLocation()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            trySaveCurrentLocation()
        case .denied, .restricted:
            showingLocationAlert = true
        @unknown default:
            showingLocationAlert = true
        }
    }
    
    private func trySaveCurrentLocation() {
        guard let loc = locationManager.location else {
            // 位置が取れなかった場合
            showingLocationAlert = true
            return
        }
        
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        let name = "現在地 (\(Date().formatted(date: .omitted, time: .shortened)))"
        addLocation(name: name, lat: lat, lon: lon, notificationLevel: "MEDIUM")
    }
}

// MARK: - Manual Add Sheet
struct AddLocationViewManual: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var lat: Double = 26.21
    @State private var lon: Double = 127.68
    @State private var notificationLevel: String = "MEDIUM"
    
    var onAdd: (String, Double, Double, String?) -> Void
    
    let levels = ["LOW", "MEDIUM", "HIGH", "SEVERE"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("手動入力") {
                    TextField("場所の名前（例: 自宅、会社）", text: $name)
                    TextField("緯度", value: $lat, format: .number)
                    TextField("経度", value: $lon, format: .number)
                }
                
                Section("通知レベル") {
                    Picker("この場所の通知優先度", selection: $notificationLevel) {
                        ForEach(levels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.locationsAddTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let finalName = name.isEmpty ? "新しい場所" : name
                        onAdd(finalName, lat, lon, notificationLevel)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Location Sheet
struct EditLocationView: View {
    @Environment(\.dismiss) private var dismiss
    let location: SavedLocation
    var onSave: (String?, Double?, Double?, String?) -> Void
    
    @State private var name: String
    @State private var lat: Double
    @State private var lon: Double
    @State private var notificationLevel: String
    
    let levels = ["LOW", "MEDIUM", "HIGH", "SEVERE"]
    
    init(location: SavedLocation, onSave: @escaping (String?, Double?, Double?, String?) -> Void) {
        self.location = location
        self.onSave = onSave
        _name = State(initialValue: location.name)
        _lat = State(initialValue: location.lat)
        _lon = State(initialValue: location.lon)
        _notificationLevel = State(initialValue: location.notificationLevel ?? "MEDIUM")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("場所の名前", text: $name)
                    TextField("緯度", value: $lat, format: .number)
                    TextField("経度", value: $lon, format: .number)
                }
                
                Section("通知レベル") {
                    Picker("通知優先度", selection: $notificationLevel) {
                        ForEach(levels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.locationsEditTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let newName = name != location.name ? name : nil
                        let newLat = lat != location.lat ? lat : nil
                        let newLon = lon != location.lon ? lon : nil
                        let newLevel = notificationLevel != (location.notificationLevel ?? "MEDIUM") ? notificationLevel : nil
                        
                        onSave(newName, newLat, newLon, newLevel)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Rich Row with Risk Info
struct LocationRiskRow: View {
    @EnvironmentObject private var viewModel: TyphoonViewModel
    let location: SavedLocation
    let risk: RiskAssessment?

    /// ローカルストア経由で通知レベルを即時変更
    private func quickSetLevel(_ newLevel: String) {
        _ = viewModel.locationStore.setNotificationLevel(id: location.id, level: newLevel)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Risk indicator
            Circle()
                .fill(risk?.riskColor ?? .gray)
                .frame(width: 14, height: 14)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                
                if let risk = risk {
                    HStack(spacing: 6) {
                        Text(risk.riskLevel)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(risk.riskColor.opacity(0.15))
                            .foregroundStyle(risk.riskColor)
                            .clipShape(Capsule())
                        
                        if let hours = risk.hoursToStrongWind {
                            Text(L10n.locationsHoursStrongWind(Int(hours)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // ユーザーの通知レベルに対する到達時間を表示（価値を高める）
                    if let level = location.notificationLevel,
                       let relevantHours = hoursToNotificationLevel(level, risk: risk) {
                        Text(L10n.locationsHoursToLevel(level, Int(relevantHours)))
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    
                    Text(L10n.locationsCurrentDistance(risk.currentDistanceKm))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.locationsNoRiskInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(String(format: "%.4f, %.4f", location.lat, location.lon))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                
                if let level = location.notificationLevel {
                    Menu {
                        ForEach(["LOW", "MEDIUM", "HIGH", "SEVERE"], id: \.self) { newLevel in
                            Button(newLevel) {
                                quickSetLevel(newLevel)
                            }
                        }
                    } label: {
                        Text(level)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    .menuStyle(.button)
                } else {
                    // 未設定の場合もタップで設定可能
                    Menu {
                        ForEach(["LOW", "MEDIUM", "HIGH", "SEVERE"], id: \.self) { newLevel in
                            Button(newLevel) {
                                quickSetLevel(newLevel)
                            }
                        }
                    } label: {
                        Text(L10n.locationsNotSet)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                    .menuStyle(.button)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

extension RiskAssessment {
    var riskColor: Color {
        switch riskLevel {
        case "SEVERE": return .red
        case "HIGH": return .orange
        case "MEDIUM": return .yellow
        default: return .green
        }
    }
    
    var hoursToStrongWind: Double? {
        // 34kt (強風域) 到達までの時間
        return arrival34kt?.hours
    }
}

// ユーザーの通知レベルに対応する到達時間を返すヘルパー
func hoursToNotificationLevel(_ level: String, risk: RiskAssessment) -> Double? {
    switch level {
    case "SEVERE":
        return risk.arrival64kt?.hours
    case "HIGH":
        return risk.arrival50kt?.hours ?? risk.arrival34kt?.hours
    case "MEDIUM", "LOW":
        return risk.arrival34kt?.hours
    default:
        return risk.hoursToStrongWind
    }
}


