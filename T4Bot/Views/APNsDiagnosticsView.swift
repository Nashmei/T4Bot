import SwiftUI
import UIKit

struct APNsDiagnosticsView: View {
    @StateObject private var diagnostics = APNsDiagnostics.shared
    @State private var exportedFiles: [URL] = []
    @State private var showExporter = false
    @State private var exportError = ""

    private var profile: [String: String] { diagnostics.provisioningSummary() }

    var body: some View {
        Form {
            Section("APNs") {
                LabeledContent("الحالة") {
                    Text(diagnostics.status)
                        .foregroundStyle(diagnostics.status == "Registered" ? Color.green : Color.secondary)
                }
                LabeledContent("Environment") {
                    Text(profile["APNs Environment"] ?? "Unknown").font(.caption.monospaced())
                }
                if !diagnostics.lastError.isEmpty {
                    LabeledContent("آخر خطأ") {
                        Text(diagnostics.lastError).font(.caption).foregroundStyle(.red)
                    }
                }
                Button { diagnostics.register() } label: {
                    Label("تسجيل الجهاز مع APNs", systemImage: "bell.badge")
                }
            }

            Section("Device Token") {
                if diagnostics.token.isEmpty {
                    Text("لم يتم الحصول على Token بعد.").foregroundStyle(.secondary)
                } else {
                    Text(diagnostics.token).font(.caption.monospaced()).textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = diagnostics.token
                    } label: {
                        Label("نسخ Device Token", systemImage: "doc.on.doc")
                    }
                }
            }

            Section("Signing / Provisioning") {
                row("Bundle ID", profile["Bundle ID"])
                row("Application ID", profile["Application Identifier"])
                row("Team ID", profile["Team ID"])
                row("Profile", profile["Profile"])
                row("Profile UUID", profile["Profile UUID"])
                row("انتهاء Profile", profile["Profile Expires"])
            }

            Section("ملفات التشخيص") {
                Button { exportDiagnostics() } label: {
                    Label("استخراج الملفات", systemImage: "square.and.arrow.up")
                }
                if !exportError.isEmpty {
                    Text(exportError).font(.caption).foregroundStyle(.red)
                }
                Text("يستخرج embedded.mobileprovision و Info.plist وتقرير APNs من داخل التطبيق. المفتاح الخاص لشهادة التوقيع ليس جزءاً من IPA، لذلك لا يمكن استخراج P12/private key منه.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("APNs Diagnostics")
        .sheet(isPresented: $showExporter) { ShareSheet(items: exportedFiles) }
    }

    private func row(_ title: String, _ value: String?) -> some View {
        LabeledContent(title) {
            Text(value ?? "—").font(.caption.monospaced()).textSelection(.enabled)
        }
    }

    private func exportDiagnostics() {
        do {
            exportedFiles = try diagnostics.makeDiagnosticFiles()
            showExporter = true
            exportError = ""
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
