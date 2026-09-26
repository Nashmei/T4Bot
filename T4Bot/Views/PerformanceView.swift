import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject private var appModel:AppModel
    private var trades:[ClosedTrade]{appModel.tradeHistory.sorted{$0.closedAt>$1.closedAt}}
    private var wins:[ClosedTrade]{trades.filter{$0.pnl>0}}
    private var losses:[ClosedTrade]{trades.filter{$0.pnl<0}}
    private var net:Double{trades.reduce(0){$0+$1.pnl}}
    private var grossProfit:Double{wins.reduce(0){$0+$1.pnl}}
    private var grossLoss:Double{abs(losses.reduce(0){$0+$1.pnl})}
    private var winRate:Double{trades.isEmpty ? 0:Double(wins.count)/Double(trades.count)*100}
    private var currency:String{appModel.snapshot?.account?.currency ?? "USD"}

    var body:some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                ScrollView {
                    if trades.isEmpty {
                        ContentUnavailableView(
                            "لا توجد بيانات أداء بعد",
                            systemImage:"chart.bar.xaxis",
                            description:Text("يظهر الأداء التاريخي من الصفقات المغلقة للحساب المتصل.")
                        ).padding(.top,90)
                    } else {
                        VStack(spacing:14) {                            if let account=appModel.snapshot?.account {
                                HStack {
                                    VStack(alignment:.leading,spacing:3) {
                                        Text("أداء الحساب").font(.headline)
                                        Text("MT5 • \(account.login)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(trades.count) صفقة")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }.padding(.horizontal,4)
                            }

                            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                                PerformanceMetric(title:"الصافي",value:money(net),icon:"sum",tint:net>=0 ? T4Palette.positive:T4Palette.negative)
                                PerformanceMetric(title:"نسبة الفوز",value:String(format:"%.1f%%",winRate),icon:"percent",tint:T4Palette.accent)
                                PerformanceMetric(title:"Profit Factor",value:profitFactor,icon:"chart.line.uptrend.xyaxis",tint:T4Palette.accent2)
                                PerformanceMetric(title:"الصفقات",value:"\(trades.count)",icon:"list.number",tint:.secondary)
                            }

                            SurfaceCard {
                                VStack(spacing:12) {
                                    SectionHeader("النتائج")
                                    resultRow("رابحة","\(wins.count)",T4Palette.positive)
                                    Divider()
                                    resultRow("خاسرة","\(losses.count)",T4Palette.negative)
                                    Divider()
                                    resultRow("إجمالي الأرباح",money(grossProfit),T4Palette.positive)
                                    Divider()
                                    resultRow("إجمالي الخسائر",money(-grossLoss),T4Palette.negative)
                                }
                            }

                            if !strategyRows.isEmpty {
                                SurfaceCard {
                                    VStack(spacing:12) {
                                        SectionHeader("أداء الاستراتيجيات",subtitle:"مرتب حسب صافي النتيجة")
                                        ForEach(strategyRows.prefix(12)) { row in
                                            HStack {
                                                VStack(alignment:.leading,spacing:2) {
                                                    Text(row.name).font(.subheadline.weight(.semibold))
                                                    Text("\(row.count) صفقة • \(row.wins) ربح")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Text(money(row.net))
                                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                                    .foregroundStyle(row.net>=0 ? T4Palette.positive:T4Palette.negative)
                                            }
                                        }
                                    }
                                }
                            }
                        }.padding(16)
                    }
                }.scrollIndicators(.hidden)
            }
            .navigationTitle("الأداء")
            .navigationBarTitleDisplayMode(.inline)
            .task{await appModel.loadHistory(silent:true)}
        }
    }

    private var profitFactor:String {
        guard grossLoss>0 else{return grossProfit>0 ? "∞":"—"}
        return String(format:"%.2f",grossProfit/grossLoss)
    }

    private var strategyRows:[StrategyPerformance] {
        let groups=Dictionary(grouping:trades){$0.strategy.isEmpty ? "غير محدد":$0.strategy}
        return groups.map { key,rows in
            StrategyPerformance(
                name:key.replacingOccurrences(of:"_",with:" "),
                count:rows.count,
                net:rows.reduce(0){$0+$1.pnl},
                wins:rows.filter{$0.pnl>0}.count
            )
        }.sorted{$0.net>$1.net}
    }

    private func resultRow(_ title:String,_ value:String,_ tint:Color)->some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(tint)
        }
    }

    private func money(_ value:Double)->String {
        value.formatted(.currency(code:currency).sign(strategy:.always()))
    }
}

private struct PerformanceMetric:View {
    let title:String
    let value:String
    let icon:String
    let tint:Color

    var body:some View {
        SurfaceCard {
            VStack(alignment:.leading,spacing:8) {
                Image(systemName:icon).foregroundStyle(tint).font(.headline)
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct StrategyPerformance:Identifiable {
    let name:String
    let count:Int
    let net:Double
    let wins:Int
    var id:String{name}
}
