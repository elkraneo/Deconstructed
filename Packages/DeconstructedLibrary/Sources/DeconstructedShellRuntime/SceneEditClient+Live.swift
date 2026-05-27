import DeconstructedModels
import DeconstructedUSDInterop
import Foundation
import SceneGraphClients

extension SceneEditClient {
	/// The OpenUSD-backed implementation. Install at app startup via
	/// `prepareDependencies { $0.sceneEditClient = .live }` so that
	/// SceneGraphFeature (which does not link OpenUSD) can author new prims
	/// through this runtime. The default `liveValue` throws `runtimeUnavailable`
	/// and is what users hit when they try to "Add Cube" without this override.
	public static let live = SceneEditClient(
		createPrimitive: { url, parentPath, primitiveType, name in
			try DeconstructedUSDInterop.createPrimitive(
				url: url,
				parentPath: parentPath,
				primitiveType: primitiveType,
				name: name
			)
		},
		createStructural: { url, parentPath, structuralType, name in
			try DeconstructedUSDInterop.createStructural(
				url: url,
				parentPath: parentPath,
				structuralType: structuralType,
				name: name
			)
		}
	)
}
