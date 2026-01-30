import SwiftUI
import DeconstructedFeatures

public struct ViewportMenuContext {
	public let canFrameScene: Bool
	public let canFrameSelected: Bool
	public let isGridVisible: Bool
	public let cameraHistory: [CameraHistoryItem]
	public let frameScene: () -> Void
	public let frameSelected: () -> Void
	public let toggleGrid: () -> Void
	public let selectCameraHistory: (CameraHistoryItem.ID) -> Void

	public init(
		canFrameScene: Bool,
		canFrameSelected: Bool,
		isGridVisible: Bool,
		cameraHistory: [CameraHistoryItem],
		frameScene: @escaping () -> Void,
		frameSelected: @escaping () -> Void,
		toggleGrid: @escaping () -> Void,
		selectCameraHistory: @escaping (CameraHistoryItem.ID) -> Void
	) {
		self.canFrameScene = canFrameScene
		self.canFrameSelected = canFrameSelected
		self.isGridVisible = isGridVisible
		self.cameraHistory = cameraHistory
		self.frameScene = frameScene
		self.frameSelected = frameSelected
		self.toggleGrid = toggleGrid
		self.selectCameraHistory = selectCameraHistory
	}
}

private struct ViewportMenuContextKey: FocusedValueKey {
	typealias Value = ViewportMenuContext
}

public extension FocusedValues {
	var viewportMenuContext: ViewportMenuContext? {
		get { self[ViewportMenuContextKey.self] }
		set { self[ViewportMenuContextKey.self] = newValue }
	}
}
