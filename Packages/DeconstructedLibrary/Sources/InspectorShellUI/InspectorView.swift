import ComposableArchitecture
import InspectorFeature
import InspectorModels
import Sharing
import SwiftUI
import SwiftUsdShell
import simd

private func format(_ vector: SIMD3<Double>) -> String {
	String(format: "%.3g, %.3g, %.3g", vector.x, vector.y, vector.z)
}

private func updateTransform(
	_ transform: SwiftUsdShell.USDTransformData,
	position: SIMD3<Double>? = nil,
	rotationDegrees: SIMD3<Double>? = nil,
	scale: SIMD3<Double>? = nil
) -> SwiftUsdShell.USDTransformData {
	SwiftUsdShell.USDTransformData(
		position: position ?? transform.position,
		rotationDegrees: rotationDegrees ?? transform.rotationDegrees,
		orientation: transform.orientation,
		scale: scale ?? transform.scale
	)
}

private struct AddReferenceRow: View {
	let onAdd: (SwiftUsdShell.USDReference) -> Void
	@State private var assetPath: String = ""
	@State private var primPath: String = ""

	var body: some View {
		HStack {
			TextField("Asset path", text: $assetPath)
				.textFieldStyle(.roundedBorder)
			TextField("Prim path (optional)", text: $primPath)
				.textFieldStyle(.roundedBorder)
			Button("Add") {
				let reference = SwiftUsdShell.USDReference(
					assetPath: assetPath,
					primPath: primPath.isEmpty ? nil : primPath
				)
				onAdd(reference)
				assetPath = ""
				primPath = ""
			}
			.disabled(assetPath.isEmpty)
			.controlSize(.small)
		}
	}
}

private struct TransformVectorEditor: View {
	let label: String
	let vector: SIMD3<Double>
	let onChange: (SIMD3<Double>) -> Void

	var body: some View {
		LabeledContent(label) {
			HStack(spacing: 4) {
				axisField(value: vector.x) { onChange(SIMD3($0, vector.y, vector.z)) }
				axisField(value: vector.y) { onChange(SIMD3(vector.x, $0, vector.z)) }
				axisField(value: vector.z) { onChange(SIMD3(vector.x, vector.y, $0)) }
			}
		}
	}

	private func axisField(value: Double, set: @escaping (Double) -> Void) -> some View {
		TextField("", value: Binding(get: { value }, set: { set($0) }), format: .number.precision(.fractionLength(0...3)))
			.textFieldStyle(.roundedBorder)
			.frame(minWidth: 60)
	}
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
	@Shared(.inspectorDisclosureState) private var disclosureState

	public init(
		store: StoreOf<InspectorFeature>,
		onOpenAudioMixer: @escaping () -> Void = {}
	) {
		self.store = store
		self.onOpenAudioMixer = onOpenAudioMixer
	}

	private func disclosure(_ keyPath: WritableKeyPath<InspectorDisclosureState, Bool>) -> Binding<Bool> {
		Binding(
			get: { disclosureState[keyPath: keyPath] },
			set: { newValue in $disclosureState.withLock { $0[keyPath: keyPath] = newValue } }
		)
	}

	public var body: some View {
		ScrollView {
			content
				.padding()
		}
	}

	@ViewBuilder
	private var content: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Inspector")
				.font(.headline)

