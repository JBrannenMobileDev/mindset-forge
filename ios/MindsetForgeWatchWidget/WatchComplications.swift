import SwiftUI
import WidgetKit

struct WatchFocusEntry: TimelineEntry {
    let date: Date
    let payload: WatchPayload
}

struct WatchFocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchFocusEntry {
        WatchFocusEntry(date: Date(), payload: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchFocusEntry) -> Void) {
        completion(WatchFocusEntry(date: Date(), payload: WatchPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchFocusEntry>) -> Void) {
        let entry = WatchFocusEntry(date: Date(), payload: WatchPayload.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let payload: WatchPayload

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(payload.isDone ? "Focus done" : payload.glanceLine,
                  systemImage: payload.isDone ? "checkmark.circle" : "scope")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if payload.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                } else if payload.streak > 0 {
                    VStack(spacing: 0) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(payload.streak)")
                            .font(.system(size: 15, weight: .bold))
                    }
                } else {
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .bold))
                }
            }
        case .accessoryCorner:
            Image(systemName: payload.isDone ? "checkmark.circle.fill" : "scope")
                .font(.system(size: 18, weight: .bold))
                .widgetLabel(payload.glanceLine)
        default: // .accessoryRectangular
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: payload.isDone ? "checkmark.circle.fill" : "scope")
                    Text("Today's Focus")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(payload.glanceLine)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
            }
        }
    }
}

struct WatchFocusComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MindsetForgeWatchWidget", provider: WatchFocusProvider()) { entry in
            WatchComplicationView(payload: entry.payload)
        }
        .configurationDisplayName("Focus")
        .description("Today's focus and streak.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

@main
struct MindsetForgeWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchFocusComplication()
    }
}
