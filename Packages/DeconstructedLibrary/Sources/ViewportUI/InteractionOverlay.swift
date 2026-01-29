import SwiftUI
import AppKit

/// A transparent NSView that captures native macOS events and bridges them to callbacks.
/// This sits on top of RealityView to intercept all mouse/trackpad interactions.
public struct InteractionOverlay: NSViewRepresentable {
    public var onMouseDown: (NSEvent) -> Void
    public var onMouseDragged: (NSEvent) -> Void
    public var onMouseUp: (NSEvent) -> Void
    public var onScroll: (NSEvent) -> Void
    public var onMagnify: (NSEvent) -> Void

    public init(
        onMouseDown: @escaping (NSEvent) -> Void = { _ in },
        onMouseDragged: @escaping (NSEvent) -> Void = { _ in },
        onMouseUp: @escaping (NSEvent) -> Void = { _ in },
        onScroll: @escaping (NSEvent) -> Void = { _ in },
        onMagnify: @escaping (NSEvent) -> Void = { _ in }
    ) {
        self.onMouseDown = onMouseDown
        self.onMouseDragged = onMouseDragged
        self.onMouseUp = onMouseUp
        self.onScroll = onScroll
        self.onMagnify = onMagnify
    }

    public func makeNSView(context: Context) -> EventView {
        let view = EventView()
        view.onMouseDown = onMouseDown
        view.onMouseDragged = onMouseDragged
        view.onMouseUp = onMouseUp
        view.onScroll = onScroll
        view.onMagnify = onMagnify
        return view
    }

    public func updateNSView(_ nsView: EventView, context: Context) {
        nsView.onMouseDown = onMouseDown
        nsView.onMouseDragged = onMouseDragged
        nsView.onMouseUp = onMouseUp
        nsView.onScroll = onScroll
        nsView.onMagnify = onMagnify
    }

    public class EventView: NSView {
        var onMouseDown: ((NSEvent) -> Void)?
        var onMouseDragged: ((NSEvent) -> Void)?
        var onMouseUp: ((NSEvent) -> Void)?
        var onScroll: ((NSEvent) -> Void)?
        var onMagnify: ((NSEvent) -> Void)?

        private var mouseCoord: CGPoint = .zero

        public override func mouseDown(with event: NSEvent) {
            mouseCoord = convert(event.locationInWindow, from: nil)
            onMouseDown?(event)
        }

        public override func mouseDragged(with event: NSEvent) {
            let newCoord = convert(event.locationInWindow, from: nil)
            // Store delta for consumers who need it
            mouseCoord = newCoord
            onMouseDragged?(event)
        }

        public override func mouseUp(with event: NSEvent) {
            onMouseUp?(event)
        }

        public override func scrollWheel(with event: NSEvent) {
            onScroll?(event)
        }

        public override func magnify(with event: NSEvent) {
            onMagnify?(event)
        }

        // Critical: Accept all events
        public override var acceptsFirstResponder: Bool { true }
        public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
