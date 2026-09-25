import SwiftUI

enum T4Palette {
    static let accent = Color(red: 0.12, green: 0.66, blue: 1.00)
    static let accent2 = Color(red: 0.25, green: 0.86, blue: 0.72)
    static let positive = Color.green
    static let negative = Color.red
}

struct AppBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                T4Palette.accent.opacity(0.07),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: T4Style.corner, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: T4Style.corner, style: .continuous)
                    .stroke(.primary.opacity(0.07), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.04), radius: 16, y: 8)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = T4Palette.accent

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.13))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                }

                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

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
        HStack(spacing: 6) {
            Circle()
                .fill(isPositive ? T4Palette.positive : .secondary)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    func t4ListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackdrop())
    }
}
