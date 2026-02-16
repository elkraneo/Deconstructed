import ComposableArchitecture
import AppKit
import Foundation
import InspectorFeature
import InspectorModels
import SceneGraphModels
import Sharing
import SwiftUI
import UniformTypeIdentifiers
import USDInterfaces
import USDInteropAdvancedCore

public struct InspectorView: View {
	@Bindable public var store: StoreOf<InspectorFeature>

	public init(store: StoreOf<InspectorFeature>) {
		self.store = store
	}

	public var body: some View {
		VStack(spacing: 0) {
			inspectorHeader
			Divider()
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					if store.isLoading {
						ProgressView()
							.frame(maxWidth: .infinity, alignment: .center)
							.padding()
					} else if let errorMessage = store.errorMessage {
						Text(errorMessage)
							.font(.caption)
							.foregroundStyle(.red)
							.padding()
					} else {
						switch store.currentTarget {
						case .sceneLayer:
							if let layerData = store.layerData {
								VStack(alignment: .leading, spacing: 16) {
									ScenePlaybackSection(
										playbackData: store.playbackData,
										isPlaying: store.playbackIsPlaying,
										currentTime: store.playbackCurrentTime,
										speed: store.playbackSpeed,
										onPlayPause: { store.send(.playbackPlayPauseTapped) },
										onStop: { store.send(.playbackStopTapped) },
										onScrub: { value, isEditing in
											store.send(.playbackScrubbed(value, isEditing: isEditing))
										}
									)

									LayerDataSection(
										layerData: layerData,
										onDefaultPrimChanged: { primPath in
											store.send(.defaultPrimChanged(primPath))
										},
										onMetersPerUnitChanged: { value in
											store.send(.metersPerUnitChanged(value))
										},
										onUpAxisChanged: { axis in
											store.send(.upAxisChanged(axis))
										},
										onConvertVariantsTapped: {
											store.send(.convertVariantsToConfigurationsTapped)
										}
									)
								}
							} else {
								// No layer data available yet
								VStack(spacing: 8) {
									Image(systemName: "cube.transparent")
										.font(.system(size: 32))
										.foregroundStyle(.secondary)
									Text("No Scene Data")
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								.frame(maxWidth: .infinity, minHeight: 100)
								.padding()
							}
						case .prim:
							if let selectedNode = store.selectedNode {
								let graphComponentNodesByPath = Dictionary(
									uniqueKeysWithValues: selectedNode.children
										.filter {
											$0.typeName == "RealityKitComponent"
											|| $0.typeName == "RealityKitCustomComponent"
											|| InspectorComponentCatalog.definition(forAuthoredPrimName: $0.name) != nil
										}
										.map { ($0.path, $0) }
								)
								let componentPaths = Set(graphComponentNodesByPath.keys)
									.union(store.componentActiveByPath.keys)
									.union(store.componentAuthoredAttributesByPath.keys)
									.sorted()
								VStack(alignment: .leading) {
									if let transform = store.primTransform {
										TransformSection(
											transform: transform,
											metersPerUnit: store.layerData?.metersPerUnit,
											onTransformChanged: { store.send(.primTransformChanged($0)) }
										)
									}

									MaterialBindingsSection(
										currentBindingPath: store.primMaterialBinding,
										currentStrength: store.primMaterialBindingStrength,
										boundMaterial: store.boundMaterial,
										materials: store.availableMaterials,
										onSetBinding: { store.send(.setMaterialBinding($0)) },
										onSetStrength: { store.send(.setMaterialBindingStrength($0)) }
									)

									PrimVariantsSection(
										variantSets: store.primVariantSets,
										onSelectionChanged: { setName, selectionId in
											store.send(
												.setVariantSelection(
													setName: setName,
													selectionId: selectionId
												)
											)
										}
									)

									PrimReferencesSection(
										references: store.primReferences,
										onAddReference: { reference in
											store.send(.addReferenceRequested(reference))
										},
										onRemoveReference: { reference in
											store.send(.removeReferenceRequested(reference))
										},
										onReplaceReference: { old, new in
											store.send(.replaceReferenceRequested(old: old, new: new))
										}
									)

									ForEach(componentPaths, id: \.self) { componentPath in
										let componentNode = graphComponentNodesByPath[componentPath]
										let componentName =
											componentNode?.name
											?? componentPath.split(separator: "/").last.map(String.init)
											?? componentPath
										let isActive = store.componentActiveByPath[componentPath] ?? true
										let authoredAttributes =
											store.componentAuthoredAttributesByPath[componentPath] ?? []
										let descendantAttributes =
											store.componentDescendantAttributesByPath[componentPath] ?? []
										ComponentParametersSection(
											componentPath: componentPath,
											componentName: componentName,
											definition: InspectorComponentCatalog.definition(
												forAuthoredPrimName: componentName
											),
											authoredAttributes: authoredAttributes,
											descendantAttributes: descendantAttributes,
											isActive: isActive,
											onToggleActive: { newValue in
												store.send(
													.setComponentActiveRequested(
														componentPath: componentPath,
														isActive: newValue
													)
												)
											},
											onParameterChanged: { identifier, parameterKey, value in
												store.send(
													.setComponentParameterRequested(
														componentPath: componentPath,
														componentIdentifier: identifier,
														parameterKey: parameterKey,
														value: value
													)
												)
											},
											onRawAttributeChanged: { targetPrimPath, attributeType, attributeName, valueLiteral in
												store.send(
													.setRawComponentAttributeRequested(
														componentPath: targetPrimPath,
														attributeType: attributeType,
														attributeName: attributeName,
														valueLiteral: valueLiteral
													)
												)
											},
											onPasteComponent: { copiedIdentifier in
												if let copiedDefinition = InspectorComponentCatalog.all.first(
													where: { $0.identifier == copiedIdentifier }
												) {
													store.send(.addComponentRequested(copiedDefinition))
												} else {
													store.send(
														.addComponentFailed(
															"Copied component '\(copiedIdentifier)' is not available in the catalog."
														)
													)
												}
											},
											onDelete: {
												store.send(
													.deleteComponentRequested(
														componentPath: componentPath
													)
												)
											}
										)
									}

									if store.primIsLoading {
										ProgressView()
											.frame(maxWidth: .infinity, alignment: .center)
											.padding(.vertical, 8)
									} else if let message = store.primErrorMessage {
										Text(message)
											.font(.caption)
											.foregroundStyle(.secondary)
									} else if let primAttributes = store.primAttributes {
										PrimDataSection(node: selectedNode)
										PrimAttributesSection(attributes: primAttributes)
									} else {
										Text("Select a prim to view its properties.")
											.font(.caption)
											.foregroundStyle(.secondary)
									}
								}
							} else {
								Text("No Prim Selected")
									.font(.caption)
									.foregroundStyle(.secondary)
									.padding()
							}
						}
					}
				}
				.padding()
			}

			if case .prim = store.currentTarget, store.selectedNode != nil {
				Divider()
				InspectorAddComponentFooter { component in
					store.send(.addComponentRequested(component))
				}
			}
		}
		.background(.background)
	}

	private var inspectorHeader: some View {
		HStack(spacing: 8) {
			Image(systemName: headerIcon)
				.font(.system(size: 12, weight: .medium))
				.foregroundStyle(.secondary)
			Text(headerTitle)
				.font(.system(size: 13, weight: .semibold))
			Spacer()
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(.ultraThinMaterial)
	}

	private var headerTitle: String {
		switch store.currentTarget {
		case .sceneLayer:
			if let url = store.sceneURL {
				let name = url.deletingPathExtension().lastPathComponent
				return name.isEmpty ? "Scene" : name
			}
			return "Scene"
		case .prim(let path):
			let components = path.split(separator: "/")
			return components.last.map(String.init) ?? "Prim"
		}
	}

	private var headerIcon: String {
		switch store.currentTarget {
		case .sceneLayer:
			return "cube.transparent"
		case .prim:
			return "cube"
		}
	}
}

