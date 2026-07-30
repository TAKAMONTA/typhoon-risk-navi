import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView {
                    OnboardingPage(
                        systemImage: "map.fill",
                        tint: .blue,
                        title: L10n.onboardingMapTitle,
                        message: L10n.onboardingMapMessage
                    )

                    OnboardingPage(
                        systemImage: "mappin.and.ellipse",
                        tint: .orange,
                        title: L10n.onboardingLocationsTitle,
                        message: L10n.onboardingLocationsMessage
                    )

                    OnboardingPage(
                        systemImage: "cloud.sun.rain.fill",
                        tint: .green,
                        title: L10n.onboardingDataTitle,
                        message: L10n.onboardingDataMessage
                    )

                    OnboardingPage(
                        systemImage: "location.circle.fill",
                        tint: .purple,
                        title: L10n.onboardingPrivacyTitle,
                        message: L10n.onboardingPrivacyMessage
                    )
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    Button {
                        onFinish()
                    } label: {
                        Text(L10n.onboardingStart)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(L10n.onboardingFootnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle(L10n.onboardingTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.onboardingSkip) {
                        onFinish()
                    }
                }
            }
        }
    }
}

private struct OnboardingPage: View {
    let systemImage: String
    let tint: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            Image(systemName: systemImage)
                .font(.system(size: 68, weight: .semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
            }

            Spacer(minLength: 48)
        }
        .padding()
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
