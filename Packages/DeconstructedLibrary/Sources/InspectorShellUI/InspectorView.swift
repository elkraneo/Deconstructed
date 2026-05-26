import ComposableArchitecture
import InspectorFeature
import SwiftUI
import SwiftUsdShell
import simd

private func format(_ vector: SIMD3<Double>) -> String {
	String(format: "%.3g, %.3g, %.3g", vector.x, vector.y, vector.z)
}

private func describe(_ value: SwiftUsdShell.USDMaterialPropertyInfo) -> String {
	switch value {
	case .bool(let v): return v ? "true" : "false"
	case .color(let r, let g, let b): return String(format: "%.3g, %.3g, %.3g", r, g, b)
	case .float(let v): return String(format: "%g", v)
	case .int(let v): return String(v)
	case .string(let v): return v
	case .texture(let url, let resolved): return resolved ?? url
	case .token(let v): return v
	case .unsupported(_, let description): return description
	}
}

public struct AudioMixerComponentEntry: Identifiable, Equatable, Sendable {
	public var id: String { componentPath }
	public let componentPath: String
	public let displayName: String
	public let descendantAttributes: [ComponentDescendantAttributes]

	public init(
		componentPath: String,
		displayName: String,
		descendantAttributes: [ComponentDescendantAttributes] = []
	) {
		self.componentPath = componentPath
		self.displayName = displayName
		self.descendantAttributes = descendantAttributes
	}
}

public struct InspectorView: View {
	private let store: StoreOf<InspectorFeature>
	private let onOpenAudioMixer: () -> Void

	public init(
		store: StoreOf<InspectorFeature>,
		onOpenAudioMixer: @escaping () -> Void = {}
	) {
		self.store = store
		self.onOpenAudioMixer = onOpenAudioMixer
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Inspector")
				.font(.headline)

			if let selected = store.selectedNode {
				LabeledContent("Selection", value: selected.name)
				LabeledContent("Path", value: selected.path)

				if let summary = store.primSummary {
					Section("Prim") {
						LabeledContent("Type", value: summary.typeName?.rawValue ?? "—")
						LabeledContent("Active", value: summary.isActive ? "Yes" : "No")
						LabeledContent("Visibility", value: summary.visibility?.rawValue ?? "—")
						LabeledContent("Purpose", value: summary.purpose?.rawValue ?? "—")
						LabeledContent("Kind", value: summary.kind?.rawValue ?? "—")
					}

					if !summary.attributes.isEmpty {
						Section("Authored Attributes") {
							ForEach(summary.attributes, id: \.name) { attribute in
								LabeledContent(
									attribute.name.rawValue,
									value: attribute.value?.displayDescription ?? "—"
								)
							}
						}
					}
				}

				if let transform = store.primTransform {
					Section("Transform") {
						LabeledContent("Position", value: format(transform.position))
						LabeledContent("Rotation (deg)", value: format(transform.rotationDegrees))
						LabeledContent("Scale", value: format(transform.scale))
					}
				}

				if let binding = store.materialBinding {
					Section("Material Binding") {
						LabeledContent("Effective", value: binding.effectiveMaterialPath?.rawValue ?? "—")
						LabeledContent("Authored", value: binding.authoredMaterialPath?.rawValue ?? "—")
						if let source = binding.bindingSourcePrimPath {
							LabeledContent("Inherited From", value: source.rawValue)
						}
						if let strength = binding.bindingStrength {
							LabeledContent("Strength", value: strength.displayName)
						}
					}

					if !store.materialProperties.isEmpty {
						Section("Material Properties") {
							ForEach(store.materialProperties, id: \.name) { property in
								LabeledContent(property.name, value: describe(property.value))
							}
						}
					}
				}

				if !store.primReferences.isEmpty {
					Section("References") {
						ForEach(store.primReferences, id: \.self) { reference in
							LabeledContent(reference.assetPath, value: reference.primPath ?? "—")
						}
					}
				}

				if !store.primVariantSets.isEmpty {
					Section("Variants") {
						ForEach(store.primVariantSets) { variantSet in
							LabeledContent(
								variantSet.name.rawValue,
								value: variantSet.selection?.rawValue ?? "—"
							)
						}
					}
				}

				if !store.primCompositionArcs.isEmpty {
					Section("Composition") {
						ForEach(Array(store.primCompositionArcs.enumerated()), id: \.offset) { _, arc in
							LabeledContent(
								arc.kind.rawValue.capitalized,
								value: arc.assetPath?.rawValue ?? arc.primPath?.rawValue ?? "—"
							)
						}
					}
				}

				if !store.primComponents.isEmpty {
					Section("Components") {
						ForEach(store.primComponents) { component in
							DisclosureGroup {
								LabeledContent("Type", value: component.typeName)
								LabeledContent("Active", value: component.isActive ? "Yes" : "No")
								LabeledContent("Path", value: component.path)
								ForEach(component.authoredAttributes) { attribute in
									LabeledContent(attribute.name, value: attribute.value)
								}
							} label: {
								LabeledContent(component.name, value: component.typeName)
							}
						}
					}
				}

				let audioMixComponents = store.primComponents.filter { $0.typeName == "RealityKit.AudioMixGroups" }
				if !audioMixComponents.isEmpty {
					Section("Audio Mix Groups") {
						ForEach(audioMixComponents) { component in
							LabeledContent(component.name, value: component.path)
						}
					}
				}
			} else {
				Text("No selection")
					.foregroundStyle(.secondary)

				if let layer = store.layerData {
					Section("Stage") {
						LabeledContent("Up Axis", value: layer.upAxis.rawValue)
						LabeledContent("Meters Per Unit", value: String(format: "%g", layer.metersPerUnit))
						LabeledContent("Default Prim", value: layer.defaultPrim ?? "—")
					}
				}

				if !store.availableMaterials.isEmpty {
					Section("Materials") {
						ForEach(store.availableMaterials) { material in
							LabeledContent(material.name, value: material.path.rawValue)
						}
					}
				}
			}

			if let errorMessage = store.errorMessage {
				Text(errorMessage)
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)
		}
		.padding()
	}
}

