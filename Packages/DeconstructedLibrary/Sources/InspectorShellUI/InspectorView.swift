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

private struct ComponentEditorRow: View {
	let component: InspectorComponentSummary
	let onParameterChange: (_ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void
	let onActiveToggle: (Bool) -> Void
	let onDelete: () -> Void

	private var componentIdentifier: String? {
		component.authoredAttributes
			.first { $0.name == "info:id" }
			.map { stripUSDQuotes($0.value) }
	}

	private var definition: InspectorComponentDefinition? {
		guard let id = componentIdentifier else { return nil }
		return InspectorComponentCatalog.definition(forIdentifier: id)
	}

	var body: some View {
		DisclosureGroup {
			LabeledContent("Type", value: component.typeName)
			Toggle(
				"Active",
				isOn: Binding(get: { component.isActive }, set: onActiveToggle)
			)

			if let definition {
				ForEach(definition.parameterLayout) { parameter in
					ComponentParameterEditor(
						parameter: parameter,
						currentValue: lookup(parameter.key),
						onChange: { attributeType, valueLiteral in
							onParameterChange(attributeType, parameter.key, valueLiteral)
						}
					)
				}
			} else {
				ForEach(component.authoredAttributes) { attribute in
					LabeledContent(attribute.name, value: attribute.value)
				}
			}

			Button("Delete Component", role: .destructive, action: onDelete)
		} label: {
			LabeledContent(component.name, value: definition?.name ?? component.typeName)
		}
	}

	private func lookup(_ key: String) -> String? {
		component.authoredAttributes.first { $0.name == key }?.value
	}
}

private struct ComponentParameterEditor: View {
	let parameter: InspectorComponentParameter
	let currentValue: String?
	let onChange: (_ attributeType: String, _ valueLiteral: String) -> Void

	var body: some View {
		switch parameter.kind {
		case .toggle(let defaultValue):
			let bool = currentValue.flatMap(parseBool) ?? defaultValue
			Toggle(
				parameter.label,
				isOn: Binding(
					get: { bool },
					set: { onChange("bool", $0 ? "true" : "false") }
				)
			)

		case .text(let defaultValue, let placeholder):
			let text = currentValue.map(stripUSDQuotes) ?? defaultValue
			LabeledContent(parameter.label) {
				TextField(placeholder, text: Binding(
					get: { text },
					set: { onChange("string", quoteUSDString($0)) }
				))
				.textFieldStyle(.roundedBorder)
			}

		case .scalar(let defaultValue, let unit):
			let value = currentValue.flatMap(Double.init) ?? defaultValue
			LabeledContent(unit.map { "\(parameter.label) (\($0))" } ?? parameter.label) {
				TextField("", value: Binding(
					get: { value },
					set: { onChange("double", String($0)) }
				), format: .number.precision(.fractionLength(0...4)))
				.textFieldStyle(.roundedBorder)
				.frame(minWidth: 80)
			}

		case .choice(let defaultValue, let options):
			let selection = currentValue.map(stripUSDQuotes) ?? defaultValue
			Picker(parameter.label, selection: Binding(
				get: { selection },
				set: { onChange("token", quoteUSDString($0)) }
			)) {
				ForEach(options, id: \.self) { option in
					Text(option).tag(option)
				}
			}
		}
	}
}

private struct AddComponentRow: View {
	let onAdd: (_ name: String, _ identifier: String) -> Void
	@State private var selection: String = ""

	private var enabled: [InspectorComponentDefinition] {
		InspectorComponentCatalog.all.filter { $0.isEnabledForAuthoring }
	}

	var body: some View {
		HStack {
			Picker("Add Component", selection: $selection) {
				Text("Choose…").tag("")
				ForEach(enabled) { definition in
					Text(definition.name).tag(definition.identifier)
				}
			}
			Button("Add") {
				guard let definition = enabled.first(where: { $0.identifier == selection }) else { return }
				onAdd(definition.authoredPrimName, definition.identifier)
				selection = ""
			}
			.disabled(selection.isEmpty)
			.controlSize(.small)
		}
	}
}

private func stripUSDQuotes(_ value: String) -> String {
	var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
		trimmed = String(trimmed.dropFirst().dropLast())
	}
	return trimmed
}

private func quoteUSDString(_ value: String) -> String {
	let escaped = value
		.replacingOccurrences(of: "\\", with: "\\\\")
		.replacingOccurrences(of: "\"", with: "\\\"")
	return "\"\(escaped)\""
}

private func parseBool(_ value: String) -> Bool? {
	let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	switch lower {
	case "true", "1": return true
	case "false", "0": return false
	default: return nil
	}
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
							ComponentEditorRow(
								component: component,
								onParameterChange: { attributeType, attributeName, valueLiteral in
									store.send(.setComponentParameterRequested(
										componentPath: component.path,
										attributeType: attributeType,
										attributeName: attributeName,
										valueLiteral: valueLiteral
									))
								},
								onActiveToggle: { isActive in
									store.send(.setComponentActiveRequested(componentPath: component.path, isActive: isActive))
								},
								onDelete: {
									store.send(.deleteComponentRequested(componentPath: component.path))
								}
							)
						}
						AddComponentRow { name, identifier in
							store.send(.addComponentRequested(componentName: name, componentIdentifier: identifier))
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
						Picker(
							"Up Axis",
							selection: Binding(
								get: { layer.upAxis.rawValue },
								set: { store.send(.setUpAxisRequested($0)) }
							)
						) {
							Text("Y").tag("Y")
							Text("Z").tag("Z")
						}

						LabeledContent("Meters Per Unit") {
							TextField(
								"",
								value: Binding(
									get: { layer.metersPerUnit },
									set: { store.send(.setMetersPerUnitRequested($0)) }
								),
								format: .number.precision(.fractionLength(0...4))
							)
							.textFieldStyle(.roundedBorder)
							.frame(minWidth: 80)
						}

						Picker(
							"Default Prim",
							selection: Binding(
								get: { layer.defaultPrim ?? "" },
								set: { newValue in
									if !newValue.isEmpty {
										store.send(.setDefaultPrimRequested(newValue))
									}
								}
							)
						) {
							if layer.defaultPrim == nil {
								Text("—").tag("")
							}
							ForEach(layer.availablePrims, id: \.self) { prim in
								Text(prim).tag(prim)
							}
						}
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
