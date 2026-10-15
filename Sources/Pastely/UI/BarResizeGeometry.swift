import CoreGraphics

/// Pure sizing rules shared by the Paste Bar's persisted preference and its
/// live-resize interaction.
enum BarResizeGeometry {
    static let defaultHeight = 430.0
    static let minimumHeight = 300.0
    static let maximumHeight = 720.0
    /// Gap between the floating bar and the screen edges around it.
    static let screenMargin: CGFloat = 8

    /// Returns a value which is safe to persist independently of the display
    /// the bar happens to be shown on.
    static func normalizedPersistedHeight(_ height: Double) -> Double {
        guard height.isFinite else { return defaultHeight }
        return min(maximumHeight, max(minimumHeight, height))
    }

    /// Applies the portable preference range first, then caps the result to
    /// the usable height of the target display.
    static func effectiveHeight(
        for requestedHeight: Double,
        in visibleFrame: CGRect
    ) -> CGFloat {
        let displayHeight = visibleFrame.height - 2 * screenMargin
        guard displayHeight.isFinite, displayHeight > 0 else { return 0 }
        return min(CGFloat(normalizedPersistedHeight(requestedHeight)), displayHeight)
    }

    /// Produces the complete panel frame, floating `screenMargin` in from the
    /// bottom or top edge and both sides of a target display.
    static func panelFrame(
        for requestedHeight: Double,
        in visibleFrame: CGRect,
        topDocked: Bool = false
    ) -> CGRect {
        dockedFrame(height: effectiveHeight(for: requestedHeight, in: visibleFrame),
                    in: visibleFrame, topDocked: topDocked)
    }

    static func dockedFrame(height: CGFloat, in visibleFrame: CGRect, topDocked: Bool) -> CGRect {
        CGRect(
            x: visibleFrame.minX + screenMargin,
            y: topDocked ? visibleFrame.maxY - screenMargin - height
                         : visibleFrame.minY + screenMargin,
            width: max(0, visibleFrame.width - 2 * screenMargin),
            height: height
        )
    }
}

/// Immutable state captured at mouse-down so live resizing does not feed the
/// moving panel geometry back into the drag calculation.
struct BarResizeSession: Equatable {
    let initialPanelHeight: CGFloat
    let initialScreenY: CGFloat
    let visibleFrame: CGRect
    let topDocked: Bool

    init(
        initialPanelHeight: CGFloat,
        initialScreenY: CGFloat,
        visibleFrame: CGRect,
        topDocked: Bool = false
    ) {
        self.visibleFrame = visibleFrame
        self.topDocked = topDocked
        self.initialPanelHeight = BarResizeGeometry.effectiveHeight(
            for: Double(initialPanelHeight),
            in: visibleFrame
        )
        self.initialScreenY = initialScreenY
    }

    /// Global macOS screen coordinates increase upward, so for a bottom bar
    /// upward pointer travel adds to the height; a top bar grows downward.
    func height(atScreenY screenY: CGFloat) -> CGFloat {
        guard initialScreenY.isFinite, screenY.isFinite else {
            return initialPanelHeight
        }
        let travel = screenY - initialScreenY
        let requestedHeight = initialPanelHeight + (topDocked ? -travel : travel)
        return BarResizeGeometry.effectiveHeight(
            for: Double(requestedHeight),
            in: visibleFrame
        )
    }

    func frame(atScreenY screenY: CGFloat) -> CGRect {
        BarResizeGeometry.dockedFrame(height: height(atScreenY: screenY),
                                      in: visibleFrame, topDocked: topDocked)
    }

    /// The portable value to write only after a successful drag completes.
    func finalPersistedHeight(atScreenY screenY: CGFloat) -> Double {
        BarResizeGeometry.normalizedPersistedHeight(
            Double(height(atScreenY: screenY))
        )
    }

    var cancelledHeight: CGFloat { initialPanelHeight }

    var cancelledFrame: CGRect {
        BarResizeGeometry.dockedFrame(height: initialPanelHeight,
                                      in: visibleFrame, topDocked: topDocked)
    }
}
