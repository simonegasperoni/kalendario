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