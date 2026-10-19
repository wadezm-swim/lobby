import SwiftUI

// MARK: - Layouts

/// The design's `repeat(auto-fit, minmax(260px, 1fr))` grid: as many columns as
/// fit, and every card in a row stretched to the tallest one.
struct CardGrid: Layout {
    var minColumnWidth: CGFloat = 260
    var spacing: CGFloat = 20

    private func columns(for width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minColumnWidth + spacing)))
    }

    private func columnWidth(for width: CGFloat, columns: Int) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func rowHeights(_ subviews: Subviews, columns: Int, columnWidth: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height }
                .max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (minColumnWidth * 4 + spacing * 3)
        let cols = columns(for: width)
        let heights = rowHeights(subviews, columns: cols, columnWidth: columnWidth(for: width, columns: cols))
        let height = heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cols = columns(for: bounds.width)
        let colWidth = columnWidth(for: bounds.width, columns: cols)
        var y = bounds.minY
        for (row, height) in rowHeights(subviews, columns: cols, columnWidth: colWidth).enumerated() {
            for col in 0..<cols {
                let index = row * cols + col
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(col) * (colWidth + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: colWidth, height: height))
            }
            y += height + spacing
        }
    }
}

/// Lays chips out left to right and wraps, like `flex-wrap`.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private func rows(_ subviews: Subviews, width: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append((index, size))
            x += size.width + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let laidOut = rows(subviews, width: width)
        let height = laidOut.map { $0.map(\.size.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(0, laidOut.count - 1))
        let used = laidOut.map { row in row.map(\.size.width).reduce(0, +) + spacing * CGFloat(max(0, row.count - 1)) }.max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, width: bounds.width) {
            var x = bounds.minX
            let height = row.map(\.size.height).max() ?? 0
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y + (height - item.size.height) / 2), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += height + spacing
        }
    }
}

// MARK: - Cards

extension View {
    /// A design card: 28pt corners, filled, content pinned to the top left.
    func card(_ fill: Color, padding: CGFloat = 24, minHeight: CGFloat? = nil) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
            .background(fill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// "Body" on the left, "from Apple Health" on the right.
struct CardHeader: View {
    @Environment(\.palette) var palette
    let title: String
    var trailing: String?
    var size: CGFloat = 18

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.urbanist(size, .bold))
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing).font(.urbanist(13)).foregroundStyle(palette.muted)
            }
        }
    }
}

/// A tickable row in a fully round pill, as in "Top three".
struct CheckRow: View {
    @Environment(\.palette) var palette
    let title: String
    let done: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 10 : 12) {
                ZStack {
                    if done {
                        Circle().fill(palette.ink)
                        Image(systemName: "checkmark")
                            .font(.system(size: compact ? 10 : 12, weight: .bold))
                            .foregroundStyle(palette.lime)
                    } else {
                        Circle().strokeBorder(palette.ring, lineWidth: 2)
                    }
                }
                .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
                Text(title)
                    .font(.urbanist(compact ? 14 : 15, .medium))
                    .foregroundStyle(done ? palette.muted : palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: compact ? 40 : 44)
            .background(palette.fill, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

/// Two or more fully round options in a pill, like Work / Off duty.
struct PillPicker<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    let selection: Value
    var background: Color
    var selectedFill: Color
    var selectedText: Color
    var text: Color
    let choose: (Value) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let on = option.value == selection
                Button { choose(option.value) } label: {
                    Text(option.label)
                        .font(.urbanist(14, on ? .bold : .semibold))
                        .foregroundStyle(on ? selectedText : text)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(on ? selectedFill : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(background, in: Capsule())
    }
}

/// A rounded label like "Well rested" or "Walkthrough today".
struct Chip: View {
    let text: String
    let fill: Color
    var ink: Color
    var size: CGFloat = 15
    var weight: Font.Weight = .bold

    var body: some View {
        Text(text)
            .font(.urbanist(size, weight))
            .foregroundStyle(ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(fill, in: Capsule())
    }
}

/// The black round button with a lime arrow on the Next up card.
struct ArrowBadge: View {
    @Environment(\.palette) var palette

    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(palette.lime)
            .frame(width: 40, height: 40)
            .background(Color(hex: "#0E0E0E"), in: Circle())
    }
}

/// "Monday 19 October · sample data" above a big title.
struct RoomTitle: View {
    @Environment(\.palette) var palette
    let kicker: String?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let kicker {
                Text(kicker).font(.urbanist(14, .medium)).foregroundStyle(palette.muted)
            }
            Text(title)
                .font(.urbanist(44, .bold))
                .tracking(-0.9)
                .foregroundStyle(palette.ink)
        }
    }
}

/// A soft blurred circle of colour behind dark cards: team glows.
struct Glow: View {
    let color: Color
    var size: CGFloat = 440
    var blur: CGFloat = 110
    var opacity: Double = 0.45

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A label/value line with a hairline above it, used across the Sports room.
struct DividedRow: View {
    @Environment(\.palette) var palette
    let label: String
    let value: String
    var valueFont: Font = .titillium(16, .bold)
    var verticalPadding: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(palette.divider).frame(height: 1)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).font(.urbanist(15)).foregroundStyle(Palette.sportsSecondary)
                Spacer(minLength: 8)
                Text(value).font(valueFont).foregroundStyle(palette.ink).multilineTextAlignment(.trailing)
            }
            .padding(.vertical, verticalPadding)
        }
    }
}
