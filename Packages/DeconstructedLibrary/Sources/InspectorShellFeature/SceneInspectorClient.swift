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
	public var setPrimTransform: @Sendable (_ url: URL, _ primPath: String, _ transform: SwiftUsdShell.USDTransformData) async throws -> Void
	public var setMaterialBinding: @Sendable (_ url: URL, _ primPath: String, _ materialPath: String?) async throws -> Void
	public var setMaterialBindingStrength: @Sendable (_ url: URL, _ primPath: String, _ strength: SwiftUsdShell.USDMaterialBindingStrength) async throws -> Void
	public var setPrimVariantSelection: @Sendable (_ url: URL, _ primPath: String, _ setName: String, _ selectionId: String?) async throws -> Void
	public var setComponentActive: @Sendable (_ url: URL, _ componentPath: String, _ isActive: Bool) async throws -> Void
	public var deleteComponent: @Sendable (_ url: URL, _ componentPath: String) async throws -> Void
	public var addPrimReference: @Sendable (_ url: URL, _ primPath: String, _ reference: SwiftUsdShell.USDReference) async throws -> Void
	public var removePrimReference: @Sendable (_ url: URL, _ primPath: String, _ reference: SwiftUsdShell.USDReference) async throws -> Void
	public var setDefaultPrim: @Sendable (_ url: URL, _ primPath: String) async throws -> Void
	public var setMetersPerUnit: @Sendable (_ url: URL, _ value: Double) async throws -> Void
	public var setUpAxis: @Sendable (_ url: URL, _ axis: String) async throws -> Void

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
		},
		setPrimTransform: @escaping @Sendable (_ url: URL, _ primPath: String, _ transform: SwiftUsdShell.USDTransformData) async throws -> Void = { _, _, _ in },
		setMaterialBinding: @escaping @Sendable (_ url: URL, _ primPath: String, _ materialPath: String?) async throws -> Void = { _, _, _ in },
		setMaterialBindingStrength: @escaping @Sendable (_ url: URL, _ primPath: String, _ strength: SwiftUsdShell.USDMaterialBindingStrength) async throws -> Void = { _, _, _ in },
		setPrimVariantSelection: @escaping @Sendable (_ url: URL, _ primPath: String, _ setName: String, _ selectionId: String?) async throws -> Void = { _, _, _, _ in },
		setComponentActive: @escaping @Sendable (_ url: URL, _ componentPath: String, _ isActive: Bool) async throws -> Void = { _, _, _ in },
		deleteComponent: @escaping @Sendable (_ url: URL, _ componentPath: String) async throws -> Void = { _, _ in },
		addPrimReference: @escaping @Sendable (_ url: URL, _ primPath: String, _ reference: SwiftUsdShell.USDReference) async throws -> Void = { _, _, _ in },
		removePrimReference: @escaping @Sendable (_ url: URL, _ primPath: String, _ reference: SwiftUsdShell.USDReference) async throws -> Void = { _, _, _ in },
		setDefaultPrim: @escaping @Sendable (_ url: URL, _ primPath: String) async throws -> Void = { _, _ in },
		setMetersPerUnit: @escaping @Sendable (_ url: URL, _ value: Double) async throws -> Void = { _, _ in },
		setUpAxis: @escaping @Sendable (_ url: URL, _ axis: String) async throws -> Void = { _, _ in }
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
		self.setPrimTransform = setPrimTransform
		self.setMaterialBinding = setMaterialBinding
		self.setMaterialBindingStrength = setMaterialBindingStrength
		self.setPrimVariantSelection = setPrimVariantSelection
		self.setComponentActive = setComponentActive
		self.deleteComponent = deleteComponent
		self.addPrimReference = addPrimReference
		self.removePrimReference = removePrimReference
		self.setDefaultPrim = setDefaultPrim
		self.setMetersPerUnit = setMetersPerUnit
		self.setUpAxis = setUpAxis
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
