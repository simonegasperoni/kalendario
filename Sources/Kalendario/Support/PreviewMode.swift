import SwiftUI

private struct KalendarioPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set only during static rendering (`--render-preview`): `ImageRenderer` does not draw
    /// the content of `ScrollView`s, so plain stacks are used instead.
    var kalendarioPreview: Bool {
        get { self[KalendarioPreviewKey.self] }
        set { self[KalendarioPreviewKey.self] = newValue }
    }
}

struct VerticalFlow<Content: View>: View {
    @Environment(\.kalendarioPreview) private var preview
    @ViewBuilder var content: Content

    var body: some View {
        if preview {
            // A static render cannot scroll, so the content is cut to the space it is given
            // and pinned to the top: letting it overflow would push the header, the day names
            // and the work-place row out of the picture.
            GeometryReader { geometry in
                VStack(spacing: 0) { content }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .clipped()
            }
        } else {
            ScrollView(.vertical) { content }
        }
    }
}

/// Vertical scrolling for a single day column, so a long day scrolls on its own.
/// In a static preview it degrades to the plain stack.
struct ColumnScrollModifier: ViewModifier {
    @Environment(\.kalendarioPreview) private var preview

    @ViewBuilder func body(content: Content) -> some View {
        if preview {
            content.clipped()
        } else {
            ScrollView(.vertical) { content }
        }
    }
}

/// Horizontal scrolling, used by the strip of sticky notes at the bottom.
struct RowScrollModifier: ViewModifier {
    @Environment(\.kalendarioPreview) private var preview

    @ViewBuilder func body(content: Content) -> some View {
        if preview {
            GeometryReader { geometry in
                HStack(spacing: 0) { content }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                    .clipped()
            }
        } else {
            ScrollView(.horizontal) { content }
        }
    }
}

extension View {
    func columnScroll() -> some View { modifier(ColumnScrollModifier()) }
    func rowScroll() -> some View { modifier(RowScrollModifier()) }
}

/// Inline text field (sticky note title, to-do rows).
/// In static previews it becomes a `Text`, because `ImageRenderer` does not draw
/// the content of AppKit text fields.
struct InlineField: View {
    @Environment(\.kalendarioPreview) private var preview

    @Binding var text: String
    var placeholder: String
    var font: Font = .system(size: 12.5)
    var color: Color = Theme.ink
    var strikethrough: Bool = false

    var body: some View {
        if preview {
            Text(text.isEmpty ? placeholder : text)
                .font(font)
                .foregroundStyle(text.isEmpty ? color.opacity(0.45) : color)
                .strikethrough(strikethrough, color: color.opacity(0.6))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(font)
                .foregroundStyle(color)
                .strikethrough(strikethrough, color: color.opacity(0.6))
        }
    }
}