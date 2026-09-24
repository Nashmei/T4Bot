import SwiftUI

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StatusPill: View {
    let title: String
    let isPositive: Bool

    var body: some View {
        Label(title, systemImage: isPositive ? "checkmark.circle.fill" : "circle")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isPositive ? .green : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
    }
}

struct LoadingOverlay: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    ZStack {
                        Color.black.opacity(0.08).ignoresSafeArea()
                        ProgressView()
                            .controlSize(.large)
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
    }
}

extension View {
    func loadingOverlay(_ active: Bool) -> some View {
        modifier(LoadingOverlay(active: active))
    }
}
