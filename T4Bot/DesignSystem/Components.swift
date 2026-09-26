import SwiftUI

enum T4Palette {
    static let accent = Color(red: 0.17, green: 0.42, blue: 0.92)
    static let accent2 = Color(red: 0.79, green: 0.96, blue: 0.39)
    static let cyan = Color(red: 0.38, green: 0.82, blue: 0.95)
    static let positive = Color(red: 0.18, green: 0.72, blue: 0.43)
    static let negative = Color(red: 0.93, green: 0.31, blue: 0.35)
}

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        (scheme == .dark ? Color(red: 0.035, green: 0.045, blue: 0.07) : Color(red: 0.955, green: 0.965, blue: 0.985))
            .ignoresSafeArea()
    }
}

struct SurfaceCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(scheme == .dark ? Color.white.opacity(0.065) : Color.white,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.055), lineWidth: 0.7) }
            .shadow(color: .black.opacity(scheme == .dark ? 0.16 : 0.055), radius: 18, y: 8)
    }
}

struct HeroCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [T4Palette.accent, Color(red: 0.28, green: 0.63, blue: 0.94), T4Palette.cyan],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: T4Palette.accent.opacity(0.22), radius: 22, y: 12)
    }
}

struct MetricCard: View {
    let title: String; let value: String; let systemImage: String
    var tint: Color = T4Palette.accent
    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: systemImage).font(.subheadline.bold()).foregroundStyle(tint)
                    .frame(width: 34, height: 34).background(tint.opacity(0.12), in: Circle())
                Text(value).font(.title3.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.62)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct StatusPill: View {
    let title: String; let isPositive: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(isPositive ? T4Palette.positive : .secondary).frame(width: 7, height: 7)
            Text(title).font(.caption.bold())
        }.padding(.horizontal, 10).padding(.vertical, 7).background(.thinMaterial, in: Capsule())
    }
}

struct SectionHeader: View {
    let title: String; var subtitle: String?
    init(_ title: String, subtitle: String? = nil) { self.title = title; self.subtitle = subtitle }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoadingOverlay: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.overlay {
            if active {
                ZStack { Color.black.opacity(0.08).ignoresSafeArea(); ProgressView().controlSize(.large).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) }
            }
        }
    }
}
extension View {
    func loadingOverlay(_ active: Bool) -> some View { modifier(LoadingOverlay(active: active)) }
    func t4ListBackground() -> some View { scrollContentBackground(.hidden).background(AppBackdrop()) }
}
