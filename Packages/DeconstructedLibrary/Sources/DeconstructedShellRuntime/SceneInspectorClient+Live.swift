import ComposableArchitecture
import Foundation
import InspectorFeature
import SwiftUsdShell

extension SceneInspectorClient {
	/// The OpenUSD-backed implementation. Install at app startup via
	/// `prepareDependencies { $0.sceneInspector = .live }` so that
	/// InspectorFeature (which does not link OpenUSD) can resolve stage
	/// metadata through this runtime.
	public static let live = SceneInspectorClient(
		stageMetadata: { url in
			DeconstructedShellRuntime.stageMetadata(url: url)
		}
	)
}
