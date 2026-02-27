import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TapToPayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TapToPayEntry {
        TapToPayEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TapToPayEntry) -> Void) {
        completion(TapToPayEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TapToPayEntry>) -> Void) {
        // Static widget — no dynamic data, never refreshes
        completion(Timeline(entries: [TapToPayEntry(date: .now)], policy: .never))
    }
}

struct TapToPayEntry: TimelineEntry {
    let date: Date
}

// MARK: - Widget Views

struct TapToPayWidgetEntryView: View {
    var entry: TapToPayEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            HomeScreenWidgetView()
        case .accessoryCircular:
            LockScreenCircularView()
        case .accessoryRectangular:
            LockScreenRectangularView()
        default:
            HomeScreenWidgetView()
        }
    }
}

// MARK: - Home Screen (.systemSmall)

private struct HomeScreenWidgetView: View {
    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.black)

            VStack(spacing: 8) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)

                Text("Tap to Pay")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("WalletConnect")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Lock Screen Circular (.accessoryCircular)

private struct LockScreenCircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "wave.3.right")
                .font(.system(size: 20, weight: .semibold))
        }
    }
}

// MARK: - Lock Screen Rectangular (.accessoryRectangular)

private struct LockScreenRectangularView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Tap to Pay")
                    .font(.system(size: 14, weight: .semibold))
                Text("NFC Payment")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Widget Definition

struct TapToPayWidget: Widget {
    let kind: String = "TapToPayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TapToPayProvider()) { entry in
            TapToPayWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "walletapp://nfc-pay")!)
        }
        .configurationDisplayName("Tap to Pay")
        .description("Quick NFC payment shortcut")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Preview

#if DEBUG
struct TapToPayWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TapToPayWidgetEntryView(entry: TapToPayEntry(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Home Screen")

            TapToPayWidgetEntryView(entry: TapToPayEntry(date: .now))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Lock Screen Circular")

            TapToPayWidgetEntryView(entry: TapToPayEntry(date: .now))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Lock Screen Rectangular")
        }
    }
}
#endif