private struct InspectorGroupBox<Content: View>: View {
	let title: String
	@Binding var isExpanded: Bool
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Button(action: { isExpanded.toggle() }) {
				HStack(spacing: 6) {
					Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
						.font(.system(size: 10))
						.foregroundStyle(.secondary)
					Text(title)
						.font(.system(size: 12, weight: .semibold))
					Spacer()
				}
			}
			.buttonStyle(.plain)

			if isExpanded {
				content
			}
		}
		.padding(12)
		.background(.quaternary.opacity(0.35))
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
}

struct PrimDataSection: View {
	let node: SceneNode
	@Shared(.inspectorDisclosureState) private var disclosureState

	var body: some View {
		InspectorGroupBox(title: "Prim", isExpanded: isExpanded) {
			VStack(alignment: .leading, spacing: 12) {
				InspectorRow(label: "Name") {
					Text(node.name)
						.font(.system(size: 11))
						.textSelection(.enabled)
				}

				InspectorRow(label: "Path") {
					Text(node.path)
						.font(.system(size: 11))
						.textSelection(.enabled)
				}

				InspectorRow(label: "Type") {
					Text(node.typeName ?? "Unknown")
						.font(.system(size: 11))
						.foregroundStyle(node.typeName == nil ? .secondary : .primary)
				}

				InspectorRow(label: "Specifier") {
					Text(node.specifier.rawValue)
						.font(.system(size: 11))
				}
			}
		}
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.primDataExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.primDataExpanded = newValue }
			}
		)
	}
}

struct PrimAttributesSection: View {
	let attributes: USDPrimAttributes
	@Shared(.inspectorDisclosureState) private var disclosureState

	var body: some View {
		InspectorGroupBox(title: "Properties", isExpanded: isExpanded) {
			VStack(alignment: .leading, spacing: 12) {
				InspectorRow(label: "USD Type") {
					Text(attributes.typeName)
						.font(.system(size: 11))
				}

				InspectorRow(label: "Active") {
					Text(attributes.isActive ? "Yes" : "No")
						.font(.system(size: 11))
				}

				InspectorRow(label: "Visibility") {
					Text(attributes.visibility)
						.font(.system(size: 11))
				}

				InspectorRow(label: "Purpose") {
					Text(attributes.purpose)
						.font(.system(size: 11))
				}

				InspectorRow(label: "Kind") {
					Text(attributes.kind)
						.font(.system(size: 11))
				}

				if !attributes.authoredAttributes.isEmpty {
					Divider()

					Text("Authored Attributes")
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.secondary)

					ForEach(attributes.authoredAttributes, id: \.name) { attribute in
						InspectorRow(label: attribute.name) {
							Text(attribute.value)
								.font(.system(size: 11))
								.textSelection(.enabled)
						}
					}
				}
			}
		}
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.primAttributesExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.primAttributesExpanded = newValue }
			}
		)
	}
}

struct MaterialBindingsSection: View {
	let currentBindingPath: String?
	let currentStrength: USDMaterialBindingStrength?
	let boundMaterial: USDMaterialInfo?
	let materials: [USDMaterialInfo]
	let onSetBinding: (String?) -> Void
	let onSetStrength: (USDMaterialBindingStrength) -> Void
	@Shared(.inspectorDisclosureState) private var disclosureState
	@State private var strengthSelection: USDMaterialBindingStrength = .fallbackStrength

