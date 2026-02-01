import DeconstructedFeatures
import DeconstructedUSDInterop
import SwiftUI
import ViewportModels

public struct ViewportMenuContext {
	public let canFrameScene: Bool
	public let canFrameSelected: Bool
	public let isGridVisible: Bool
	public let cameraHistory: [CameraHistoryItem]
	public let frameScene: () -> Void
	public let frameSelected: () -> Void
	public let toggleGrid: () -> Void
	public let selectCameraHistory: (CameraHistoryItem.ID) -> Void

	// Insert
	public let canInsert: Bool
	public let insertPrimitive: (USDPrimitiveType) -> Void
	public let insertStructural: (USDStructuralType) -> Void

	// Environment
	public let environmentConfiguration: EnvironmentConfiguration
	public let setEnvironmentPath: (String?) -> Void
	public let setEnvironmentShowBackground: (Bool) -> Void
	public let setEnvironmentRotation: (Float) -> Void
	public let setEnvironmentExposure: (Float) -> Void

	public init(
		canFrameScene: Bool,
		canFrameSelected: Bool,
		isGridVisible: Bool,
		cameraHistory: [CameraHistoryItem],
		frameScene: @escaping () -> Void,
		frameSelected: @escaping () -> Void,
		toggleGrid: @escaping () -> Void,
		selectCameraHistory: @escaping (CameraHistoryItem.ID) -> Void,
		canInsert: Bool = false,
		insertPrimitive: @escaping (USDPrimitiveType) -> Void = { _ in },
		insertStructural: @escaping (USDStructuralType) -> Void = { _ in },
		environmentConfiguration: EnvironmentConfiguration = EnvironmentConfiguration(),
		setEnvironmentPath: @escaping (String?) -> Void = { _ in },
		setEnvironmentShowBackground: @escaping (Bool) -> Void = { _ in },
		setEnvironmentRotation: @escaping (Float) -> Void = { _ in },
		setEnvironmentExposure: @escaping (Float) -> Void = { _ in }
	) {
		self.canFrameScene = canFrameScene
		self.canFrameSelected = canFrameSelected
		self.isGridVisible = isGridVisible
		self.cameraHistory = cameraHistory
		self.frameScene = frameScene
		self.frameSelected = frameSelected
		self.toggleGrid = toggleGrid
		self.selectCameraHistory = selectCameraHistory
		self.canInsert = canInsert
		self.insertPrimitive = insertPrimitive
		self.insertStructural = insertStructural
		self.environmentConfiguration = environmentConfiguration
		self.setEnvironmentPath = setEnvironmentPath
		self.setEnvironmentShowBackground = setEnvironmentShowBackground
		self.setEnvironmentRotation = setEnvironmentRotation
		self.setEnvironmentExposure = setEnvironmentExposure
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
