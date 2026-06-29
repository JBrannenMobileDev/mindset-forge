import SwiftUI
import WidgetKit

// MARK: - Timeline

struct FocusEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
}

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: Date(), payload: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        completion(FocusEntry(date: Date(), payload: WidgetPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let entry = FocusEntry(date: Date(), payload: WidgetPayload.load())
        // The app pushes updates on every relevant change; this periodic refresh
        // only keeps session-period theming current across the day.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct MindsetForgeWidget: Widget {
    let kind = "MindsetForgeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusProvider()) { entry in
            FocusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Focus")
        .description("Your #1 priority for today.")
        .supportedFamilies(Self.supportedFamilies)
    }

    static var supportedFamilies: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, *) {
            return [
                .systemSmall, .systemMedium, .systemLarge,
                .accessoryRectangular, .accessoryInline,
            ]
        } else {
            return [.systemSmall, .systemMedium, .systemLarge]
        }
    }
}

@main
struct MindsetForgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        MindsetForgeWidget()
    }
}
