import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = TyphoonViewModel()

    /// 起動時のタブ選択。`-selectedTab N` の launch argument で上書き可能。
    /// 通常起動では 0（地図）のまま。スクショ撮影や復元用途のために UserDefaults 同期。
    @AppStorage("selectedTab") private var selectedTab: Int = 0

    /// 初回起動時だけ、アプリの使い方を簡単に案内する。
    @AppStorage("hasSeenOnboardingV1") private var hasSeenOnboarding = false

    /// App Store スクリーンショット撮影時はオンボーディングを出さない。
    private var shouldShowOnboarding: Bool {
        !hasSeenOnboarding && !UserDefaults.standard.bool(forKey: "screenshotMode")
    }

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

            AreaMoodView()
                .tabItem {
                    Label(L10n.tabMood, systemImage: "person.3")
                }
                .tag(3)
        }
        .sheet(isPresented: Binding(
            get: { shouldShowOnboarding },
            set: { newValue in
                if !newValue {
                    hasSeenOnboarding = true
                }
            }
        )) {
            OnboardingView {
                hasSeenOnboarding = true
            }
            .interactiveDismissDisabled()
        }
    }
}