	var body: some View {
		InspectorGroupBox(title: "Material Bindings", isExpanded: isExpanded) {
			VStack(alignment: .leading, spacing: 12) {
				InspectorRow(label: "Binding") {
					HStack(spacing: 8) {
						Picker("", selection: bindingSelection) {
							Text("None").tag("")
							ForEach(materials, id: \.path) { material in
								Text(material.name.isEmpty ? material.path : material.name)
									.tag(material.path)
							}
						}
						.labelsHidden()
						.pickerStyle(.menu)

						Button {
							onSetBinding(nil)
						} label: {
							Image(systemName: "xmark.circle.fill")
								.foregroundStyle(.secondary)
						}
						.buttonStyle(.plain)
						.help("Clear binding")
					}
				}

				if let resolvedBindingPath = normalizeMaterialPath(currentBindingPath) {
					InspectorRow(label: "Strength") {
						Picker("", selection: $strengthSelection) {
							ForEach(USDMaterialBindingStrength.allCases, id: \.self) { strength in
								Text(strength.displayName).tag(strength)
							}
						}
						.labelsHidden()
						.pickerStyle(.menu)
						.onChange(of: strengthSelection) { _, newValue in
							if newValue == (currentStrength ?? .fallbackStrength) { return }
							onSetStrength(newValue)
						}
					}

					Text(resolvedBindingPath)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
						.textSelection(.enabled)
				} else {
					Text("No material bound.")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				}

				if let boundMaterial {
					Divider()

					Text(boundMaterial.name.isEmpty ? "Material Properties" : boundMaterial.name)
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.secondary)

					if boundMaterial.properties.isEmpty {
						Text("No authored material properties found.")
							.font(.system(size: 11))
							.foregroundStyle(.secondary)
					} else {
						ForEach(boundMaterial.properties, id: \.name) { property in
							MaterialPropertyRow(property: property)
						}
					}
				} else {
					// Keep the section informative even if material discovery is empty.
					if normalizeMaterialPath(currentBindingPath) != nil {
						Text("Material properties unavailable (material list did not include the bound path).")
							.font(.system(size: 11))
							.foregroundStyle(.secondary)
					}
				}
			}
			.onAppear {
				strengthSelection = currentStrength ?? .fallbackStrength
			}
			.onChange(of: currentStrength) { _, newValue in
				strengthSelection = newValue ?? .fallbackStrength
			}
		}
	}

	private var bindingSelection: Binding<String> {
		Binding(
			get: { normalizeMaterialPath(currentBindingPath) ?? "" },
			set: { newValue in
				let normalizedCurrent = normalizeMaterialPath(currentBindingPath) ?? ""
				let normalizedNew = normalizeMaterialPath(newValue) ?? ""
				if normalizedNew == normalizedCurrent { return }
				onSetBinding(normalizedNew.isEmpty ? nil : normalizedNew)
			}
		)
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.materialBindingsExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.materialBindingsExpanded = newValue }
			}
		)
	}
}

private func normalizeMaterialPath(_ path: String?) -> String? {
	guard var path, !path.isEmpty else { return nil }
	path = path.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !path.isEmpty else { return nil }
	if path.first == "<", path.last == ">", path.count >= 2 {
		path.removeFirst()
		path.removeLast()
	}
	return path.isEmpty ? nil : path
}

private struct MaterialPropertyRow: View {
	let property: USDMaterialProperty

	var body: some View {
		InspectorRow(label: property.name) {
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
			case let .texture(url, resolvedPath):
				TextureValueView(url: url, resolvedPath: resolvedPath)
			@unknown default:
				Text("Unsupported")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
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

			Text(displayText)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.middle)
				.textSelection(.enabled)
		}
	}

	private var displayText: String {
		if let resolvedPath, !resolvedPath.isEmpty {
			return resolvedPath
		}
		return url
	}

	private func loadPreviewImage() -> NSImage? {
		guard let resolvedPath, !resolvedPath.isEmpty else { return nil }
		let fileURL = URL(fileURLWithPath: resolvedPath)
		return NSImage(contentsOf: fileURL)
	}
}

struct TransformSection: View {
	let transform: USDTransformData
	let metersPerUnit: Double?
	let onTransformChanged: (USDTransformData) -> Void
	@Shared(.inspectorDisclosureState) private var disclosureState
	@State private var isUniformScale: Bool

	private var lengthUnitLabel: String {
		guard let metersPerUnit else { return "m" }
		if Swift.abs(metersPerUnit - 0.01) < 0.0001 { return "cm" }
		return "m"
	}

	init(
		transform: USDTransformData,
		metersPerUnit: Double?,
		onTransformChanged: @escaping (USDTransformData) -> Void
	) {
		self.transform = transform
		self.metersPerUnit = metersPerUnit
		self.onTransformChanged = onTransformChanged
		let s = transform.scale
		let isUniform =
			Swift.abs(s.x - s.y) < 0.000_001
			&& Swift.abs(s.y - s.z) < 0.000_001
		self._isUniformScale = State(initialValue: isUniform)
	}

	var body: some View {
		InspectorGroupBox(title: "Transform", isExpanded: isExpanded) {
			VStack(alignment: .leading, spacing: 10) {
				TransformEditableRow(
					label: "Position",
					unit: lengthUnitLabel,
					values: transform.position,
					onValuesChanged: { values in
						var updated = transform
						updated.position = values
						onTransformChanged(updated)
					}
				)
				TransformEditableRow(
					label: "Rotation",
					unit: "°",
					values: transform.rotationDegrees,
					onValuesChanged: { values in
						var updated = transform
						updated.rotationDegrees = values
						onTransformChanged(updated)
					}
				)
				UniformScaleEditableRow(
					label: "Scale",
					unit: "",
					values: transform.scale,
					isUniformScale: $isUniformScale,
					onValuesChanged: { values in
						var updated = transform
						updated.scale = values
						onTransformChanged(updated)
					}
				)
			}
		}
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.transformExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.transformExpanded = newValue }
			}
		)
	}
}

private struct PrimVariantsSection: View {
	let variantSets: [USDVariantSetDescriptor]
	let onSelectionChanged: (String, String?) -> Void
	@Shared(.inspectorDisclosureState) private var disclosureState

	var body: some View {
		InspectorGroupBox(title: "Variants", isExpanded: isExpanded) {
			if variantSets.isEmpty {
				Text("No variant sets")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			} else {
				VStack(alignment: .leading, spacing: 10) {
					ForEach(variantSets, id: \.key) { set in
						InspectorRow(label: set.name) {
							Picker(
								"",
								selection: Binding(
									get: { set.selectedOptionId ?? "__none__" },
									set: { newValue in
										onSelectionChanged(set.name, newValue == "__none__" ? nil : newValue)
									}
								)
							) {
								Text("None").tag("__none__")
								ForEach(set.options, id: \.id) { option in
									Text(option.displayName).tag(option.id)
								}
							}
							.pickerStyle(.menu)
							.labelsHidden()
						}
					}
				}
			}
		}
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.variantsExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.variantsExpanded = newValue }
			}
		)
	}
}

private struct PrimReferencesSection: View {
	let references: [USDReference]
	let onAddReference: (USDReference) -> Void
	let onRemoveReference: (USDReference) -> Void
	let onReplaceReference: (USDReference, USDReference) -> Void
	@Shared(.inspectorDisclosureState) private var disclosureState
	@State private var selectedIndex: Int?

