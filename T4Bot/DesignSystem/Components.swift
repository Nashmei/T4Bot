import SwiftUI

enum T4Palette {
    static let accent = Color(red: 0.33, green: 0.47, blue: 0.98)
    static let accentSoft = Color(red: 0.47, green: 0.58, blue: 1.00)
    static let positive = Color(red: 0.16, green: 0.72, blue: 0.46)
    static let negative = Color(red: 0.94, green: 0.29, blue: 0.34)
    static let warning = Color(red: 0.96, green: 0.65, blue: 0.16)
    static let cyan = Color(red: 0.20, green: 0.74, blue: 0.88)
}

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark
             ? Color(red: 0.035, green: 0.043, blue: 0.060)
             : Color(red: 0.965, green: 0.973, blue: 0.988))
            LinearGradient(
                colors: [
                    T4Palette.accent.opacity(scheme == .dark ? 0.12 : 0.08),
                    .clear,
                    T4Palette.cyan.opacity(scheme == .dark ? 0.05 : 0.03)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

struct Panel<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                scheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.88),
                in: RoundedRectangle(cornerRadius: T4Style.radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: T4Style.radius, style: .continuous)
                    .stroke(Color.primary.opacity(scheme == .dark ? 0.07 : 0.055), lineWidth: 0.7)
            )
    }
}

struct CommandBar<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct StatusDot: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    var tint: Color = T4Palette.accent

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Spacer()
                }
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
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
                    Color.black.opacity(0.08).ignoresSafeArea()
                    ProgressView().controlSize(.large)
                        .padding(22)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
    var size: CGFloat = 54
    var running: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [T4Palette.accent, T4Palette.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: running ? "waveform.path.ecg" : "pause.fill")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