			if let selected = store.selectedNode {
				LabeledContent("Selection", value: selected.name)
				LabeledContent("Path", value: selected.path)

				if let summary = store.primSummary {
					DisclosureGroup(isExpanded: disclosure(\.primDataExpanded)) {
						LabeledContent("Type", value: summary.typeName?.rawValue ?? "—")
						LabeledContent("Active", value: summary.isActive ? "Yes" : "No")
						LabeledContent("Visibility", value: summary.visibility?.rawValue ?? "—")
						LabeledContent("Purpose", value: summary.purpose?.rawValue ?? "—")
						LabeledContent("Kind", value: summary.kind?.rawValue ?? "—")
					} label: {
						Text("Prim").font(.headline)
					}

					if !summary.attributes.isEmpty {
						DisclosureGroup(isExpanded: disclosure(\.primAttributesExpanded)) {
							ForEach(summary.attributes, id: \.name) { attribute in
								LabeledContent(
									attribute.name.rawValue,
									value: attribute.value?.displayDescription ?? "—"
								)
							}
						} label: {
							Text("Authored Attributes").font(.headline)
						}
					}
				}

				if let transform = store.primTransform {
					DisclosureGroup(isExpanded: disclosure(\.transformExpanded)) {
						TransformVectorEditor(label: "Position", vector: transform.position) { newValue in
							store.send(.primTransformEdited(updateTransform(transform, position: newValue)))
						}
						TransformVectorEditor(label: "Rotation (deg)", vector: transform.rotationDegrees) { newValue in
							store.send(.primTransformEdited(updateTransform(transform, rotationDegrees: newValue)))
						}
						TransformVectorEditor(label: "Scale", vector: transform.scale) { newValue in
							store.send(.primTransformEdited(updateTransform(transform, scale: newValue)))
						}
					} label: {
						Text("Transform").font(.headline)
					}
				}

				if let binding = store.materialBinding {
					DisclosureGroup(isExpanded: disclosure(\.materialBindingsExpanded)) {
						LabeledContent("Effective", value: binding.effectiveMaterialPath?.rawValue ?? "—")
						if let source = binding.bindingSourcePrimPath {
							LabeledContent("Inherited From", value: source.rawValue)
						}

						let authoredPath = binding.authoredMaterialPath?.rawValue
						Picker(
							"Authored Material",
							selection: Binding(
								get: { authoredPath ?? "" },
								set: { newValue in
									store.send(.setMaterialBindingRequested(materialPath: newValue.isEmpty ? nil : newValue))
								}
							)
						) {
							Text("None").tag("")
							ForEach(store.availableMaterials) { material in
								Text(material.name).tag(material.path.rawValue)
							}
						}

						Picker(
							"Strength",
							selection: Binding(
								get: { binding.bindingStrength ?? .fallbackStrength },
								set: { store.send(.setMaterialBindingStrengthRequested($0)) }
							)
						) {
							ForEach(SwiftUsdShell.USDMaterialBindingStrength.allCases, id: \.self) { strength in
								Text(strength.displayName).tag(strength)
							}
						}
					} label: {
						Text("Material Binding").font(.headline)
					}

					if !store.materialProperties.isEmpty {
						DisclosureGroup(isExpanded: disclosure(\.materialPropertiesExpanded)) {
							ForEach(store.materialProperties, id: \.name) { property in
								LabeledContent(property.name, value: describe(property.value))
							}
						} label: {
							Text("Material Properties").font(.headline)
						}
					}
				}

				DisclosureGroup(isExpanded: disclosure(\.referencesExpanded)) {
					if store.primReferences.isEmpty {
						Text("No authored references")
							.foregroundStyle(.secondary)
					} else {
						ForEach(store.primReferences, id: \.self) { reference in
							HStack {
								VStack(alignment: .leading) {
									Text(reference.assetPath)
									if let primPath = reference.primPath {
										Text(primPath).font(.caption).foregroundStyle(.secondary)
									}
								}
								Spacer()
								Button("Remove", role: .destructive) {
									store.send(.removeReferenceRequested(reference))
								}
								.controlSize(.small)
							}
						}
					}
					AddReferenceRow { reference in
						store.send(.addReferenceRequested(reference))
					}
				} label: {
					Text("References").font(.headline)
				}

				if !store.primVariantSets.isEmpty {
					DisclosureGroup(isExpanded: disclosure(\.variantsExpanded)) {
						ForEach(store.primVariantSets) { variantSet in
							Picker(
								variantSet.name.rawValue,
								selection: Binding(
									get: { variantSet.selection?.rawValue ?? "" },
									set: { newValue in
										store.send(.setVariantSelectionRequested(
											setName: variantSet.name.rawValue,
											selectionId: newValue.isEmpty ? nil : newValue
										))
									}
								)
							) {
								Text("None").tag("")
								ForEach(variantSet.choices, id: \.rawValue) { choice in
									Text(choice.rawValue).tag(choice.rawValue)
								}
							}
						}
					} label: {
						Text("Variants").font(.headline)
					}
				}

				if !store.primCompositionArcs.isEmpty {
					DisclosureGroup(isExpanded: disclosure(\.compositionExpanded)) {
						ForEach(Array(store.primCompositionArcs.enumerated()), id: \.offset) { _, arc in
							LabeledContent(
								arc.kind.rawValue.capitalized,
								value: arc.assetPath?.rawValue ?? arc.primPath?.rawValue ?? "—"
							)
						}
					} label: {
						Text("Composition").font(.headline)
					}
				}

				if !store.primComponents.isEmpty {
					DisclosureGroup(isExpanded: disclosure(\.componentsExpanded)) {
						ForEach(store.primComponents) { component in
							DisclosureGroup {
								LabeledContent("Type", value: component.typeName)
								Toggle(
									"Active",
									isOn: Binding(
										get: { component.isActive },
										set: { store.send(.setComponentActiveRequested(componentPath: component.path, isActive: $0)) }
									)
								)
								LabeledContent("Path", value: component.path)
								ForEach(component.authoredAttributes) { attribute in
									LabeledContent(attribute.name, value: attribute.value)
								}
								Button("Delete Component", role: .destructive) {
									store.send(.deleteComponentRequested(componentPath: component.path))
								}
							} label: {
								LabeledContent(component.name, value: component.typeName)
							}
						}
					} label: {
						Text("Components").font(.headline)
					}
				}

				let audioMixComponents = store.primComponents.filter { $0.typeName == "RealityKit.AudioMixGroups" }
				if !audioMixComponents.isEmpty {
					DisclosureGroup(isExpanded: disclosure(\.audioMixGroupsExpanded)) {
						ForEach(audioMixComponents) { component in
							LabeledContent(component.name, value: component.path)
						}
					} label: {
						Text("Audio Mix Groups").font(.headline)
					}
				}
			} else {
				Text("No selection")
					.foregroundStyle(.secondary)

				if let layer = store.layerData {
					DisclosureGroup(isExpanded: disclosure(\.layerDataExpanded)) {
						LabeledContent("Up Axis", value: layer.upAxis.rawValue)
						LabeledContent("Meters Per Unit", value: String(format: "%g", layer.metersPerUnit))
						LabeledContent("Default Prim", value: layer.defaultPrim ?? "—")
					} label: {
						Text("Stage").font(.headline)
					}
				}

				if !store.availableMaterials.isEmpty {
					DisclosureGroup(isExpanded: disclosure(\.materialsExpanded)) {
						ForEach(store.availableMaterials) { material in
							LabeledContent(material.name, value: material.path.rawValue)
						}
					} label: {
						Text("Materials").font(.headline)
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
		.frame(maxWidth: .infinity, alignment: .leading)
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
