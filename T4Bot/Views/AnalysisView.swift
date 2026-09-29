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
                                        Text("AI MARKET ANALYSIS").font(.caption2.bold()).opacity(0.75)
                                        Text("تحليل السوق").font(.title.bold())
                                        Text("تحليل AI مستقل عن الاستراتيجيات الأخرى ويصدر BUY / SELL / WAIT للمحرك.").font(.caption).opacity(0.88)
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
                            Label("تحديث التحليل",systemImage:"arrow.clockwise")
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
                AnalysisSymbolPicker(initialSelection:selected) { saved in
                    selected=saved
                    Task { await appModel.update(symbols:saved.sorted()) }
                }
            }
            .loadingOverlay(appModel.isPerformingCommand)
        }
    }
    private func openPicker() { showPicker=true }
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
    @EnvironmentObject private var appModel:AppModel
    @Environment(\.dismiss) private var dismiss
    let initialSelection:Set<String>
    let onSave:(Set<String>)->Void

    @State private var selection:Set<String>
    @State private var query=""
    @State private var selectedExpanded=true
    @State private var activeExpanded=false
    @State private var allExpanded=false
    @State private var searchTask:Task<Void,Never>?

    init(initialSelection:Set<String>, onSave:@escaping(Set<String>)->Void) {
        self.initialSelection=initialSelection
        self.onSave=onSave
        _selection=State(initialValue:initialSelection)
    }

    private var selectedRows:[String] {
        selection.sorted().filter{query.isEmpty || $0.localizedCaseInsensitiveContains(query)}
    }
    private var activeRows:[String] {
        appModel.activeSymbols.filter{query.isEmpty || $0.localizedCaseInsensitiveContains(query)}
    }

    var body:some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing:12) {
                    symbolSection(
                        title:"مختارة",
                        count:selection.count,
                        expanded:$selectedExpanded,
                        rows:selectedRows
                    )

                    symbolSection(
                        title:"نشط الآن",
                        count:appModel.activeSymbols.count,
                        expanded:$activeExpanded,
                        rows:activeRows
                    )

                    DisclosureGroup(isExpanded:$allExpanded) {
                        LazyVStack(spacing:0) {
                            ForEach(appModel.availableSymbols,id:\.self){symbolRow($0)}
                            if appModel.symbolsHasMore {
                                Button {
                                    Task{await appModel.loadMoreSymbols()}
                                } label:{
                                    HStack {
                                        Spacer()
                                        Label("تحميل المزيد",systemImage:"arrow.down.circle")
                                        Spacer()
                                    }
                                    .padding(.vertical,14)
                                }
                            }
                        }
                    } label:{
                        HStack {
                            Text("الكل").font(.headline)
                            Spacer()
                            Text("\(appModel.symbolsTotal)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(.background.opacity(0.92),in:RoundedRectangle(cornerRadius:20,style:.continuous))
                }
                .padding(16)
            }
            .background(AppBackdrop())
            .searchable(text:$query,prompt:"ابحث بالرمز فقط")
            .navigationTitle("اختيار الأزواج")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction){Button("إلغاء"){dismiss()}}
                ToolbarItem(placement:.confirmationAction){
                    Button("حفظ"){
                        onSave(selection)
                        dismiss()
                    }.disabled(selection.isEmpty)
                }
            }
            .task {
                await appModel.loadSymbols(silent:true,force:true,query:"")
            }
            .onChange(of:query){_,newValue in
                searchTask?.cancel()
                searchTask=Task {
                    try? await Task.sleep(for:.milliseconds(300))
                    guard !Task.isCancelled else{return}
                    await appModel.loadSymbols(silent:true,force:true,query:newValue)
                    if !newValue.isEmpty {allExpanded=true}
                }
            }
        }
    }

    @ViewBuilder
    private func symbolSection(
        title:String,
        count:Int,
        expanded:Binding<Bool>,
        rows:[String]
    )->some View {
        DisclosureGroup(isExpanded:expanded) {
            LazyVStack(spacing:0) {
                if rows.isEmpty {
                    Text("لا توجد رموز").font(.caption).foregroundStyle(.secondary).padding(.vertical,12)
                } else {
                    ForEach(rows,id:\.self){symbolRow($0)}
                }
            }
        } label:{
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background.opacity(0.92),in:RoundedRectangle(cornerRadius:20,style:.continuous))
    }

    private func symbolRow(_ symbol:String)->some View {
        Button {
            if selection.contains(symbol){selection.remove(symbol)}
            else{selection.insert(symbol)}
        } label:{
            HStack {
                Text(symbol).font(.body.monospaced()).foregroundStyle(.primary)
                Spacer()
                Image(systemName:selection.contains(symbol) ? "checkmark.circle.fill":"circle")
                    .foregroundStyle(selection.contains(symbol) ? T4Palette.accent:.secondary)
            }
            .padding(.vertical,11)
        }
        .buttonStyle(.plain)
    }
}
