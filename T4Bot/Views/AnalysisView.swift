import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var search = ""

    private var items: [AnalysisSnapshot] {
        let all = appModel.snapshot?.analysis ?? []
        guard !search.isEmpty else { return all }
        return all.filter { $0.symbol.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        Panel {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.symbol).font(.title3.bold().monospaced())
                                        Text(item.regime)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(regimeColor(item.regime))
                                    }
                                    Spacer()
                                    Text(item.state)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 12) {
                                    StatusDot(text: item.direction ?? item.side ?? "NONE",
                                              color: directionColor(item.direction ?? item.side))
                                    if let confidence = item.confidence {
                                        Text("ثقة \(confidence, specifier: "%.0f")%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let strength = item.strength {
                                        Text("قوة \(strength, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let strategy = item.strategy {
                                    Label(strategy, systemImage: "point.3.connected.trianglepath.dotted")
                                        .font(.subheadline.weight(.semibold))
                                }

                                if let reason = item.reasonCode ?? item.reason {
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("السوق")
        .searchable(text: $search, prompt: "ابحث عن رمز")
        .refreshable { await appModel.runAnalysis() }
    }

    private func regimeColor(_ regime: String) -> Color {
        switch regime.uppercased() {
        case "TREND": return T4Palette.positive
        case "VOLATILE": return T4Palette.warning
        case "RANGE": return T4Palette.cyan
        default: return .secondary
        }
    }

    private func directionColor(_ direction: String?) -> Color {
        switch direction?.uppercased() {
        case "UP", "BUY": return T4Palette.positive
        case "DOWN", "SELL": return T4Palette.negative
        default: return .secondary
        }
    }
}
