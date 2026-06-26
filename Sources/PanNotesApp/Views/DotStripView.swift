import PanNotesCore
import SwiftUI

struct DotStripView: View {
    let dots: [Dot]
    let theme: Theme
    let selectedDotID: String
    let onSelect: (Dot) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(dots.sorted { $0.displayOrder < $1.displayOrder }) { dot in
                Button {
                    onSelect(dot)
                } label: {
                    Circle()
                        .fill(color(for: dot))
                        .frame(
                            width: selectedDotID == dot.id ? 16 : 12,
                            height: selectedDotID == dot.id ? 16 : 12
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(selectedDotID == dot.id ? 0.45 : 0), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .help(dot.title)
            }
            Spacer()
        }
        .padding(12)
    }

    private func color(for dot: Dot) -> Color {
        let hex = theme.variants.first { $0.name == dot.themeToken }?.light.dot ?? "#D8A900"
        return Color(hex: hex)
    }
}

private extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = Int(raw, radix: 16) ?? 0xD8A900
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