	var body: some View {
		InspectorGroupBox(title: "References", isExpanded: isExpanded) {
			VStack(alignment: .leading, spacing: 10) {
				if references.isEmpty {
					Text("No references")
						.font(.system(size: 11))
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
									selectedIndex == index
										? Color.accentColor.opacity(0.18)
										: Color.clear
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
						guard let reference = chooseReference() else { return }
						onAddReference(reference)
					} label: {
						Image(systemName: "plus")
					}
					.buttonStyle(.plain)

					Button {
						guard let index = selectedIndex, references.indices.contains(index) else { return }
						onRemoveReference(references[index])
						if references.count <= 1 {
							selectedIndex = nil
						} else {
							selectedIndex = min(index, references.count - 2)
						}
					} label: {
						Image(systemName: "minus")
					}
					.buttonStyle(.plain)
					.disabled(selectedIndex == nil)

					Button("Replace") {
						guard let index = selectedIndex, references.indices.contains(index) else { return }
						guard let newReference = chooseReference() else { return }
						onReplaceReference(references[index], newReference)
					}
					.buttonStyle(.plain)
					.disabled(selectedIndex == nil)
				}
				.font(.system(size: 13, weight: .semibold))
			}
		}
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.referencesExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.referencesExpanded = newValue }
			}
		)
	}

	private func chooseReference() -> USDReference? {
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
		return USDReference(assetPath: url.path)
	}
}

private struct InspectorAddComponentFooter: View {
	let onAddComponent: (InspectorComponentDefinition) -> Void

	var body: some View {
		HStack {
			Menu {
				ForEach(InspectorComponentCatalog.grouped, id: \.0) { category, components in
					Section(category.displayName) {
						ForEach(components, id: \.id) { component in
							Button(component.name) {
								onAddComponent(component)
							}
							.disabled(!component.isEnabledForAuthoring)
							.help(component.summary)
						}
					}
				}
			} label: {
				Text("Add Component")
					.font(.system(size: 12, weight: .semibold))
					.frame(maxWidth: .infinity)
			}
			.menuStyle(.borderlessButton)
		}
		.padding(12)
		.background(.thinMaterial)
	}
}

private struct ComponentParametersSection: View {
	let componentPath: String
	let componentName: String
	let definition: InspectorComponentDefinition?
	let authoredAttributes: [USDPrimAttributes.AuthoredAttribute]
	let descendantAttributes: [ComponentDescendantAttributes]
	let isActive: Bool
	let onToggleActive: (Bool) -> Void
	let onParameterChanged: (String, String, InspectorComponentParameterValue) -> Void
	let onRawAttributeChanged: (String, String, String, String) -> Void
	let onPasteComponent: (String) -> Void
	let onDelete: () -> Void
	@State private var values: [String: InspectorComponentParameterValue]
	@State private var rawValues: [String: String]
	@State private var rawAttributeTypes: [String: String]
	@State private var isExpanded: Bool

