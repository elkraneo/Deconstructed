import SwiftUI
import simd
import AppKit
import ViewportModels

/// View modifier that adds arcball camera controls to a view.
/// Handles mouse drag (orbit), option+drag (pan), scroll (pan), and option+scroll (zoom).
public struct ArcballCameraControls: ViewModifier {
    @Binding var state: ArcballCameraState
    let sceneBounds: SceneBounds
    let configuration: ViewportConfiguration

    // Interaction State
    @State private var startDistance: Float?
    @State private var mouseCoord: CGPoint = .zero
    @State private var lastClampedEdge: ClampEdge?

    public init(
        state: Binding<ArcballCameraState>,
        sceneBounds: SceneBounds,
        configuration: ViewportConfiguration = ViewportConfiguration()
    ) {
        self._state = state
        self.sceneBounds = sceneBounds
        self.configuration = configuration
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                // Transparent overlay that captures ALL events (sits on top of RealityView)
                InteractionOverlay(
                    onMouseDown: { event in
                        handleMouseDown(event)
                    },
                    onMouseDragged: { event in
                        handleMouseDragged(event)
                    },
                    onMouseUp: { event in
                        handleMouseUp(event)
                    },
                    onScroll: { event in
                        handleNativeScroll(event)
                    },
                    onMagnify: { event in
                        handleNativeMagnify(event)
                    }
                )
            }
    }

    // MARK: - Mouse Event Handlers

    private func handleMouseDown(_ event: NSEvent) {
        mouseCoord = event.locationInWindow
    }

    private func handleMouseDragged(_ event: NSEvent) {
        let newCoord = event.locationInWindow
        let deltaX = Float(newCoord.x - mouseCoord.x)
        let deltaY = Float(newCoord.y - mouseCoord.y)

        if event.modifierFlags.contains(.option) {
            // Option + Drag = Pan
            let multiplier: Float = event.modifierFlags.contains(.shift) ? 2.0 : 0.5
            handlePan(deltaX: deltaX * multiplier, deltaY: -deltaY * multiplier)
        } else {
            // Orbit - negate deltaY to match screen-to-world coordinate flip
            handleOrbit(deltaX: deltaX, deltaY: -deltaY)
        }

        mouseCoord = newCoord
    }

    private func handleMouseUp(_ event: NSEvent) {
        startDistance = nil
    }
    
    private enum ClampEdge {
        case min
        case max
    }

    private let clampEpsilon: Float = 0.0001

    private var minDistance: Float { configuration.minDistance }

    private var maxDistanceValue: Float {
        if let override = configuration.maxDistance {
            return Swift.max(override, minDistance)
        }

        let extent = Swift.max(Float(sceneBounds.maxExtent), 0.001)
        return Swift.max(1000.0, extent * 100000.0)
    }

    private func clampDistance(_ value: Float) -> Float {
        let maxDistance = maxDistanceValue
        let clamped = Swift.min(Swift.max(value, minDistance), maxDistance)
        let edge: ClampEdge?

        if clamped <= minDistance + clampEpsilon {
            edge = .min
        } else if clamped >= maxDistance - clampEpsilon {
            edge = .max
        } else {
            edge = nil
        }

        if edge != lastClampedEdge {
            if edge != nil {
                performHapticFeedback()
            }
            lastClampedEdge = edge
        }

        return clamped
    }

    private func performHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func handleOrbit(deltaX: Float, deltaY: Float) {
        let sensitivity: Float = 0.01
        
        var newRotation = state.rotation
        newRotation.y -= deltaX * sensitivity // Yaw
        newRotation.x -= deltaY * sensitivity // Pitch
        
        // Clamp pitch to prevent camera flip
        newRotation.x = Swift.max(-.pi / 2 + 0.01, Swift.min(.pi / 2 - 0.01, newRotation.x))
        
        state.rotation = newRotation
    }
    
    private func handlePan(deltaX: Float, deltaY: Float) {
        // Pan sensitivity scales with distance
        let scale = state.distance * 0.001
        
        // Calculate pan direction relative to camera rotation
        let rotX = simd_quatf(angle: state.rotation.x, axis: [1, 0, 0])
        let rotY = simd_quatf(angle: state.rotation.y, axis: [0, 1, 0])
        let orientation = rotY * rotX
        
        let right = orientation.act([1, 0, 0])
        let up = orientation.act([0, 1, 0])
        
        // Pan by delta
        state.focus += (right * (-deltaX * scale)) + (up * (deltaY * scale))
    }
    
    private func handleZoom(magnification: CGFloat) {
        if startDistance == nil { startDistance = state.distance }
        guard let start = startDistance else { return }
        guard magnification > 0 else { return }
        
        // Pinch out (scale > 1) -> zoom in (distance < start)
        let newDistance = start / Float(magnification)
        state.distance = clampDistance(newDistance)
    }
    
    private func handleNativeScroll(_ event: NSEvent) {
        // Scroll = Pan, Option+Scroll = Zoom
        if event.modifierFlags.contains(.option) {
            // Zoom
            let sensitivity: Float = 0.005
            let delta = Float(event.scrollingDeltaY) * sensitivity
            let newDistance = state.distance * (1.0 - delta)
            state.distance = clampDistance(newDistance)
        } else {
            // Pan
            let multiplier: Float = event.modifierFlags.contains(.shift) ? 5.0 : 1.0
            let deltaX = Float(event.scrollingDeltaX) * multiplier
            let deltaY = Float(event.scrollingDeltaY) * multiplier
            handlePan(deltaX: deltaX, deltaY: deltaY)
        }
    }
    
    private func handleNativeMagnify(_ event: NSEvent) {
        // Pinch out (positive magnification) -> zoom in (distance decreases)
        let sensitivity: Float = 1.0
        let delta = Float(event.magnification) * sensitivity
        let newDistance = state.distance * (1.0 - delta)
        state.distance = clampDistance(newDistance)
    }
}

// MARK: - View Extension

public extension View {
    /// Adds arcball camera controls to the view.
    func arcballCameraControls(
        state: Binding<ArcballCameraState>,
        sceneBounds: SceneBounds,
        configuration: ViewportConfiguration = ViewportConfiguration()
    ) -> some View {
        modifier(ArcballCameraControls(
            state: state,
            sceneBounds: sceneBounds,
            configuration: configuration
        ))
    }
}
