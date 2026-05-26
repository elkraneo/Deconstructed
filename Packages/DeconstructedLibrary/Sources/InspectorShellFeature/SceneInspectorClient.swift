import ComposableArchitecture
import Foundation
import SwiftUsdShell

/// Loads stage-level metadata for the inspector without forcing app/feature
/// targets to depend on `USDOperations`/`USDInterfaces`/`OpenUSD`.
///
/// The OpenUSD-backed implementation is installed by
/// `DeconstructedShellRuntime` via `SceneInspectorClient.live`. Until that
/// override is installed, the default `liveValue` returns empty metadata so
/// the feature still compiles and behaves safely.
public struct SceneInspectorClient: Sendable {
	public var stageMetadata: @Sendable (_ url: URL) async -> SwiftUsdShell.USDStageMetadata

	public init(
		stageMetadata: @escaping @Sendable (_ url: URL) async -> SwiftUsdShell.USDStageMetadata = { _ in
			SwiftUsdShell.USDStageMetadata()
		}
	) {
		self.stageMetadata = stageMetadata
	}
}

extension SceneInspectorClient: DependencyKey {
	/// Default live value. The shell runtime installs the OpenUSD-backed
	/// implementation at app startup; see `DeconstructedShellRuntime`.
	public static let liveValue: SceneInspectorClient = SceneInspectorClient(
		stageMetadata: { _ in
			SwiftUsdShell.USDStageMetadata()
		}
	)

	public static let previewValue: SceneInspectorClient = SceneInspectorClient(
		stageMetadata: { _ in
			SwiftUsdShell.USDStageMetadata(
				upAxis: SwiftUsdShell.USDToken("Y"),
				metersPerUnit: 1,
				defaultPrimName: SwiftUsdShell.USDToken("Root")
			)
		}
	)
}

extension DependencyValues {
	public var sceneInspector: SceneInspectorClient {
		get { self[SceneInspectorClient.self] }
		set { self[SceneInspectorClient.self] = newValue }
	}
}
