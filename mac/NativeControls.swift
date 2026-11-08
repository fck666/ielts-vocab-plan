import SwiftUI

struct NativeSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var symbol: String? = nil
    var id: Value { value }
}

/// Shared mode picker: semantic surfaces, native buttons, keyboard focus and reduced-motion support.
struct NativeSegmentedControl<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [NativeSegmentOption<Value>]
    var accent: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight
    @State private var hoveredValue: Value?
    @FocusState private var focusedValue: Value?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let selected = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 6) {
                        if let symbol = option.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selected ? accent : Color.secondary)
                        }
                        Text(option.title)
                            .font(.system(size: 12, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .padding(.horizontal, 8)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(accent.opacity(0.22)))
                                .shadow(color: Color(nsColor: .shadowColor).opacity(0.08), radius: 2, y: 1)
                                .matchedGeometryEffect(id: "selection", in: highlight)
                        } else if hoveredValue == option.value {
                            RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04))
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .focused($focusedValue, equals: option.value)
                .onKeyPress(.leftArrow) { moveSelection(from: option.value, by: -1) }
                .onKeyPress(.rightArrow) { moveSelection(from: option.value, by: 1) }
                .onHover { hovering in
                    hoveredValue = hovering ? option.value : nil
                }
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .help(option.title)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func moveSelection(from value: Value, by offset: Int) -> KeyPress.Result {
        guard let index = options.firstIndex(where: { $0.value == value }) else { return .ignored }
        let next = index + offset
        guard options.indices.contains(next) else { return .handled }
        selection = options[next].value
        focusedValue = selection
        return .handled
    }
}
