import SwiftUI

struct DataSourceStatusBanner: View {
    @ObservedObject var viewModel: TyphoonViewModel

    /// App Store スクショ撮影モードでは全状態で非表示
    private var isScreenshotMode: Bool {
        UserDefaults.standard.bool(forKey: "screenshotMode")
    }

    var body: some View {
        if isScreenshotMode {
            EmptyView()
        } else {
            bannerContent
        }
    }

    @ViewBuilder
    private var bannerContent: some View {
        switch viewModel.dataSourceStatus {
        case .real:
            EmptyView()

        case .demo:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                Text(L10n.bannerDemoInUse)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.retry) {
                    Task { await viewModel.loadData() }
                }
                .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.12))
            .cornerRadius(10)
            
        case .demoDueToError(let message):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L10n.bannerRealDataFailure)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.loadData() }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)
        }
    }
}