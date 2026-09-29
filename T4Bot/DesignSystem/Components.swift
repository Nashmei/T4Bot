import SwiftUI

enum T4Palette {
    static let accent = Color(red: 0.82, green: 0.58, blue: 0.18)
    static let accent2 = Color(red: 0.95, green: 0.76, blue: 0.36)
    static let bronze = Color(red: 0.48, green: 0.31, blue: 0.08)
    static let positive = Color(red: 0.18, green: 0.72, blue: 0.46)
    static let negative = Color(red: 0.94, green: 0.30, blue: 0.34)
    static let warning = Color(red: 0.95, green: 0.66, blue: 0.18)
}

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark
                ? Color(red: 0.045, green: 0.043, blue: 0.039)
                : Color(red: 0.975, green: 0.973, blue: 0.966))
            LinearGradient(
                colors: [
                    T4Palette.accent.opacity(scheme == .dark ? 0.08 : 0.05),
                    .clear,
                    T4Palette.accent2.opacity(scheme == .dark ? 0.035 : 0.025)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

struct SurfaceCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                scheme == .dark
                    ? Color.white.opacity(0.07)
                    : Color.white.opacity(0.96),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(scheme == .dark ? 0.06 : 0.04), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.18 : 0.045), radius: 18, y: 8)
    }
}

struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.58, green: 0.39, blue: 0.08),
                        T4Palette.accent,
                        Color(red: 0.86, green: 0.66, blue: 0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .foregroundStyle(.white)
            .shadow(color: T4Palette.accent.opacity(0.14), radius: 18, y: 9)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = T4Palette.accent

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: systemImage)
                    .font(.subheadline.bold())
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.10), in: Circle())
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Statuses are deliberately plain text, not glass/button-shaped controls.
struct StatusPill: View {
    let title: String
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isPositive ? T4Palette.positive : Color.secondary.opacity(0.65))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
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
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoadingOverlay: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                ZStack {
                    Color.black.opacity(0.06).ignoresSafeArea()
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
    func loadingOverlay(_ active: Bool) -> some View { modifier(LoadingOverlay(active: active)) }
    func t4ListBackground() -> some View { scrollContentBackground(.hidden).background(AppBackdrop()) }
}

struct BrandMark: View {
    var size: CGFloat = 72
    var running: Bool = true

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.20), lineWidth: size * 0.085)
            Circle()
                .trim(from: 0.03, to: running ? 0.82 : 0.27)
                .stroke(
                    T4Palette.accent2,
                    style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round)
                )
                .rotationEffect(.degrees(-88))
            Image(systemName: running ? "bolt.fill" : "pause.fill")
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct AccountRingMetric: View {
    let title: String
    let value: String
    let progress: Double
    let icon: String
    let detail: String
    var tint: Color = T4Palette.accent2

    var body: some View {
        SurfaceCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(tint.opacity(0.14), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: max(0.03, min(progress, 1)))
                        .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: icon)
                        .font(.caption.bold())
                        .foregroundStyle(tint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