	init(
		componentPath: String,
		componentName: String,
		definition: InspectorComponentDefinition?,
		authoredAttributes: [USDPrimAttributes.AuthoredAttribute],
		descendantAttributes: [ComponentDescendantAttributes],
		isActive: Bool,
		onToggleActive: @escaping (Bool) -> Void,
		onParameterChanged: @escaping (String, String, InspectorComponentParameterValue) -> Void,
		onRawAttributeChanged: @escaping (String, String, String, String) -> Void,
		onPasteComponent: @escaping (String) -> Void,
		onDelete: @escaping () -> Void
	) {
		self.componentPath = componentPath
		self.componentName = componentName
		self.definition = definition
		self.authoredAttributes = authoredAttributes
		self.descendantAttributes = descendantAttributes
		self.isActive = isActive
		self.onToggleActive = onToggleActive
		self.onParameterChanged = onParameterChanged
		self.onRawAttributeChanged = onRawAttributeChanged
		self.onPasteComponent = onPasteComponent
		self.onDelete = onDelete
		let layout = definition?.parameterLayout ?? []
		let allAuthoredAttributes = authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes)
		let authoredMap = Self.authoredMap(from: allAuthoredAttributes)
		self._values = State(initialValue: Self.initialValues(layout: layout, authoredAttributes: authoredMap, identifier: definition?.identifier))
		self._rawValues = State(
			initialValue: Dictionary(
				uniqueKeysWithValues: authoredAttributes.map { ($0.name, $0.value) }
			)
		)
		self._rawAttributeTypes = State(
			initialValue: inferredTypeMap(
				for: authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes)
			)
		)
		self._isExpanded = State(initialValue: true)
	}

	var body: some View {
		InspectorGroupBox(
			title: definition?.name ?? componentName,
			isExpanded: $isExpanded
		) {
			HStack(spacing: 8) {
				Spacer()
				Menu {
					Button("Copy Component") {
						copyComponentPayload()
					}
					Button("Copy Component Name") {
						copyComponentName()
					}
						Button("Paste Component") {
							guard let copiedIdentifier = copiedComponentIdentifierFromPasteboard() else { return }
							onPasteComponent(copiedIdentifier)
						}
						.disabled(copiedComponentIdentifierFromPasteboard() == nil)

					Divider()

					Button(isActive ? "Deactivate" : "Activate") {
						onToggleActive(!isActive)
					}

					Divider()

					Button("Remove Overrides") {
						// TODO: implement component override clearing semantics.
					}
					.disabled(true)

					Divider()
					Button("Delete", role: .destructive) {
						onDelete()
					}
				} label: {
					Image(systemName: "ellipsis")
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(.secondary)
						.frame(width: 20, height: 20)
				}
				.menuStyle(.borderlessButton)
				Button {
					onToggleActive(!isActive)
				} label: {
					Image(systemName: isActive ? "checkmark.circle" : "circle")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(isActive ? .orange : .secondary)
				}
				.buttonStyle(.plain)
				.help(isActive ? "Deactivate component" : "Activate component")
			}

			Group {
				let parameters = definition?.parameterLayout ?? []
				if parameters.isEmpty {
					let visibleAttributes = authoredAttributes.filter { $0.name != "info:id" }
					if visibleAttributes.isEmpty {
						Text("No editable parameters mapped yet.")
							.font(.system(size: 11))
							.foregroundStyle(.secondary)
					} else {
						VStack(alignment: .leading, spacing: 8) {
							ForEach(visibleAttributes, id: \.name) { attribute in
								GenericComponentAttributeRow(
									name: attribute.name,
									attributeType: rawAttributeTypes[attribute.name]
										?? inferAttributeType(name: attribute.name, literal: attribute.value),
									value: rawBinding(for: attribute.name, fallback: attribute.value),
									onCommit: { newValue in
										let type = rawAttributeTypes[attribute.name]
											?? inferAttributeType(name: attribute.name, literal: attribute.value)
										let value = normalizeLiteral(
											newValue,
											attributeType: type
										)
										rawValues[attribute.name] = value
										rawAttributeTypes[attribute.name] = type
										onRawAttributeChanged(
											componentPath,
											type,
											attribute.name,
											value
										)
									}
								)
							}
						}
					}
					if !descendantAttributes.isEmpty {
						Divider()
							.padding(.vertical, 4)
						VStack(alignment: .leading, spacing: 8) {
							ForEach(descendantAttributes, id: \.primPath) { descendant in
								let visibleDescendantAttrs = descendant.authoredAttributes.filter { $0.name != "info:id" }
								if !visibleDescendantAttrs.isEmpty {
									Text(descendant.displayName)
										.font(.system(size: 11, weight: .semibold))
										.foregroundStyle(.secondary)
									ForEach(visibleDescendantAttrs, id: \.name) { attribute in
										GenericComponentAttributeRow(
											name: "\(descendant.displayName).\(attribute.name)",
											attributeType: rawAttributeTypes["\(descendant.primPath)#\(attribute.name)"]
												?? inferAttributeType(name: attribute.name, literal: attribute.value),
											value: rawBinding(
												for: "\(descendant.primPath)#\(attribute.name)",
												fallback: attribute.value
											),
											onCommit: { newValue in
												let storageKey = "\(descendant.primPath)#\(attribute.name)"
												let type = rawAttributeTypes[storageKey]
													?? inferAttributeType(name: attribute.name, literal: attribute.value)
												let value = normalizeLiteral(
													newValue,
													attributeType: type
												)
												rawValues[storageKey] = value
												rawAttributeTypes[storageKey] = type
												onRawAttributeChanged(
													descendant.primPath,
													type,
													attribute.name,
													value
												)
											}
										)
									}
								}
							}
						}
					}
				} else {
					VStack(alignment: .leading, spacing: 10) {
						ForEach(parameters, id: \.key) { parameter in
							switch parameter.kind {
							case let .toggle(defaultValue):
								Toggle(
									parameter.label,
									isOn: boolBinding(for: parameter.key, fallback: defaultValue)
								)
								.font(.system(size: 11))
								.toggleStyle(.checkbox)

							case let .text(defaultValue, placeholder):
								VStack(alignment: .leading, spacing: 4) {
									Text(parameter.label)
										.font(.system(size: 11))
										.foregroundStyle(.secondary)
									TextField(
										placeholder,
										text: stringBinding(for: parameter.key, fallback: defaultValue)
									)
									.textFieldStyle(.roundedBorder)
									.font(.system(size: 11))
								}

							case let .scalar(defaultValue, unit):
								InspectorRow(label: parameter.label) {
									HStack(spacing: 8) {
										TextField(
											"",
											value: doubleBinding(for: parameter.key, fallback: defaultValue),
											format: .number.precision(.fractionLength(0...3))
										)
										.textFieldStyle(.roundedBorder)
										.frame(width: 90)
										.font(.system(size: 11))
										if let unit {
											Text(unit)
												.font(.system(size: 10))
												.foregroundStyle(.secondary)
										}
									}
								}

							case let .choice(defaultValue, options):
								InspectorRow(label: parameter.label) {
									Picker(
										"",
										selection: stringBinding(for: parameter.key, fallback: defaultValue)
									) {
										ForEach(options, id: \.self) { option in
											Text(option).tag(option)
										}
									}
									.labelsHidden()
									.pickerStyle(.menu)
								}
							}
						}
					}
				}
			}
			.disabled(!isActive)
		}
		.opacity(isActive ? 1 : 0.55)
		.animation(.default, value: isActive)
		.onChange(of: authoredAttributesSignature) { _, _ in
			let layout = definition?.parameterLayout ?? []
			rawValues = Dictionary(
				uniqueKeysWithValues: authoredAttributes.map { ($0.name, $0.value) }
			)
			rawAttributeTypes = inferredTypeMap(
				for: authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes)
			)
			guard !layout.isEmpty else { return }
			let allAuthoredAttributes = authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes)
			values = Self.initialValues(
				layout: layout,
				authoredAttributes: Self.authoredMap(from: allAuthoredAttributes),
				identifier: componentIdentifier
			)
		}
	}

	private func boolBinding(for key: String, fallback: Bool) -> Binding<Bool> {
		Binding(
			get: {
				if case let .bool(value)? = values[key] { return value }
				return fallback
			},
			set: {
				values[key] = .bool($0)
				notifyParameterChange(key: key, value: .bool($0))
			}
		)
	}

	private func stringBinding(for key: String, fallback: String) -> Binding<String> {
		Binding(
			get: {
				if case let .string(value)? = values[key] { return value }
				return fallback
			},
			set: {
				values[key] = .string($0)
				notifyParameterChange(key: key, value: .string($0))
			}
		)
	}

	private func doubleBinding(for key: String, fallback: Double) -> Binding<Double> {
		Binding(
			get: {
				if case let .double(value)? = values[key] { return value }
				return fallback
			},
			set: {
				values[key] = .double($0)
				notifyParameterChange(key: key, value: .double($0))
			}
		)
	}

	private func notifyParameterChange(key: String, value: InspectorComponentParameterValue) {
		guard let componentIdentifier else { return }
		onParameterChanged(componentIdentifier, key, value)
	}

	private func rawBinding(for key: String, fallback: String) -> Binding<String> {
		Binding(
			get: { rawValues[key] ?? fallback },
			set: { rawValues[key] = $0 }
		)
	}

	private func inferAttributeType(name: String, literal: String) -> String {
		let trimmed = literal.trimmingCharacters(in: .whitespacesAndNewlines)
		let lowerName = name.lowercased()
		if lowerName.contains("color"), trimmed.hasPrefix("("), trimmed.hasSuffix(")") {
			let commaCount = trimmed.filter { $0 == "," }.count
			return commaCount == 2 ? "color3f" : "color4f"
		}
		if trimmed.hasPrefix("("), trimmed.hasSuffix(")") {
			let commaCount = trimmed.filter { $0 == "," }.count
			return switch commaCount {
			case 1: "float2"
			case 2: "float3"
			case 3: "float4"
			default: "float3"
			}
		}
		let lower = trimmed.lowercased()
		if lower == "true" || lower == "false" {
			return "bool"
		}
		if lower == "0" || lower == "1" {
			if lowerName.hasPrefix("is")
				|| lowerName.hasPrefix("has")
				|| lowerName.hasPrefix("enable")
				|| lowerName.hasPrefix("use")
			{
				return "bool"
			}
		}
		if trimmed.first == "\"", trimmed.last == "\"" {
			if lowerName == "label"
				|| lowerName == "value"
				|| lowerName == "name"
				|| lowerName == "title"
				|| lowerName.hasSuffix("text")
				|| lowerName.contains("description")
			{
				return "string"
			}
			return "token"
		}
		if Int(trimmed) != nil {
			return "int"
		}
		if Double(trimmed) != nil {
			return "float"
		}
		return "token"
	}

	private func inferredTypeMap(
		for attributes: [USDPrimAttributes.AuthoredAttribute]
	) -> [String: String] {
		var result: [String: String] = [:]
		for attribute in attributes {
			result[attribute.name] = inferAttributeType(name: attribute.name, literal: attribute.value)
		}
		return result
	}

	private func normalizeLiteral(_ input: String, attributeType: String) -> String {
		let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
		switch attributeType {
		case "string", "token":
			if trimmed.first == "\"", trimmed.last == "\"" {
				return trimmed
			}
			let escaped = trimmed
				.replacingOccurrences(of: "\\", with: "\\\\")
				.replacingOccurrences(of: "\"", with: "\\\"")
			return "\"\(escaped)\""
		case "bool":
			let lower = trimmed.lowercased()
			if lower == "1" || lower == "true" { return "true" }
			if lower == "0" || lower == "false" { return "false" }
			return "false"
		default:
			return trimmed
		}
	}

	private func copiedComponentIdentifierFromPasteboard() -> String? {
		let pasteboard = NSPasteboard.general
		guard let payload = pasteboard.string(forType: .string) else { return nil }
		guard let data = payload.data(using: .utf8) else { return nil }
		guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
		guard let dictionary = object as? [String: Any] else { return nil }
		return dictionary["identifier"] as? String
	}

	private func copyComponentName() {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(definition?.name ?? componentName, forType: .string)
	}

	private func copyComponentPayload() {
		let payloadName = definition?.name ?? componentName
		let payloadIdentifier = definition?.identifier ?? "unknown"
		let payload = """
		{
		  "name": "\(payloadName)",
		  "authoredPrimName": "\(componentName)",
		  "path": "\(componentPath)",
		  "identifier": "\(payloadIdentifier)"
		}
		"""
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(payload, forType: .string)
	}

	private var componentIdentifier: String? {
		definition?.identifier
		?? authoredAttributes.first(where: { $0.name == "info:id" })?.value
			.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
	}

	private var authoredAttributesSignature: String {
		(authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes))
			.map { "\($0.name)=\($0.value)" }
			.sorted()
			.joined(separator: "|")
	}

	private static func authoredMap(from attributes: [USDPrimAttributes.AuthoredAttribute]) -> [String: String] {
		var map: [String: String] = [:]
		for attribute in attributes {
			map[attribute.name] = attribute.value
		}
		return map
	}

	private static func initialValues(
		layout: [InspectorComponentParameter],
		authoredAttributes: [String: String],
		identifier: String?
	) -> [String: InspectorComponentParameterValue] {
		Dictionary(
			uniqueKeysWithValues: layout.map { parameter in
				(
					parameter.key,
					initialValue(
						for: parameter,
						authoredAttributes: authoredAttributes,
						identifier: identifier
					)
				)
			}
		)
	}

	private static func initialValue(
		for parameter: InspectorComponentParameter,
		authoredAttributes: [String: String],
		identifier: String?
	) -> InspectorComponentParameterValue {
		let authoredName = authoredNameForParameter(
			key: parameter.key,
			componentIdentifier: identifier
		)
		let authoredRaw = authoredAttributes[authoredName]
		switch parameter.kind {
		case let .toggle(defaultValue):
			guard let authoredRaw else {
				return .bool(defaultValue)
			}
			return .bool(parseUSDBool(authoredRaw) ?? defaultValue)
		case let .text(defaultValue, _):
			guard let authoredRaw else {
				return .string(defaultValue)
			}
			return .string(parseUSDString(authoredRaw))
		case let .scalar(defaultValue, _):
			guard let authoredRaw else {
				return .double(defaultValue)
			}
			return .double(parseUSDDouble(authoredRaw) ?? defaultValue)
		case let .choice(defaultValue, options):
			guard let authoredRaw else {
				return .string(defaultValue)
			}
			let parsed = parseUSDString(authoredRaw)
			let resolved = options.contains(parsed) ? parsed : defaultValue
			return .string(resolved)
		}
	}

	private static func authoredNameForParameter(
		key: String,
		componentIdentifier: String?
	) -> String {
		switch (componentIdentifier, key) {
		case ("RealityKit.Reverb", "preset"):
			return "reverbPreset"
		case ("RealityKit.PointLight", "attenuationFalloff"):
			return "attenuationFalloffExponent"
		case ("RealityKit.SpotLight", "attenuationFalloff"):
			return "attenuationFalloffExponent"
		case ("RealityKit.SpotLight", "shadowEnabled"):
			return "isEnabled"
		case ("RealityKit.SpotLight", "shadowBias"):
			return "depthBias"
		case ("RealityKit.SpotLight", "shadowCullMode"):
			return "cullMode"
		case ("RealityKit.SpotLight", "shadowNear"):
			return "zNear"
		case ("RealityKit.SpotLight", "shadowFar"):
			return "zFar"
		default:
			return key
		}
	}

	private static func parseUSDBool(_ raw: String) -> Bool? {
		switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
		case "true":
			return true
		case "false":
			return false
		case "1":
			return true
		case "0":
			return false
		default:
			return nil
		}
	}

	private static func parseUSDDouble(_ raw: String) -> Double? {
		Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
	}

	private static func parseUSDString(_ raw: String) -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.count >= 2, trimmed.first == "\"", trimmed.last == "\"" else {
			return trimmed
		}
		let start = trimmed.index(after: trimmed.startIndex)
		let end = trimmed.index(before: trimmed.endIndex)
		let inner = String(trimmed[start..<end])
		return inner
			.replacingOccurrences(of: "\\\"", with: "\"")
			.replacingOccurrences(of: "\\\\", with: "\\")
	}
}

