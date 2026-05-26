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
		},
		primTransform: { url, primPath in
			DeconstructedShellRuntime.primTransform(url: url, primPath: primPath)
		},
		materialBinding: { url, primPath in
			DeconstructedShellRuntime.materialBinding(url: url, primPath: primPath)
		},
		primReferences: { url, primPath in
			DeconstructedShellRuntime.primReferences(url: url, primPath: primPath)
		},
		primVariantSets: { url, primPath in
			DeconstructedShellRuntime.primVariantSets(url: url, primPath: primPath)
		},
		primSummary: { url, primPath in
			DeconstructedShellRuntime.primSummary(url: url, primPath: primPath)
		},
		allMaterials: { url in
			DeconstructedShellRuntime.allMaterials(url: url)
		},
		materialProperties: { url, materialPath in
			DeconstructedShellRuntime.materialProperties(url: url, materialPath: materialPath)
		},
		primCompositionArcs: { url, primPath in
			DeconstructedShellRuntime.primCompositionArcs(url: url, primPath: primPath)
		},
		primComponents: { url, primPath in
			DeconstructedShellRuntime.primComponents(url: url, primPath: primPath)
		}
	)
}
