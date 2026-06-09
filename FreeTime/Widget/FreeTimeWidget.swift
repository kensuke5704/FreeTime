import SwiftUI
import WidgetKit

struct FreeTimeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct FreeTimeProvider: TimelineProvider {
    func placeholder(in context: Context) -> FreeTimeEntry {
        FreeTimeEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FreeTimeEntry) -> Void) {
        completion(FreeTimeEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FreeTimeEntry>) -> Void) {
        let entry = FreeTimeEntry(date: .now, snapshot: loadSnapshot())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadSnapshot() -> WidgetSnapshot {
        guard
            let data = SharedDefaults.defaults.data(forKey: SharedDefaults.snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}

struct FreeTimeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FreeTimeEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text("空き")
                    .font(.caption2)
                Text(shortDuration)
                    .font(.system(.caption, design: .rounded).bold())
            }
            .widgetLabel { Text("今日の空き時間") }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("空き時間 \(duration)")
                    .font(.headline)
                if let next = nextText {
                    Text(next).font(.caption)
                }
            }

        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                Text("空き時間")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(duration)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                Spacer()
                if let next = nextText {
                    Label(next, systemImage: "clock")
                        .font(.caption)
                        .lineLimit(2)
                }
            }

        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("今日")
                        .font(.headline)
                    Spacer()
                    Text("空き時間 \(duration)")
                        .font(.headline)
                }
                Divider()
                if let title = entry.snapshot.nextTitle, let start = entry.snapshot.nextStart {
                    Text("次の予定")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(start, style: .time).fontWeight(.semibold)
                        Text(title).fontWeight(.semibold)
                        Spacer()
                    }
                } else {
                    ContentUnavailableView("次の予定はありません", systemImage: "calendar")
                }
            }
        }
    }

    private var duration: String { entry.snapshot.freeMinutes.durationText }
    private var shortDuration: String {
        "\(entry.snapshot.freeMinutes / 60)h\(entry.snapshot.freeMinutes % 60)m"
    }
    private var nextText: String? {
        guard let title = entry.snapshot.nextTitle, let start = entry.snapshot.nextStart else { return nil }
        return "\(start.formatted(date: .omitted, time: .shortened)) \(title)"
    }
}

struct FreeTimeWidget: Widget {
    let kind = "FreeTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FreeTimeProvider()) { entry in
            FreeTimeWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("FreeTime")
        .description("今日の空き時間と次の予定を表示します。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

@main
struct FreeTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        FreeTimeWidget()
    }
}
