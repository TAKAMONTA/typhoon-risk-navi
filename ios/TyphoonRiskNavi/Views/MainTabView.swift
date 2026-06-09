import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = TyphoonViewModel()

    /// 起動時のタブ選択。`-selectedTab N` の launch argument で上書き可能。
    /// 通常起動では 0（地図）のまま。スクショ撮影や復元用途のために UserDefaults 同期。
    @AppStorage("selectedTab") private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TyphoonMapView()
                .tabItem {
                    Label(L10n.tabMap, systemImage: "map")
                }
                .environmentObject(viewModel)
                .tag(0)

            LocationsView()
                .tabItem {
                    Label(L10n.tabLocations, systemImage: "list.bullet")
                }
                .environmentObject(viewModel)
                .tag(1)

            SettingsView()
                .tabItem {
                    Label(L10n.tabSettings, systemImage: "gear")
                }
                .environmentObject(viewModel)
                .tag(2)
        }
    }
}
