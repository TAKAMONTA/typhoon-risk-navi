import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: TyphoonViewModel
    
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
                    Toggle(L10n.settingsNotificationStrongWind, isOn: .constant(false))
                        .disabled(true)
                    Toggle(L10n.settingsNotificationPathUpdate, isOn: .constant(false))
                        .disabled(true)
                    
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
        }
    }
}
