import SwiftUI

struct PositionsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if let positions = appModel.snapshot?.positions, !positions.isEmpty {
                    List(positions) { position in
                        PositionRow(position: position)
                    }
                } else {
                    ContentUnavailableView(
                        "لا توجد مراكز مفتوحة",
                        systemImage: "tray",
                        description: Text("هذه الشاشة للعرض فقط؛ تنفيذ وإدارة الصفقات يتمان داخل Mtbot.")
                    )
                }
            }
            .navigationTitle("الصفقات")
            .refreshable {
                await appModel.refresh()
            }
        }
    }
}

private struct PositionRow: View {
    let position: PositionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(position.symbol)
                    .font(.headline)
                Text(position.side)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(position.side == "BUY" ? .green : .red)
                Spacer()
                Text(position.profit, format: .currency(code: "USD").sign(strategy: .always()))
                    .font(.headline)
                    .monospacedDigit()
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                row("Ticket", "\(position.ticket)")
                row("Volume", position.volume.formatted(.number.precision(.fractionLength(2))))
                row("Entry", position.priceOpen.formatted())
                row("Current", position.priceCurrent.formatted())
                row("SL", position.sl.formatted())
                row("TP", position.tp.formatted())
            }
            .font(.caption)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .textSelection(.enabled)
        }
    }
}
