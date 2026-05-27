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
		},
		setPrimTransform: { url, primPath, transform in
			try DeconstructedShellRuntime.setPrimTransform(url: url, primPath: primPath, transform: transform)
		},
		setMaterialBinding: { url, primPath, materialPath in
			try DeconstructedShellRuntime.setMaterialBinding(url: url, primPath: primPath, materialPath: materialPath)
		},
		setMaterialBindingStrength: { url, primPath, strength in
			try DeconstructedShellRuntime.setMaterialBindingStrength(url: url, primPath: primPath, strength: strength)
		},
		setPrimVariantSelection: { url, primPath, setName, selectionId in
			try DeconstructedShellRuntime.setPrimVariantSelection(
				url: url, primPath: primPath, setName: setName, selectionId: selectionId
			)
		},
		setComponentActive: { url, componentPath, isActive in
			try DeconstructedShellRuntime.setComponentActive(
				url: url, componentPath: componentPath, isActive: isActive
			)
		},
		deleteComponent: { url, componentPath in
			try DeconstructedShellRuntime.deleteComponent(url: url, componentPath: componentPath)
		},
		addPrimReference: { url, primPath, reference in
			try DeconstructedShellRuntime.addPrimReference(url: url, primPath: primPath, reference: reference)
		},
		removePrimReference: { url, primPath, reference in
			try DeconstructedShellRuntime.removePrimReference(url: url, primPath: primPath, reference: reference)
		},
		setDefaultPrim: { url, primPath in
			try DeconstructedShellRuntime.setDefaultPrim(url: url, primPath: primPath)
		},
		setMetersPerUnit: { url, value in
			try DeconstructedShellRuntime.setMetersPerUnit(url: url, value: value)
		},
		setUpAxis: { url, axis in
			try DeconstructedShellRuntime.setUpAxis(url: url, axis: axis)
		},
		setComponentParameter: { url, componentPath, attributeType, attributeName, valueLiteral in
			try DeconstructedShellRuntime.setComponentParameter(
				url: url,
				componentPath: componentPath,
				attributeType: attributeType,
				attributeName: attributeName,
				valueLiteral: valueLiteral
			)
		},
		addComponent: { url, primPath, componentName, componentIdentifier in
			try DeconstructedShellRuntime.addComponent(
				url: url,
				primPath: primPath,
				componentName: componentName,
				componentIdentifier: componentIdentifier
			)
		},
		meshSortingGroupMembers: { url, groupPrimPath, candidatePrimPaths in
			DeconstructedShellRuntime.meshSortingGroupMembers(
				url: url,
				groupPrimPath: groupPrimPath,
				candidatePrimPaths: candidatePrimPaths
			)
		},
		addBehavior: { url, behaviorsContainerPath, triggerType in
			try DeconstructedShellRuntime.addBehavior(
				url: url,
				behaviorsContainerPrimPath: behaviorsContainerPath,
				triggerType: triggerType
			)
		},
		removeBehavior: { url, behaviorsContainerPath, behaviorPath in
			try DeconstructedShellRuntime.removeBehavior(
				url: url,
				behaviorsContainerPrimPath: behaviorsContainerPath,
				behaviorPrimPath: behaviorPath
			)
		},
		addAudioMixGroup: { url, componentPath, existing in
			try DeconstructedShellRuntime.addAudioMixGroup(
				url: url,
				componentPath: componentPath,
				existingMixGroupPaths: existing
			)
		},
		assignAudioMixGroupResource: { url, componentPath, mixGroupPath, sourceURL, existing, rootPrimPath in
			try DeconstructedShellRuntime.assignAudioMixGroupResource(
				url: url,
				componentPath: componentPath,
				mixGroupPath: mixGroupPath,
				sourceURL: sourceURL,
				existingAudioFilePaths: existing,
				rootPrimPath: rootPrimPath
			)
		},
		addAnimationLibraryResource: { url, componentPath, sourceURL, existing in
			try DeconstructedShellRuntime.addAnimationLibraryResource(
				url: url,
				componentPath: componentPath,
				sourceURL: sourceURL,
				existingResourcePaths: existing
			)
		},
		removeAnimationLibraryResource: { url, resourcePrimPath in
			try DeconstructedShellRuntime.removeAnimationLibraryResource(
				url: url,
				resourcePrimPath: resourcePrimPath
			)
		}
	)
}
