import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showPicker=false
    @State private var selected=Set<String>()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                ScrollView {
                    VStack(spacing:14) {
                        HeroCard {
                            VStack(alignment:.leading,spacing:14) {
                                HStack {
                                    VStack(alignment:.leading,spacing:4) {
                                        Text("AI MARKET SCAN").font(.caption2.bold()).opacity(0.75)
                                        Text("التحليل").font(.title.bold())
                                        Text("اختر الأزواج التي تريد تفعيل بياناتها وتحليلها.").font(.caption).opacity(0.85)
                                    }
                                    Spacer()
                                    Image(systemName:"sparkles").font(.title.bold())
                                }
                                HStack {
                                    Button { openPicker() } label: { Label("اختيار الأزواج",systemImage:"plus.circle.fill") }
                                        .buttonStyle(.bordered).tint(.white)
                                    Spacer()
                                    Text("\(selected.count) نشط").font(.caption.bold())
                                }
                            }
                        }
                        if !selected.isEmpty {
                            ScrollView(.horizontal,showsIndicators:false) {
                                HStack(spacing:8) {
                                    ForEach(selected.sorted(),id:\.self) { x in
                                        Text(x).font(.caption.bold()).padding(.horizontal,11).padding(.vertical,7)
                                            .background(T4Palette.accent.opacity(0.12),in:Capsule())
                                    }
                                }
                            }
                        }
                        Button { Task { await appModel.runAnalysis() } } label: {
                            Label("تحليل الأزواج النشطة",systemImage:"waveform.path.ecg")
                                .fontWeight(.bold).frame(maxWidth:.infinity).padding(.vertical,10)
                        }.buttonStyle(.borderedProminent).tint(T4Palette.accent).disabled(selected.isEmpty || appModel.isPerformingCommand)

                        if let s=appModel.snapshot {
                            if s.analysis.isEmpty {
                                ContentUnavailableView("لا يوجد تحليل بعد",systemImage:"chart.xyaxis.line",description:Text("اختر الأزواج ثم ابدأ التحليل.")).padding(.top,28)
                            } else {
                                ForEach(s.analysis.filter { selected.contains($0.symbol) }) { AnalysisCard(item:$0) }
                            }
                        }
                    }.padding(16)
                }
            }
            .navigationTitle("التحليل").navigationBarTitleDisplayMode(.inline)
            .onAppear { selected=Set(appModel.snapshot?.settings.symbols ?? []) }
            .sheet(isPresented:$showPicker) {
                AnalysisSymbolPicker(available:appModel.availableSymbols, initialSelection:selected) { saved in
                    selected=saved
                    Task { await appModel.update(symbols:saved.sorted()) }
                }
            }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }
    private func openPicker() { showPicker=true; Task { await appModel.loadSymbols() } }
}

private struct AnalysisCard:View {
    let item:AnalysisSnapshot
    var body:some View {
        SurfaceCard {
            VStack(spacing:12) {
                HStack {
                    VStack(alignment:.leading,spacing:3) { Text(item.symbol).font(.title3.bold()); Text(item.regime.replacingOccurrences(of:"_",with:" ")).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(item.state=="signal" ? "فرصة" : "انتظار").font(.caption.bold()).padding(.horizontal,10).padding(.vertical,6)
                        .background((item.state=="signal" ? T4Palette.positive:Color.secondary).opacity(0.11),in:Capsule())
                }
                Divider()
                HStack {
                    Label(item.state=="signal" ? (item.side=="BUY" ? "شراء":"بيع") : "لا توجد صفقة",systemImage:item.state=="signal" ? "arrow.up.right.circle.fill":"pause.circle")
                    Spacer()
                    if let c=item.confidence { Text("\(Int(c))%").font(.headline.monospacedDigit()) }
                }
                if let strategy=item.strategy { Text(strategy.replacingOccurrences(of:"_",with:" ")).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading) }
            }
        }
    }
}

private struct AnalysisSymbolPicker:View {
    let available:[String]; let initialSelection:Set<String>; let onSave:(Set<String>)->Void
    @State private var selection:Set<String>
    init(available:[String], initialSelection:Set<String>, onSave:@escaping(Set<String>)->Void) {
        self.available=available; self.initialSelection=initialSelection; self.onSave=onSave
        _selection=State(initialValue:initialSelection)
    }
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    private let popular=["XAUUSD","XAGUSD","EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","USDCHF","NZDUSD","EURJPY","GBPJPY","EURGBP"]
    private var filtered:[String] {
        let source=query.isEmpty ? available:available.filter{$0.localizedCaseInsensitiveContains(query)}
        return source.sorted { a,b in
            let ai=popular.firstIndex(where:{a.uppercased().contains($0)}) ?? 999
            let bi=popular.firstIndex(where:{b.uppercased().contains($0)}) ?? 999
            return ai == bi ? a.localizedStandardCompare(b) == .orderedAscending : ai < bi
        }
    }
    var body:some View {
        NavigationStack {
            List(filtered,id:\.self) { x in
                Button { if selection.contains(x){selection.remove(x)}else{selection.insert(x)} } label:{
                    HStack { Text(x).foregroundStyle(.primary); Spacer(); Image(systemName:selection.contains(x) ? "checkmark.circle.fill":"circle").foregroundStyle(selection.contains(x) ? T4Palette.accent:.secondary) }
                }
            }.searchable(text:$query,prompt:"ابحث في رموز MT5").navigationTitle("اختيار الأزواج")
            .toolbar {
                ToolbarItem(placement:.cancellationAction){Button("إلغاء"){dismiss()}}
                ToolbarItem(placement:.confirmationAction){Button("حفظ"){onSave(selection);dismiss()}.disabled(selection.isEmpty)}
            }
        }
    }
}