public struct AudioMixerPanel: View {
	private let components: [AudioMixerComponentEntry]
	private let onAddMixGroup: (String) -> Void
	private let onAssignAudio: (String, String, URL) -> Void
	private let onRawAttributeChanged: (String, String, String, String, String) -> Void

	public init(
		components: [AudioMixerComponentEntry],
		onAddMixGroup: @escaping (String) -> Void,
		onAssignAudio: @escaping (String, String, URL) -> Void,
		onRawAttributeChanged: @escaping (String, String, String, String, String) -> Void
	) {
		self.components = components
		self.onAddMixGroup = onAddMixGroup
		self.onAssignAudio = onAssignAudio
		self.onRawAttributeChanged = onRawAttributeChanged
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Audio Mixer")
				.font(.headline)

			if components.isEmpty {
				Text("No audio mix groups in the current shell-backed inspector.")
					.foregroundStyle(.secondary)
			} else {
				List(components) { component in
					Text(component.displayName)
				}
			}
		}
		.padding()
	}
}

public struct AudioMixGroupsEditor: View {
	private let componentPath: String
	private let descendantAttributes: [ComponentDescendantAttributes]
	private let onAddMixGroup: (String) -> Void
	private let onAssignAudioMixGroupResource: (String, String, URL) -> Void
	private let onRawAttributeChanged: (String, String, String, String, String) -> Void

	public init(
		componentPath: String,
		descendantAttributes: [ComponentDescendantAttributes],
		onAddMixGroup: @escaping (String) -> Void,
		onAssignAudioMixGroupResource: @escaping (String, String, URL) -> Void,
		onRawAttributeChanged: @escaping (String, String, String, String, String) -> Void
	) {
		self.componentPath = componentPath
		self.descendantAttributes = descendantAttributes
		self.onAddMixGroup = onAddMixGroup
		self.onAssignAudioMixGroupResource = onAssignAudioMixGroupResource
		self.onRawAttributeChanged = onRawAttributeChanged
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if descendantAttributes.isEmpty {
				Text("Audio mix group editing requires the SwiftUsdShell runtime adapter.")
					.foregroundStyle(.secondary)
			} else {
				ForEach(descendantAttributes) { descendant in
					LabeledContent(descendant.name, value: descendant.path)
				}
			}

			Button("Add Mix Group") {
				onAddMixGroup(componentPath)
			}
		}
	}
}
