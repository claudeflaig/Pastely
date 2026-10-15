import SwiftUI

/// What follows the pointer while a clip is dragged: a small, solid label
/// instead of a see-through copy of the whole card, so the tabs it is
/// dragged over stay in sight.
struct ClipDragPreview: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIconProvider.icon(forBundleID: item.sourceBundleID))
                .resizable().interpolation(.high)
                .frame(width: 20, height: 20)
            if item.type == .color, let color = Color(hex: item.colorHex ?? "") {
                Circle().fill(color).frame(width: 12, height: 12)
            }
            Text(item.displayTitle)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(height: 32)
        .frame(maxWidth: 220)
        .background(SourceColor.color(for: item.sourceBundleID), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .fixedSize()
    }
}