private struct GenericComponentAttributeRow: View {
	let name: String
	let attributeType: String
	@Binding var value: String
	let onCommit: (String) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(name)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
			switch attributeType {
			case "bool":
				Toggle(
					"",
					isOn: Binding(
						get: {
							let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
							return lower == "true" || lower == "1"
						},
						set: { isOn in
							value = isOn ? "true" : "false"
							onCommit(value)
						}
					)
				)
				.labelsHidden()
				.toggleStyle(.checkbox)
			default:
				TextField("", text: $value)
					.textFieldStyle(.roundedBorder)
					.font(.system(size: 11))
					.onSubmit { onCommit(value) }
			}
		}
	}
}

private struct TransformEditableRow: View {
	let label: String
	let unit: String
	let values: SIMD3<Double>
	let onValuesChanged: (SIMD3<Double>) -> Void

	var body: some View {
		HStack(spacing: 8) {
			Text(label)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.frame(width: 80, alignment: .leading)

			Text(unit)
				.font(.system(size: 10))
				.foregroundStyle(.secondary)
				.frame(width: 18, alignment: .leading)

			Spacer()

			axisField(values.x, label: "X") { value in
				var updated = values
				updated.x = value
				onValuesChanged(updated)
			}
			axisField(values.y, label: "Y") { value in
				var updated = values
				updated.y = value
				onValuesChanged(updated)
			}
			axisField(values.z, label: "Z") { value in
				var updated = values
				updated.z = value
				onValuesChanged(updated)
			}
		}
	}

