import WidgetKit
import SwiftUI

// MARK: - Timeline

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: .now)
    }
    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

// MARK: - Widget View

struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .widgetURL(URL(string: "pinly://quickadd")!)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var smallView: some View {
        VStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
            Text("Hızlı Ekle")
                .font(.caption)
                .fontWeight(.semibold)
            Text("Konumunu kaydet")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Hızlı Mekan Ekle")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Mevcut konumunu tek dokunuşla\nPinly mekanlarına ekle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct QuickAddWidget: Widget {
    let kind = "com.ferhatakkopru.Pinly.QuickAdd"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { _ in
            QuickAddWidgetView()
        }
        .configurationDisplayName("Hızlı Ekle")
        .description("Mevcut konumunu tek dokunuşla mekanlarına ekle")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
