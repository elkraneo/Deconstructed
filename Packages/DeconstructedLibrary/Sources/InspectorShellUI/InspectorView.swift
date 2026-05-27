import AppKit
import ComposableArchitecture
import InspectorFeature
import InspectorModels
import Sharing
import SwiftUI
import SwiftUsdShell
import UniformTypeIdentifiers
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
	let onPaste: (String) -> Void

	private var componentIdentifier: String? {
		component.authoredAttributes
			.first { $0.name == "info:id" }
			.map { stripUSDQuotes($0.value) }
	}

	private var definition: InspectorComponentDefinition? {
		guard let id = componentIdentifier else { return nil }
		return InspectorComponentCatalog.definition(forIdentifier: id)
	}

	private var nonLayoutAttributes: [InspectorAuthoredAttribute] {
		let layoutKeys: Set<String> = Set((definition?.parameterLayout ?? []).map(\.key))
		return component.authoredAttributes.filter { attribute in
			!layoutKeys.contains(attribute.name) && attribute.name != "info:id"
		}
	}

	var body: some View {
		DisclosureGroup {
			HStack {
				Spacer()
				Menu {
					Button("Copy Component") { copyComponentPayload() }
					Button("Copy Component Name") { copyComponentName() }
					Button("Paste Component") {
						guard let identifier = copiedComponentIdentifierFromPasteboard() else { return }
						onPaste(identifier)
					}
					.disabled(copiedComponentIdentifierFromPasteboard() == nil)
					Divider()
					Button(component.isActive ? "Deactivate" : "Activate") {
						onActiveToggle(!component.isActive)
					}
					Divider()
					Button("Remove Overrides") {}
						.disabled(true)
					Divider()
					Button("Delete", role: .destructive, action: onDelete)
				} label: {
					Image(systemName: "ellipsis")
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(.secondary)
						.frame(width: 20, height: 20)
				}
				.menuStyle(.borderlessButton)
				.fixedSize()
			}

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
			}

			ForEach(nonLayoutAttributes) { attribute in
				GenericAttributeEditor(
					attribute: attribute,
					onChange: { attributeType, valueLiteral in
						onParameterChange(attributeType, attribute.name, valueLiteral)
					}
				)
			}
		} label: {
			LabeledContent(component.name, value: definition?.name ?? component.typeName)
		}
	}

	private func lookup(_ key: String) -> String? {
		component.authoredAttributes.first { $0.name == key }?.value
	}

	private func copyComponentName() {
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(definition?.name ?? component.name, forType: .string)
	}

	private func copyComponentPayload() {
		let payloadName = definition?.name ?? component.name
		let payloadIdentifier = definition?.identifier ?? "unknown"
		let payload = """
		{
		  "name": "\(payloadName)",
		  "authoredPrimName": "\(component.name)",
		  "path": "\(component.path)",
		  "identifier": "\(payloadIdentifier)"
		}
		"""
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(payload, forType: .string)
	}

	private func copiedComponentIdentifierFromPasteboard() -> String? {
		guard let payload = NSPasteboard.general.string(forType: .string),
		      let data = payload.data(using: .utf8),
		      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
		else { return nil }
		return object["identifier"] as? String
	}
}

private struct GenericAttributeEditor: View {
	let attribute: InspectorAuthoredAttribute
	let onChange: (_ attributeType: String, _ valueLiteral: String) -> Void

	var body: some View {
		if let bool = parseBool(attribute.value) {
			Toggle(
				attribute.name,
				isOn: Binding(
					get: { bool },
					set: { onChange("bool", $0 ? "true" : "false") }
				)
			)
		} else if let number = Double(attribute.value.trimmingCharacters(in: .whitespacesAndNewlines)) {
			LabeledContent(attribute.name) {
				TextField("", value: Binding(
					get: { number },
					set: { onChange("double", String($0)) }
				), format: .number.precision(.fractionLength(0...4)))
				.textFieldStyle(.roundedBorder)
				.frame(minWidth: 80)
			}
		} else {
			LabeledContent(attribute.name) {
				TextField("", text: Binding(
					get: { stripUSDQuotes(attribute.value) },
					set: { onChange("string", quoteUSDString($0)) }
				))
				.textFieldStyle(.roundedBorder)
			}
		}
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

	var body: some View {
		Menu {
			ForEach(InspectorComponentCatalog.grouped, id: \.0) { category, components in
				Section(category.displayName) {
					ForEach(components, id: \.id) { component in
						Button(component.name) {
							onAdd(component.authoredPrimName, component.identifier)
						}
						.disabled(!component.isEnabledForAuthoring)
						.help(component.summary)
					}
				}
			}
		} label: {
			Label("Add Component", systemImage: "plus.circle")
				.font(.system(size: 12, weight: .semibold))
				.frame(maxWidth: .infinity)
		}
		.menuStyle(.borderlessButton)
		.padding(8)
		.background(.thinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 6))
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

private struct ReferencesEditor: View {
	let references: [SwiftUsdShell.USDReference]
	let onAdd: (SwiftUsdShell.USDReference) -> Void
	let onRemove: (SwiftUsdShell.USDReference) -> Void
	let onReplace: (_ old: SwiftUsdShell.USDReference, _ new: SwiftUsdShell.USDReference) -> Void
	@State private var selectedIndex: Int?

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			if references.isEmpty {
				Text("No authored references")
					.foregroundStyle(.secondary)
			} else {
				VStack(alignment: .leading, spacing: 4) {
					ForEach(Array(references.enumerated()), id: \.offset) { index, reference in
						Button {
							selectedIndex = index
						} label: {
							HStack(spacing: 8) {
								Image(systemName: "shippingbox")
									.font(.system(size: 11))
									.foregroundStyle(.secondary)
								VStack(alignment: .leading, spacing: 2) {
									Text(reference.assetPath)
										.font(.system(size: 11))
										.lineLimit(1)
										.truncationMode(.middle)
									if let primPath = reference.primPath, !primPath.isEmpty {
										Text("Prim: \(primPath)")
											.font(.system(size: 10))
											.foregroundStyle(.secondary)
											.lineLimit(1)
											.truncationMode(.middle)
									}
								}
								Spacer()
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 6)
							.background(
								selectedIndex == index ? Color.accentColor.opacity(0.18) : Color.clear
							)
							.clipShape(RoundedRectangle(cornerRadius: 8))
						}
						.buttonStyle(.plain)
					}
				}
			}

			Divider()

			HStack(spacing: 10) {
				Button {
					guard let reference = chooseReferenceFile() else { return }
					onAdd(reference)
				} label: {
					Image(systemName: "plus")
				}
				.buttonStyle(.plain)

				Button {
					guard let index = selectedIndex, references.indices.contains(index) else { return }
					onRemove(references[index])
					selectedIndex = references.count <= 1 ? nil : min(index, references.count - 2)
				} label: {
					Image(systemName: "minus")
				}
				.buttonStyle(.plain)
				.disabled(selectedIndex == nil)

				Button("Replace") {
					guard let index = selectedIndex, references.indices.contains(index) else { return }
					guard let newReference = chooseReferenceFile() else { return }
					onReplace(references[index], newReference)
				}
				.buttonStyle(.plain)
				.disabled(selectedIndex == nil)

				AddReferenceRow(onAdd: onAdd)
			}
			.font(.system(size: 13, weight: .semibold))
		}
	}

