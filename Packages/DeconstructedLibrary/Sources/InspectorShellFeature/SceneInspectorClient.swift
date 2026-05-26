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
	public var primTransform: @Sendable (_ url: URL, _ primPath: String) async -> SwiftUsdShell.USDTransformData?
	public var materialBinding: @Sendable (_ url: URL, _ primPath: String) async -> SwiftUsdShell.USDMaterialBindingInfo?
	public var primReferences: @Sendable (_ url: URL, _ primPath: String) async -> [SwiftUsdShell.USDReference]
	public var primVariantSets: @Sendable (_ url: URL, _ primPath: String) async -> [SwiftUsdShell.USDVariantSetSummary]
	public var primSummary: @Sendable (_ url: URL, _ primPath: String) async -> SwiftUsdShell.USDPrimSummary?
	public var allMaterials: @Sendable (_ url: URL) async -> [SwiftUsdShell.USDMaterialSummary]
	public var materialProperties: @Sendable (_ url: URL, _ materialPath: String) async -> [SwiftUsdShell.USDMaterialPropertySummary]
	public var primCompositionArcs: @Sendable (_ url: URL, _ primPath: String) async -> [SwiftUsdShell.USDCompositionArcSummary]
	public var primComponents: @Sendable (_ url: URL, _ primPath: String) async -> [InspectorComponentSummary]

	public init(
		stageMetadata: @escaping @Sendable (_ url: URL) async -> SwiftUsdShell.USDStageMetadata = { _ in
			SwiftUsdShell.USDStageMetadata()
		},
		primTransform: @escaping @Sendable (_ url: URL, _ primPath: String) async -> SwiftUsdShell.USDTransformData? = { _, _ in
			nil
		},
		materialBinding: @escaping @Sendable (_ url: URL, _ primPath: String) async -> SwiftUsdShell.USDMaterialBindingInfo? = { _, _ in
			nil
		},
		primReferences: @escaping @Sendable (_ url: URL, _ primPath: String) async -> [SwiftUsdShell.USDReference] = { _, _ in
			[]
		},
		primVariantSets: @escaping @Sendable (_ url: URL, _ primPath: String) async -> [SwiftUsdShell.USDVariantSetSummary] = { _, _ in
			[]
		},
		primSummary: @escaping @Sendable (_ url: URL, _ primPath: String) async -> SwiftUsdShell.USDPrimSummary? = { _, _ in
			nil
		},
		allMaterials: @escaping @Sendable (_ url: URL) async -> [SwiftUsdShell.USDMaterialSummary] = { _ in
			[]
		},
		materialProperties: @escaping @Sendable (_ url: URL, _ materialPath: String) async -> [SwiftUsdShell.USDMaterialPropertySummary] = { _, _ in
			[]
		},
		primCompositionArcs: @escaping @Sendable (_ url: URL, _ primPath: String) async -> [SwiftUsdShell.USDCompositionArcSummary] = { _, _ in
			[]
		},
		primComponents: @escaping @Sendable (_ url: URL, _ primPath: String) async -> [InspectorComponentSummary] = { _, _ in
			[]
		}
	) {
		self.stageMetadata = stageMetadata
		self.primTransform = primTransform
		self.materialBinding = materialBinding
		self.primReferences = primReferences
		self.primVariantSets = primVariantSets
		self.primSummary = primSummary
		self.allMaterials = allMaterials
		self.materialProperties = materialProperties
		self.primCompositionArcs = primCompositionArcs
		self.primComponents = primComponents
	}
}

extension SceneInspectorClient: DependencyKey {
	/// Default live value. The shell runtime installs the OpenUSD-backed
	/// implementation at app startup; see `DeconstructedShellRuntime`.
	public static let liveValue: SceneInspectorClient = SceneInspectorClient()

	public static let previewValue: SceneInspectorClient = SceneInspectorClient(
		stageMetadata: { _ in
			SwiftUsdShell.USDStageMetadata(
				upAxis: SwiftUsdShell.USDToken("Y"),
				metersPerUnit: 1,
				defaultPrimName: SwiftUsdShell.USDToken("Root")
			)
		},
		primTransform: { _, _ in
			SwiftUsdShell.USDTransformData()
		}
	)
}

extension DependencyValues {
	public var sceneInspector: SceneInspectorClient {
		get { self[SceneInspectorClient.self] }
		set { self[SceneInspectorClient.self] = newValue }
	}
}
