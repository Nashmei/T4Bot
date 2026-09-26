import SwiftUI

enum T4Palette {
    static let accent = Color(red: 0.78, green: 0.55, blue: 0.12)
    static let accent2 = Color(red: 0.96, green: 0.78, blue: 0.31)
    static let cyan = Color(red: 0.72, green: 0.62, blue: 0.35)
    static let positive = Color(red: 0.18, green: 0.72, blue: 0.43)
    static let negative = Color(red: 0.93, green: 0.31, blue: 0.35)
}

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        (scheme == .dark ? Color(red: 0.075, green: 0.068, blue: 0.052) : Color(red: 0.975, green: 0.965, blue: 0.925))
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
            .background(LinearGradient(colors: [Color(red:0.68,green:0.45,blue:0.08), T4Palette.accent, Color(red:0.91,green:0.70,blue:0.25)],
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

struct BrandMark: View {
    var size: CGFloat = 72
    var running: Bool = true
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: size * 0.085)
            Circle().trim(from: 0.03, to: running ? 0.82 : 0.27)
                .stroke(T4Palette.accent2, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .rotationEffect(.degrees(-88))
            Image(systemName: running ? "bolt.fill" : "pause.fill")
                .font(.system(size: size * 0.34, weight: .black)).foregroundStyle(.white)
        }.frame(width:size,height:size)
    }
}

struct AccountRingMetric: View {
    let title:String; let value:String; let progress:Double; let icon:String; let detail:String
    var tint:Color = T4Palette.accent2
    var body: some View {
        SurfaceCard {
            HStack(spacing:12) {
                ZStack {
                    Circle().stroke(tint.opacity(0.16),lineWidth:7)
                    Circle().trim(from:0,to:max(0.03,min(progress,1))).stroke(tint,style:StrokeStyle(lineWidth:7,lineCap:.round)).rotationEffect(.degrees(-90))
                    Image(systemName:icon).font(.caption.bold()).foregroundStyle(tint)
                }.frame(width:48,height:48)
                VStack(alignment:.leading,spacing:3) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.62)
                    Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}