	private func axisField(_ value: Double, label: String, onCommit: @escaping (Double) -> Void) -> some View {
		EditableAxisField(
			value: value,
			label: label,
			onCommit: onCommit
		)
	}
}

private struct UniformScaleEditableRow: View {
	let label: String
	let unit: String
	let values: SIMD3<Double>
	@Binding var isUniformScale: Bool
	let onValuesChanged: (SIMD3<Double>) -> Void

	var body: some View {
		HStack(spacing: 8) {
			Text(label)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.frame(width: 80, alignment: .leading)

			Text(unit)
				.font(.system(size: 10))
				.foregroundStyle(.secondary)
				.frame(width: 18, alignment: .leading)

			Button {
				isUniformScale.toggle()
				guard isUniformScale else { return }
				let v = (values.x + values.y + values.z) / 3.0
				onValuesChanged(SIMD3<Double>(repeating: v))
			} label: {
				// `link.slash` is not available on macOS; use a stable pair.
				Image(systemName: isUniformScale ? "link.circle.fill" : "link.circle")
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(isUniformScale ? .primary : .secondary)
					.padding(4)
					.background(.quaternary.opacity(0.55))
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
			.buttonStyle(.plain)
			.help("Toggle uniform scale")

			Spacer()

			axisField(values.x, label: "X") { value in
				onValuesChanged(updatedScale(axis: .x, value: value))
			}
			axisField(values.y, label: "Y") { value in
				onValuesChanged(updatedScale(axis: .y, value: value))
			}
			axisField(values.z, label: "Z") { value in
				onValuesChanged(updatedScale(axis: .z, value: value))
			}
		}
	}

	private enum Axis { case x, y, z }

	private func updatedScale(axis: Axis, value: Double) -> SIMD3<Double> {
		if isUniformScale {
			return SIMD3<Double>(repeating: value)
		}
		var updated = values
		switch axis {
		case .x:
			updated.x = value
		case .y:
			updated.y = value
		case .z:
			updated.z = value
		}
		return updated
	}

	private func axisField(_ value: Double, label: String, onCommit: @escaping (Double) -> Void) -> some View {
		EditableAxisField(
			value: value,
			label: label,
			onCommit: onCommit
		)
	}
}

private struct EditableAxisField: View {
	let value: Double
	let label: String
	let onCommit: (Double) -> Void
	
	@State private var text: String = ""
	@State private var isEditing: Bool = false
	@FocusState private var isFocused: Bool

	private static let numberFormat = FloatingPointFormatStyle<Double>.number
		.precision(.fractionLength(0...3))

	var body: some View {
		TextField(label, text: $text)
			.focused($isFocused)
			.textFieldStyle(.plain)
			.font(.system(size: 11, weight: .medium))
			.multilineTextAlignment(.trailing)
			.frame(width: 44, alignment: .trailing)
			.padding(.horizontal, 6)
			.padding(.vertical, 4)
			.background(.quaternary.opacity(0.5))
			.clipShape(RoundedRectangle(cornerRadius: 6))
			.overlay(
				Text(label)
					.font(.system(size: 8))
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
					.padding(.leading, 4)
					.padding(.bottom, 2)
			)
			.onAppear {
				text = value.formatted(Self.numberFormat)
			}
			.onChange(of: value) { _, newValue in
				// Only sync external value if not currently editing to prevent overwriting user input
				if !isEditing && !isFocused {
					text = newValue.formatted(Self.numberFormat)
				}
			}
			.onChange(of: isFocused) { wasFocused, nowFocused in
				if wasFocused && !nowFocused {
					// Lost focus - commit changes
					commit()
					isEditing = false
				} else if nowFocused {
					isEditing = true
				}
			}
			.onSubmit {
				commit()
				isEditing = false
			}
			.onExitCommand {
				// ESC pressed - revert to external value and unfocus
				text = value.formatted(Self.numberFormat)
				isEditing = false
				isFocused = false
			}
	}