	private func chooseReferenceFile() -> SwiftUsdShell.USDReference? {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowedContentTypes = [
			UTType(filenameExtension: "usd"),
			UTType(filenameExtension: "usda"),
			UTType(filenameExtension: "usdc"),
			UTType(filenameExtension: "usdz")
		].compactMap { $0 }
		panel.prompt = "Select"
		guard panel.runModal() == .OK, let url = panel.url else { return nil }
		return SwiftUsdShell.USDReference(assetPath: url.path)
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

private struct MaterialPropertyRow: View {
	let property: SwiftUsdShell.USDMaterialPropertySummary

	var body: some View {
		LabeledContent(property.name) {
			switch property.value {
			case let .color(r, g, b):
				HStack(spacing: 8) {
					Color(red: Double(r), green: Double(g), blue: Double(b))
						.frame(width: 14, height: 14)
						.clipShape(RoundedRectangle(cornerRadius: 3))
						.overlay(
							RoundedRectangle(cornerRadius: 3)
								.strokeBorder(.quaternary, lineWidth: 1)
						)
					Text(String(format: "%.3f, %.3f, %.3f", r, g, b))
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				}
			case let .float(v):
				Text(v.formatted(.number.precision(.fractionLength(0...3))))
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			case let .texture(url, resolved):
				TextureValueView(url: url, resolvedPath: resolved)
			case let .bool(v):
				Text(v ? "true" : "false").font(.system(size: 11)).foregroundStyle(.secondary)
			case let .int(v):
				Text(String(v)).font(.system(size: 11)).foregroundStyle(.secondary)
			case let .string(v):
				Text(v).font(.system(size: 11)).foregroundStyle(.secondary)
					.lineLimit(1).truncationMode(.middle)
			case let .token(v):
				Text(v).font(.system(size: 11)).foregroundStyle(.secondary)
			case let .unsupported(_, description):
				Text(description).font(.system(size: 11)).foregroundStyle(.secondary)
					.lineLimit(1).truncationMode(.middle)
			}
		}
	}
}

private struct TextureValueView: View {
	let url: String
	let resolvedPath: String?

	var body: some View {
		HStack(spacing: 8) {
			if let image = loadPreviewImage() {
				Image(nsImage: image)
					.resizable()
					.scaledToFill()
					.frame(width: 18, height: 18)
					.clipShape(RoundedRectangle(cornerRadius: 4))
			} else {
				Image(systemName: "photo")
					.font(.system(size: 12))
					.foregroundStyle(.secondary)
			}

			Text(resolvedPath?.isEmpty == false ? resolvedPath! : url)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.middle)
				.textSelection(.enabled)
		}
	}

	private func loadPreviewImage() -> NSImage? {
		guard let resolvedPath, !resolvedPath.isEmpty else { return nil }
		return NSImage(contentsOf: URL(fileURLWithPath: resolvedPath))
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
								MaterialPropertyRow(property: property)
							}
						} label: {
							Text("Material Properties").font(.headline)
						}
					}
				}

				DisclosureGroup(isExpanded: disclosure(\.referencesExpanded)) {
					ReferencesEditor(
						references: store.primReferences,
						onAdd: { store.send(.addReferenceRequested($0)) },
						onRemove: { store.send(.removeReferenceRequested($0)) },
						onReplace: { old, new in
							store.send(.removeReferenceRequested(old))
							store.send(.addReferenceRequested(new))
						}
					)
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

				DisclosureGroup(isExpanded: disclosure(\.componentsExpanded)) {
					if store.primComponents.isEmpty {
						Text("No authored components")
							.foregroundStyle(.secondary)
					} else {
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
								},
								onPaste: { identifier in
									if let definition = InspectorComponentCatalog.definition(forIdentifier: identifier) {
										store.send(.addComponentRequested(
											componentName: definition.authoredPrimName,
											componentIdentifier: definition.identifier
										))
									}
								}
							)
						}
					}
					AddComponentRow { name, identifier in
						store.send(.addComponentRequested(componentName: name, componentIdentifier: identifier))
					}
				} label: {
					Text("Components").font(.headline)
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
