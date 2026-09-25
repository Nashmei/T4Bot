import Foundation
import UIKit
import UserNotifications

@MainActor
final class APNsDiagnostics: NSObject, ObservableObject {
    static let shared = APNsDiagnostics()

    @Published private(set) var token = ""
    @Published private(set) var status = "Not registered"
    @Published private(set) var lastError = ""

    func register() {
        status = "Registering..."
        lastError = ""
        UIApplication.shared.registerForRemoteNotifications()
    }

    func registered(_ deviceToken: Data) {
        token = deviceToken.map {
            String(format: "%02x", $0)
        }.joined()

        status = "Registered"
        lastError = ""
    }

    func failed(_ error: Error) {
        status = "Failed"
        lastError = error.localizedDescription
    }

    func provisioningSummary() -> [String: String] {
        guard
            let url = Bundle.main.url(
                forResource: "embedded",
                withExtension: "mobileprovision"
            ),
            let data = try? Data(contentsOf: url),
            let raw = String(data: data, encoding: .isoLatin1),
            let start = raw.range(of: "<?xml"),
            let end = raw.range(of: "</plist>", options: .backwards)
        else {
            return [
                "Bundle ID": Bundle.main.bundleIdentifier ?? "",
                "Profile": "Not found"
            ]
        }

        let xml = String(raw[start.lowerBound..<end.upperBound])

        guard
            let xmlData = xml.data(using: .utf8),
            let plist = try? PropertyListSerialization.propertyList(
                from: xmlData,
                format: nil
            ),
            let root = plist as? [String: Any]
        else {
            return [:]
        }

        let entitlements =
            root["Entitlements"] as? [String: Any] ?? [:]

        var result: [String: String] = [:]

        result["Bundle ID"] =
            Bundle.main.bundleIdentifier ?? ""

        result["Profile"] =
            root["Name"] as? String

        result["Profile UUID"] =
            root["UUID"] as? String

        result["Team ID"] =
            (root["TeamIdentifier"] as? [String])?.first

        result["Application Identifier"] =
            entitlements["application-identifier"] as? String

        result["APNs Environment"] =
            entitlements["aps-environment"] as? String

        if let date = root["ExpirationDate"] as? Date {
            result["Profile Expires"] =
                ISO8601DateFormatter().string(from: date)
        }

        return result
    }

    func makeDiagnosticFiles() throws -> [URL] {
        let fm = FileManager.default

        let directory = fm.temporaryDirectory
            .appendingPathComponent(
                "T4Bot-APNs-Diagnostics",
                isDirectory: true
            )

        try? fm.removeItem(at: directory)

        try fm.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        var files: [URL] = []

        // embedded.mobileprovision
        if let source = Bundle.main.url(
            forResource: "embedded",
            withExtension: "mobileprovision"
        ) {
            let destination =
                directory.appendingPathComponent(
                    "embedded.mobileprovision"
                )

            try fm.copyItem(
                at: source,
                to: destination
            )

            files.append(destination)
        }

        // Info.plist
        if let info = Bundle.main.infoDictionary {
            let destination =
                directory.appendingPathComponent("Info.plist")

            let data =
                try PropertyListSerialization.data(
                    fromPropertyList: info,
                    format: .xml,
                    options: 0
                )

            try data.write(to: destination)
            files.append(destination)
        }

        // Human-readable APNs report
        var summary = provisioningSummary()

        summary["Device Token"] = token
        summary["Registration"] = status
        summary["Last Error"] = lastError

        let reportText =
            summary.keys
                .sorted()
                .map {
                    "\($0): \(summary[$0] ?? "")"
                }
                .joined(separator: "\n")
            + "\n"

        let report =
            directory.appendingPathComponent(
                "apns-diagnostics.txt"
            )

        try Data(reportText.utf8).write(to: report)

        files.append(report)

        return files
    }
}
