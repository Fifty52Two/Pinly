import MetricKit
import Foundation

// MARK: - DiagnosticsCollector

/// MetricKit abone — uygulama crash/hang tanılama verilerini UserDefaults'ta
/// en fazla 50 satır tutarak geliştiriciye profil ekranından gösterir.
/// Apple Developer hesabı olmadan da çalışır; Crashlytics kurulana kadar
/// geçici hata izleme olarak kullanılır.
final class DiagnosticsCollector: NSObject {
    static let shared = DiagnosticsCollector()

    private let logKey = "pinly.diagnosticLog"
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    var log: [String] {
        UserDefaults.standard.stringArray(forKey: logKey) ?? []
    }

    func register() {
        MXMetricManager.shared.add(self)
    }

    func clearLog() {
        UserDefaults.standard.removeObject(forKey: logKey)
    }

    private func appendLog(_ entry: String) {
        var current = log
        current.insert(entry, at: 0)
        UserDefaults.standard.set(Array(current.prefix(50)), forKey: logKey)
    }

    private func timestamp() -> String {
        dateFormatter.string(from: Date())
    }
}

// MARK: - MXMetricManagerSubscriber

extension DiagnosticsCollector: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        appendLog("[\(timestamp())] Metrics: \(payloads.count) payload(s) received")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let summary = String(crash.callStackTree.jsonRepresentation()
                    .prefix(120).description)
                appendLog("[\(timestamp())] Crash: \(summary)")
            }
            for hang in payload.hangDiagnostics ?? [] {
                let secs = hang.hangDuration.converted(to: .seconds).value
                appendLog("[\(timestamp())] Hang: \(String(format: "%.2f", secs))s")
            }
            for cpu in payload.cpuExceptionDiagnostics ?? [] {
                let secs = cpu.totalCPUTime.converted(to: .seconds).value
                appendLog("[\(timestamp())] CPU: \(String(format: "%.1f", secs))s")
            }
            for disk in payload.diskWriteExceptionDiagnostics ?? [] {
                appendLog("[\(timestamp())] DiskWrite: \(disk.totalWritesCaused) bytes")
            }
        }
    }
}
