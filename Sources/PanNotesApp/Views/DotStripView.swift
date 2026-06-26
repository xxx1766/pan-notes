import PanNotesCore
import SwiftUI

struct DotStripView: View {
    let dots: [Dot]
    let theme: Theme
    let selectedDotID: String
    let onSelect: (Dot) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            ForEach(dots.sorted { $0.displayOrder < $1.displayOrder }) { dot in
                Button {
                    onSelect(dot)
                } label: {
                    dotMarker(for: dot)
                }
                .buttonStyle(.plain)
                .help(dot.title)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func dotMarker(for dot: Dot) -> some View {
        let color = color(for: dot)
        let isSelected = selectedDotID == dot.id

        return ZStack {
            Circle()
                .fill(isSelected ? color.opacity(0.14) : Color.clear)
                .frame(width: 24, height: 24)
            Circle()
                .fill(color)
                .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.72 : 0), lineWidth: 1)
                )
                .shadow(color: color.opacity(isSelected ? 0.28 : 0), radius: 3, y: 1)
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
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
