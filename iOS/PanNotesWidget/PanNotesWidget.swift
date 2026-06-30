import PanNotesCore
import SwiftUI
import WidgetKit

struct PanNotesEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
}

struct PanNotesTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PanNotesEntry {
        PanNotesEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PanNotesEntry) -> Void) {
        completion(PanNotesEntry(date: Date(), snapshot: loadSnapshot() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PanNotesEntry>) -> Void) {
        let entry = PanNotesEntry(date: Date(), snapshot: loadSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> WidgetSnapshot? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PanNotesMobileConstants.appGroupID
        ) else {
            return nil
        }

        let url = WidgetSnapshotStore.snapshotURL(in: containerURL)
        return try? WidgetSnapshotStore.load(from: url)
    }
}

struct PanNotesWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: PanNotesEntry

    var body: some View {
        let snapshot = entry.snapshot
        let selectedDot = snapshot?.selectedDot

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(snapshot?.dots ?? [], id: \.id) { dot in
                    Circle()
                        .fill(Color(hex: dot.tintHex))
                        .frame(width: dot.id == snapshot?.currentDotID ? 8 : 6, height: dot.id == snapshot?.currentDotID ? 8 : 6)
                        .opacity(dot.id == snapshot?.currentDotID ? 1 : 0.45)
                }
                Spacer(minLength: 0)
            }

            Text(selectedDot?.title ?? "Pan Notes")
                .font(.system(size: titleSize, weight: .semibold))
                .lineLimit(1)

            Text(previewText)
                .font(.system(size: bodySize))
                .foregroundStyle(.secondary)
                .lineLimit(bodyLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(widgetPadding)
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    private var previewText: String {
        guard let text = entry.snapshot?.selectedDot?.previewText, !text.isEmpty else {
            return "Open Pan Notes on iPhone to choose your iCloud Drive/PanNotes folder."
        }
        return text
    }

    private var titleSize: CGFloat {
        family == .systemSmall ? 14 : 15
    }

    private var bodySize: CGFloat {
        family == .systemSmall ? 13 : 14
    }

    private var bodyLineLimit: Int {
        switch family {
        case .systemSmall:
            return 5
        case .systemMedium:
            return 4
        default:
            return 2
        }
    }

    private var widgetPadding: CGFloat {
        family == .accessoryRectangular ? 6 : 12
    }
}

struct PanNotesWidget: Widget {
    let kind = "PanNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PanNotesTimelineProvider()) { entry in
            PanNotesWidgetView(entry: entry)
        }
        .configurationDisplayName("Pan Notes")
        .description("Show the current Pan Notes dot.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private extension WidgetSnapshot {
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: 1,
            currentDotID: "001",
            generatedAt: Date(),
            dots: [
                WidgetDotSnapshot(
                    id: "001",
                    title: "Dot 1",
                    displayOrder: 0,
                    themeToken: "yellow",
                    tintHex: "#D8A900",
                    previewText: "Choose your PanNotes folder in the iPhone app.",
                    updatedAt: Date()
                )
            ]
        )
    }
}

private extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