	private func commit() {
		guard let parsed = parseFlexibleDouble(text) else {
			text = value.formatted(Self.numberFormat)
			return
		}
		onCommit(parsed)
		text = parsed.formatted(Self.numberFormat)
	}

	private func parseFlexibleDouble(_ raw: String) -> Double? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }

		let decimalSeparators = CharacterSet(charactersIn: ".,\u{066B}\u{FF0E}\u{FF0C}\u{3002}")
		let groupingSeparators = CharacterSet(charactersIn: "'\u{2019}\u{0060}\u{00A0}\u{202F}\u{066C}_ ")

		var scalars = Array(trimmed.unicodeScalars)
		let lastDecimalIndex = scalars.lastIndex { scalar in
			decimalSeparators.contains(scalar)
		}

		var normalized = ""
		for (index, scalar) in scalars.enumerated() {
			if let digit = Character(scalar).wholeNumberValue {
				normalized.append(String(digit))
				continue
			}
			if (scalar == "+" || scalar == "-") && index == 0 {
				normalized.append(Character(scalar))
				continue
			}
			if groupingSeparators.contains(scalar) {
				continue
			}
			if decimalSeparators.contains(scalar) {
				if index == lastDecimalIndex {
					normalized.append(".")
				}
				continue
			}
			return try? Self.numberFormat.parseStrategy.parse(trimmed)
		}

		if let parsed = Double(normalized) {
			return parsed
		}

		return try? Self.numberFormat.parseStrategy.parse(trimmed)
	}
}

struct ScenePlaybackSection: View {
	let playbackData: ScenePlaybackData?
	let isPlaying: Bool
	let currentTime: Double
	let speed: Double
	let onPlayPause: () -> Void
	let onStop: () -> Void
	let onScrub: (Double, Bool) -> Void
	@Shared(.inspectorDisclosureState) private var disclosureState

	private var isEnabled: Bool {
		playbackData?.hasTimeline ?? false
	}

	private var startTime: Double {
		playbackData?.startTimeCode ?? 0
	}

	private var endTime: Double {
		let end = playbackData?.endTimeCode ?? 0
		return max(end, startTime)
	}

	private var fps: Double {
		let value = playbackData?.timeCodesPerSecond ?? 24.0
		return value > 0 ? value : 24.0
	}

	var body: some View {
		InspectorGroupBox(title: "Scene Playback", isExpanded: isExpanded) {
			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 10) {
					Button(action: onPlayPause) {
						Image(systemName: isPlaying ? "pause.fill" : "play.fill")
							.font(.system(size: 12, weight: .semibold))
							.frame(width: 18, height: 18)
					}
					.buttonStyle(.plain)

					Button(action: onStop) {
						Image(systemName: "stop.fill")
							.font(.system(size: 10, weight: .semibold))
							.frame(width: 18, height: 18)
					}
					.buttonStyle(.plain)

					VStack(spacing: 2) {
						Slider(
							value: Binding(
								get: { currentTime },
								set: { onScrub($0, false) }
							),
							in: startTime...max(startTime + 0.001, endTime),
							onEditingChanged: { isEditing in
								onScrub(currentTime, isEditing)
							}
						)
						.controlSize(.small)

						HStack {
							Text(formatFrame(currentTime))
							Spacer()
							Text(formatFrame(endTime))
						}
						.font(.caption2.monospacedDigit())
						.foregroundStyle(.secondary)
					}
				}
				.disabled(!isEnabled)

				if !isEnabled {
					Text("No timeline range found in the USD.")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private func formatFrame(_ time: Double) -> String {
		let frame = time * fps
		return String(format: "%.0f", frame)
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.scenePlaybackExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.scenePlaybackExpanded = newValue }
			}
		)
	}
}

struct LayerDataSection: View {
	let layerData: SceneLayerData
	let onDefaultPrimChanged: (String) -> Void
	let onMetersPerUnitChanged: (Double) -> Void
	let onUpAxisChanged: (UpAxis) -> Void
	let onConvertVariantsTapped: () -> Void
	@Shared(.inspectorDisclosureState) private var disclosureState

	var body: some View {
		InspectorGroupBox(title: "Layer Data", isExpanded: isExpanded) {
			VStack(alignment: .leading, spacing: 12) {
				InspectorRow(label: "Default Prim") {
					Picker(
						"",
						selection: Binding(
							get: { layerData.defaultPrim ?? "" },
							set: { onDefaultPrimChanged($0) }
						)
					) {
						Text("None").tag("")
						ForEach(layerData.availablePrims, id: \.self) { prim in
							Text(prim).tag(prim)
						}
					}
					.pickerStyle(.menu)
					.labelsHidden()
				}

				InspectorRow(label: "Meters Per Unit") {
					TextField(
						"",
						value: Binding(
							get: { layerData.metersPerUnit },
							set: { onMetersPerUnitChanged($0) }
						),
						format: .number
					)
					.textFieldStyle(.plain)
					.multilineTextAlignment(.trailing)
					.frame(width: 80)
				}

				InspectorRow(label: "Up Axis") {
					Picker(
						"",
						selection: Binding(
							get: { layerData.upAxis },
							set: { onUpAxisChanged($0) }
						)
					) {
						ForEach(UpAxis.allCases, id: \.self) { axis in
							Text(axis.displayName).tag(axis)
						}
					}
					.pickerStyle(.menu)
					.labelsHidden()
				}

				Button(action: onConvertVariantsTapped) {
					Label(
						"Convert Variants to Configurations",
						systemImage: "arrow.triangle.2.circlepath"
					)
					.font(.system(size: 11))
				}
				.buttonStyle(.borderless)
				.disabled(true)
				.foregroundStyle(.secondary)
				.help("Deferred: will use USDInteropAdvanced combineVariants in a later pass.")
			}
		}
	}

	private var isExpanded: Binding<Bool> {
		Binding(
			get: { disclosureState.layerDataExpanded },
			set: { newValue in
				$disclosureState.withLock { $0.layerDataExpanded = newValue }
			}
		)
	}
}

struct InspectorRow<Content: View>: View {
	let label: String
	@ViewBuilder let content: Content

	var body: some View {
		HStack(spacing: 8) {
			Text(label)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.frame(width: 100, alignment: .leading)
			Spacer()
			content
		}
	}
}
