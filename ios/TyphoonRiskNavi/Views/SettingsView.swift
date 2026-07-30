import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: TyphoonViewModel
    @AppStorage(NotificationPreferences.strongWindKey) private var notifyStrongWind = false
    @AppStorage(NotificationPreferences.pathUpdateKey) private var notifyPathUpdate = false
    @State private var notificationDeniedAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(L10n.settingsDataSourceSection) {
                    HStack {
                        Text(L10n.settingsCurrentlyUsing)
                        Spacer()
                        switch viewModel.dataSourceStatus {
                        case .real:
                            Text(L10n.realData)
                                .foregroundStyle(.green)
                                .bold()
                        case .demo:
                            Text(L10n.settingsDemoData)
                                .foregroundStyle(.orange)
                                .bold()
                        case .noTyphoon:
                            Text(L10n.bannerNoTyphoon)
                                .foregroundStyle(.blue)
                                .bold()
                        case .demoDueToError:
                            Text(L10n.settingsDemoDataError)
                                .foregroundStyle(.orange)
                                .bold()
                        }
                    }

                    switch viewModel.dataSourceStatus {
                    case .real:
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.settingsRealDataDesc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let last = viewModel.lastRealDataDescription {
                                Text(last)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    case .noTyphoon:
                        Text(L10n.settingsNoTyphoonDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .demo:
                        Text(L10n.settingsUsingDemoBecauseNoReal)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .demoDueToError(let message):
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.settingsUsingDemoBecauseFetchFailed)
                                .font(.caption)
                            Text(L10n.settingsErrorPrefix(message))
                                .font(.caption2)
                                .foregroundStyle(.red)
                            if let last = viewModel.lastRealDataDescription {
                                Text(last)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                Task { await viewModel.loadData() }
                            } label: {
                                Label(L10n.retry, systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .controlSize(.small)
                        }
                    }
                }

                Section(L10n.settingsNotificationsSection) {
                    Toggle(L10n.settingsNotificationStrongWind, isOn: $notifyStrongWind)
                        .onChange(of: notifyStrongWind) { _, enabled in
                            Task { await handleNotificationToggle(enabled: enabled, which: .strongWind) }
                        }
                    Toggle(L10n.settingsNotificationPathUpdate, isOn: $notifyPathUpdate)
                        .onChange(of: notifyPathUpdate) { _, enabled in
                            Task { await handleNotificationToggle(enabled: enabled, which: .pathUpdate) }
                        }

                    Text(L10n.settingsNotificationNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(L10n.settingsReloadData) {
                        Task { await viewModel.loadData() }
                    }
                }

                Section("アプリ情報") {
                    HStack {
                        Text(L10n.settingsVersion)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(L10n.settingsBuild)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明")
                            .foregroundStyle(.secondary)
                    }

                    Text(L10n.settingsAppDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("精度モデル") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.settingsPrecisionModelDesc)
                            .font(.caption)

                        Text(L10n.settingsPrecisionModelDetail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle(L10n.tabSettings)
            .task {
                if !viewModel.hasData {
                    await viewModel.loadData()
                }
            }
            .alert(L10n.notificationPermissionTitle, isPresented: $notificationDeniedAlert) {
                Button(L10n.locationsOpenSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(L10n.locationsCancel, role: .cancel) {}
            } message: {
                Text(L10n.notificationPermissionMessage)
            }
        }
    }

    private enum NotificationToggleKind {
        case strongWind
        case pathUpdate
    }

    private func handleNotificationToggle(enabled: Bool, which: NotificationToggleKind) async {
        guard enabled else {
            await LocalNotificationService.shared.refreshNotifications(
                risks: viewModel.displayRisks,
                typhoon: viewModel.state?.typhoon,
                dataSourceIsReal: viewModel.isUsingRealData
            )
            return
        }

        let allowed = await LocalNotificationService.shared.requestAuthorizationIfNeeded()
        if !allowed {
            switch which {
            case .strongWind: notifyStrongWind = false
            case .pathUpdate: notifyPathUpdate = false
            }
            notificationDeniedAlert = true
            return
        }

        await LocalNotificationService.shared.refreshNotifications(
            risks: viewModel.displayRisks,
            typhoon: viewModel.state?.typhoon,
            dataSourceIsReal: viewModel.isUsingRealData
        )
    }
}
