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
									let isMeshSortingGroupSelection = selectedNode.typeName == "RealityKitMeshSortingGroup"
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
									let sharedAudioLibraryResources: [AudioLibraryResource] = componentPaths.compactMap { path -> [AudioLibraryResource]? in
										let attrs = store.componentAuthoredAttributesByPath[path] ?? []
										guard componentIdentifier(from: attrs) == "RealityKit.AudioLibrary" else {
											return nil
										}
										let descendants = store.componentDescendantAttributesByPath[path] ?? []
									return parseAudioLibraryResources(from: descendants)
								}.first ?? []
								VStack(alignment: .leading) {
										if isMeshSortingGroupSelection {
											MeshSortingGroupSection(
												attributes: store.primAttributes?.authoredAttributes ?? [],
												members: store.meshSortingGroupMembers,
												onDepthPassChanged: { value in
													store.send(.setMeshSortingGroupDepthPassRequested(value))
												}
											)
										}
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
												audioLibraryResources: sharedAudioLibraryResources,
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
											onAddAudioResource: { targetPath, sourceURL in
												store.send(
													.addAudioLibraryResourceRequested(
														componentPath: targetPath,
														sourceURL: sourceURL
													)
												)
											},
											onRemoveAudioResource: { targetPath, resourceKey in
												store.send(
													.removeAudioLibraryResourceRequested(
														componentPath: targetPath,
														resourceKey: resourceKey
													)
												)
											},
											onAddAnimationResource: { targetPath, sourceURL in
												store.send(
													.addAnimationLibraryResourceRequested(
														componentPath: targetPath,
														sourceURL: sourceURL
													)
												)
											},
											onRemoveAnimationResource: { targetPath, resourcePrimPath in
												store.send(
													.removeAnimationLibraryResourceRequested(
														componentPath: targetPath,
														resourcePrimPath: resourcePrimPath
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

				if case .prim = store.currentTarget,
				   let selectedNode = store.selectedNode,
				   selectedNode.typeName != "RealityKitMeshSortingGroup"
				{
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

private func componentIdentifier(from attributes: [USDPrimAttributes.AuthoredAttribute]) -> String? {
	attributes
		.first(where: { $0.name == "info:id" })?
		.value
		.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
}

private func parseAudioLibraryResources(
	from descendantAttributes: [ComponentDescendantAttributes]
) -> [AudioLibraryResource] {
	guard let resourcesNode = descendantAttributes.first(where: {
		$0.displayName == "resources"
			|| $0.displayName.lowercased().contains("resources")
			|| $0.primPath.hasSuffix("/resources")
	}) else {
		return []
	}
	let attrs = resourcesNode.authoredAttributes
	let keys = parseUSDStringArrayLiteral(authoredLiteralValue(in: attrs, names: ["keys"]))
	let values = parseUSDRelationshipTargetsLiteral(authoredLiteralValue(in: attrs, names: ["values"]))
	guard !keys.isEmpty else { return [] }
	return keys.enumerated().map { index, key in
		AudioLibraryResource(key: key, valueTarget: index < values.count ? values[index] : "")
	}
}

private func parseAnimationLibraryResources(
	from descendantAttributes: [ComponentDescendantAttributes]
) -> [AnimationLibraryResource] {
	descendantAttributes.compactMap { descendant in
		let fileLiteral = authoredLiteralValue(
			in: descendant.authoredAttributes,
			names: ["file"]
		)
		guard !fileLiteral.isEmpty else { return nil }
		let displayName = parseUSDStringLiteral(
			authoredLiteralValue(
				in: descendant.authoredAttributes,
				names: ["name"],
				allowLooseMatch: false
			)
		)
		let relativeAssetPath = parseUSDAssetPathLiteral(fileLiteral)
		return AnimationLibraryResource(
			primPath: descendant.primPath,
			displayName: displayName.isEmpty ? descendant.displayName : displayName,
			relativeAssetPath: relativeAssetPath
		)
	}
	.sorted {
		$0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
	}
}

private func authoredLiteralValue(
	in attributes: [USDPrimAttributes.AuthoredAttribute],
	names: [String],
	allowLooseMatch: Bool = true
) -> String {
	let lowered = Set(names.map { $0.lowercased() })
	if let exact = attributes.first(where: { lowered.contains($0.name.lowercased()) }) {
		return exact.value
	}
	if let typed = attributes.first(where: { attribute in
		let key = attribute.name.lowercased()
		return lowered.contains(where: { key.hasSuffix(" \($0)") })
	}) {
		return typed.value
	}
	if allowLooseMatch, let loose = attributes.first(where: { attribute in
		let key = attribute.name.lowercased()
		return lowered.contains(where: { key.contains($0) })
	}) {
		return loose.value
	}
	return ""
}

private func parseUSDStringArrayLiteral(_ raw: String) -> [String] {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !trimmed.isEmpty else { return [] }
	if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
		let body = String(trimmed.dropFirst().dropLast())
		return body.split(separator: ",", omittingEmptySubsequences: true).map { token in
			parseUSDStringLiteral(String(token).trimmingCharacters(in: .whitespacesAndNewlines))
		}
	}
	if trimmed.hasPrefix("("), trimmed.hasSuffix(")"), trimmed.count >= 2 {
		let body = String(trimmed.dropFirst().dropLast())
		return body.split(separator: ",", omittingEmptySubsequences: true).map { token in
			parseUSDStringLiteral(String(token).trimmingCharacters(in: .whitespacesAndNewlines))
		}
	}
	return [parseUSDStringLiteral(trimmed)]
}

private func parseUSDRelationshipTargetsLiteral(_ raw: String) -> [String] {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
		let body = String(trimmed.dropFirst().dropLast())
		return body
			.split(separator: ",", omittingEmptySubsequences: true)
			.map { parseUSDRelationshipTargetLiteral(String($0)) }
			.filter { !$0.isEmpty }
	}
	let single = parseUSDRelationshipTargetLiteral(trimmed)
	return single.isEmpty ? [] : [single]
}

private func parseUSDStringLiteral(_ raw: String) -> String {
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

private func parseUSDRelationshipTargetLiteral(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), trimmed.count >= 2 {
		return String(trimmed.dropFirst().dropLast())
	}
	return trimmed
}

private func parseUSDAssetPathLiteral(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.count >= 2, trimmed.first == "@", trimmed.last == "@"
	else {
		return trimmed
	}
	let start = trimmed.index(after: trimmed.startIndex)
	let end = trimmed.index(before: trimmed.endIndex)
	return String(trimmed[start..<end])
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

private struct MeshSortingGroupSection: View {
	let attributes: [USDPrimAttributes.AuthoredAttribute]
	let members: [String]
	let onDepthPassChanged: (String) -> Void
	@State private var isExpanded = true

	var body: some View {
		InspectorGroupBox(
			title: "Model Sorting Group",
			isExpanded: $isExpanded
		) {
			InspectorRow(label: "Depth Pass") {
				Picker(
					"",
					selection: Binding(
						get: { currentDepthPass },
						set: { onDepthPassChanged($0) }
					)
				) {
					Text("None").tag("None")
					Text("Pre Pass").tag("prePass")
					Text("Post Pass").tag("postPass")
				}
				.labelsHidden()
				.pickerStyle(.menu)
			}

			VStack(alignment: .leading, spacing: 6) {
				if members.isEmpty {
					Text("No members assigned.")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				} else {
					ForEach(members, id: \.self) { member in
						Text(member)
							.font(.system(size: 11))
							.textSelection(.enabled)
					}
				}
			}
			.padding(8)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.quaternary.opacity(0.4))
			.clipShape(RoundedRectangle(cornerRadius: 8))
		}
	}

	private var currentDepthPass: String {
		attributes
			.first(where: { $0.name == "depthPass" })
			.map { parseUSDString($0.value) } ?? "None"
	}

	private func parseUSDString(_ raw: String) -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.count >= 2, trimmed.first == "\"", trimmed.last == "\"" else {
			return trimmed
		}
		let start = trimmed.index(after: trimmed.startIndex)
		let end = trimmed.index(before: trimmed.endIndex)
		return String(trimmed[start..<end])
	}
}

private struct ComponentParametersSection: View {
	let componentPath: String
	let componentName: String
	let definition: InspectorComponentDefinition?
	let authoredAttributes: [USDPrimAttributes.AuthoredAttribute]
	let descendantAttributes: [ComponentDescendantAttributes]
	let audioLibraryResources: [AudioLibraryResource]
	let isActive: Bool
	let onToggleActive: (Bool) -> Void
	let onParameterChanged: (String, String, InspectorComponentParameterValue) -> Void
	let onRawAttributeChanged: (String, String, String, String) -> Void
	let onAddAudioResource: (String, URL) -> Void
	let onRemoveAudioResource: (String, String) -> Void
	let onAddAnimationResource: (String, URL) -> Void
	let onRemoveAnimationResource: (String, String) -> Void
	let onPasteComponent: (String) -> Void
	let onDelete: () -> Void
	@State private var values: [String: InspectorComponentParameterValue]
	@State private var rawValues: [String: String]
	@State private var rawAttributeTypes: [String: String]
	@State private var isExpanded: Bool
	@State private var selectedAudioResourceKey: String?
	@State private var selectedPreviewResourceTarget: String?
	@State private var isMaterialExpanded: Bool
	@State private var isMassPropertiesExpanded: Bool
	@State private var isCenterOfMassExpanded: Bool
	@State private var isMovementLockingExpanded: Bool
	@State private var selectedAnimationResourcePrimPath: String?

	init(
		componentPath: String,
		componentName: String,
		definition: InspectorComponentDefinition?,
		authoredAttributes: [USDPrimAttributes.AuthoredAttribute],
		descendantAttributes: [ComponentDescendantAttributes],
		audioLibraryResources: [AudioLibraryResource],
		isActive: Bool,
		onToggleActive: @escaping (Bool) -> Void,
		onParameterChanged: @escaping (String, String, InspectorComponentParameterValue) -> Void,
		onRawAttributeChanged: @escaping (String, String, String, String) -> Void,
		onAddAudioResource: @escaping (String, URL) -> Void,
		onRemoveAudioResource: @escaping (String, String) -> Void,
		onAddAnimationResource: @escaping (String, URL) -> Void,
		onRemoveAnimationResource: @escaping (String, String) -> Void,
		onPasteComponent: @escaping (String) -> Void,
		onDelete: @escaping () -> Void
	) {
		self.componentPath = componentPath
		self.componentName = componentName
		self.definition = definition
		self.authoredAttributes = authoredAttributes
		self.descendantAttributes = descendantAttributes
		self.audioLibraryResources = audioLibraryResources
		self.isActive = isActive
		self.onToggleActive = onToggleActive
		self.onParameterChanged = onParameterChanged
		self.onRawAttributeChanged = onRawAttributeChanged
		self.onAddAudioResource = onAddAudioResource
		self.onRemoveAudioResource = onRemoveAudioResource
		self.onAddAnimationResource = onAddAnimationResource
		self.onRemoveAnimationResource = onRemoveAnimationResource
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
			initialValue: Self.inferredTypeMap(
				for: authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes)
			)
		)
		self._isExpanded = State(initialValue: true)
		self._selectedAudioResourceKey = State(initialValue: nil)
		self._selectedPreviewResourceTarget = State(initialValue: nil)
		self._isMaterialExpanded = State(initialValue: true)
		self._isMassPropertiesExpanded = State(initialValue: true)
		self._isCenterOfMassExpanded = State(initialValue: true)
		self._isMovementLockingExpanded = State(initialValue: true)
		self._selectedAnimationResourcePrimPath = State(initialValue: nil)
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
				if componentIdentifier == "RealityKit.AudioLibrary" {
					audioLibraryEditor
				} else if componentIdentifier == "RealityKit.AnimationLibrary" {
					animationLibraryEditor
				} else if componentIdentifier == "RealityKit.RigidBody" {
					physicsBodyEditor
				} else if parameters.isEmpty {
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
											?? Self.inferAttributeType(name: attribute.name, literal: attribute.value),
										value: rawBinding(for: attribute.name, fallback: attribute.value),
										onCommit: { newValue in
											let type = rawAttributeTypes[attribute.name]
												?? Self.inferAttributeType(name: attribute.name, literal: attribute.value)
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
													?? Self.inferAttributeType(name: attribute.name, literal: attribute.value),
												value: rawBinding(
													for: "\(descendant.primPath)#\(attribute.name)",
													fallback: attribute.value
											),
												onCommit: { newValue in
													let storageKey = "\(descendant.primPath)#\(attribute.name)"
													let type = rawAttributeTypes[storageKey]
														?? Self.inferAttributeType(name: attribute.name, literal: attribute.value)
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
							ForEach(parameters.filter { shouldDisplay(parameter: $0) }, id: \.key) { parameter in
							switch parameter.kind {
							case let .toggle(defaultValue):
								Toggle(
									parameter.label,
									isOn: boolBinding(for: parameter.key, fallback: defaultValue)
								)
								.font(.system(size: 11))
								.toggleStyle(.checkbox)

								case let .text(defaultValue, placeholder):
									if isColorParameter(parameter.key) {
										InspectorRow(label: parameter.label) {
											HStack(spacing: 8) {
												ColorPicker(
													"",
													selection: colorBinding(for: parameter.key, fallback: defaultValue),
													supportsOpacity: false
												)
												.labelsHidden()
												TextField(
													placeholder,
													text: stringBinding(for: parameter.key, fallback: defaultValue)
												)
												.textFieldStyle(.roundedBorder)
												.font(.system(size: 11))
											}
										}
									} else {
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
				if showsAudioPreviewSection {
					Divider()
						.padding(.vertical, 4)
					VStack(alignment: .leading, spacing: 8) {
						Text("Preview")
							.font(.system(size: 11, weight: .semibold))
							.foregroundStyle(.secondary)
						InspectorRow(label: "Resource") {
							Picker("", selection: previewResourceSelection) {
								ForEach(audioLibraryResources, id: \.valueTarget) { resource in
									Text(previewResourceLabel(for: resource)).tag(resource.valueTarget)
								}
							}
							.labelsHidden()
							.pickerStyle(.menu)
							.disabled(audioLibraryResources.isEmpty)
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
			rawAttributeTypes = Self.inferredTypeMap(
				for: authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes)
			)
			let availableKeys = Set(audioLibraryResources.map(\.key))
			if let selectedAudioResourceKey, !availableKeys.contains(selectedAudioResourceKey) {
				self.selectedAudioResourceKey = nil
			}
			let availablePreviewTargets = Set(audioLibraryResources.map(\.valueTarget))
			if let selectedPreviewResourceTarget,
				!availablePreviewTargets.contains(selectedPreviewResourceTarget)
			{
				self.selectedPreviewResourceTarget = nil
			}
			let availableAnimationPaths = Set(animationLibraryResources.map(\.primPath))
			if let selectedAnimationResourcePrimPath,
			   !availableAnimationPaths.contains(selectedAnimationResourcePrimPath)
			{
				self.selectedAnimationResourcePrimPath = nil
			}
			guard !layout.isEmpty else { return }
			// Accessibility edits are currently sensitive to async refresh ordering.
			// Keep local typed values stable instead of re-hydrating on every authored signature change.
			if componentIdentifier == "RealityKit.Accessibility" {
				return
			}
			let allAuthoredAttributes = authoredAttributes + descendantAttributes.flatMap(\.authoredAttributes)
			values = Self.initialValues(
				layout: layout,
				authoredAttributes: Self.authoredMap(from: allAuthoredAttributes),
				identifier: componentIdentifier
			)
		}
	}

	private var audioLibraryEditor: some View {
		VStack(alignment: .leading, spacing: 8) {
			VStack(alignment: .leading, spacing: 0) {
				if audioLibraryResources.isEmpty {
					Text("No audio resources.")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
						.padding(10)
						.frame(maxWidth: .infinity, alignment: .leading)
				} else {
					ForEach(audioLibraryResources, id: \.key) { resource in
						Button {
							selectedAudioResourceKey = resource.key
						} label: {
							HStack(spacing: 8) {
								Image(systemName: "waveform")
									.font(.system(size: 11))
									.foregroundStyle(.cyan)
								Text(resource.key)
									.font(.system(size: 11))
									.lineLimit(1)
								Spacer(minLength: 0)
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 6)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(
								selectedAudioResourceKey == resource.key
									? Color.accentColor.opacity(0.22)
									: Color.clear
							)
						}
						.buttonStyle(.plain)
					}
				}
			}
			.frame(minHeight: 120, maxHeight: 180)
			.background(.quaternary.opacity(0.35))
			.clipShape(RoundedRectangle(cornerRadius: 8))

			HStack(spacing: 10) {
				Button {
					guard let selectedURL = selectAudioFileURL() else { return }
					onAddAudioResource(componentPath, selectedURL)
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 12, weight: .medium))
				}
				.buttonStyle(.plain)
				Button {
					guard let selectedAudioResourceKey else { return }
					onRemoveAudioResource(componentPath, selectedAudioResourceKey)
					self.selectedAudioResourceKey = nil
				} label: {
					Image(systemName: "minus")
						.font(.system(size: 12, weight: .medium))
				}
				.buttonStyle(.plain)
				.disabled(selectedAudioResourceKey == nil)
				Spacer()
			}
			.padding(.horizontal, 4)
		}
	}

	private var animationLibraryEditor: some View {
		VStack(alignment: .leading, spacing: 8) {
			VStack(alignment: .leading, spacing: 0) {
				if animationLibraryResources.isEmpty {
					Text("No animation resources.")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
						.padding(10)
						.frame(maxWidth: .infinity, alignment: .leading)
				} else {
					ForEach(animationLibraryResources, id: \.primPath) { resource in
						Button {
							selectedAnimationResourcePrimPath = resource.primPath
						} label: {
							HStack(spacing: 8) {
								Image(systemName: "film")
									.font(.system(size: 11))
									.foregroundStyle(.cyan)
								Text(resource.displayName)
									.font(.system(size: 11))
									.lineLimit(1)
								Spacer(minLength: 0)
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 6)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(
								selectedAnimationResourcePrimPath == resource.primPath
									? Color.accentColor.opacity(0.22)
									: Color.clear
							)
						}
						.buttonStyle(.plain)
					}
				}
			}
			.frame(minHeight: 120, maxHeight: 180)
			.background(.quaternary.opacity(0.35))
			.clipShape(RoundedRectangle(cornerRadius: 8))

			HStack(spacing: 10) {
				Button {
					guard let selectedURL = selectAnimationFileURL() else { return }
					onAddAnimationResource(componentPath, selectedURL)
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 12, weight: .medium))
				}
				.buttonStyle(.plain)
				Button {
					guard let selectedAnimationResourcePrimPath else { return }
					onRemoveAnimationResource(
						componentPath,
						selectedAnimationResourcePrimPath
					)
					self.selectedAnimationResourcePrimPath = nil
				} label: {
					Image(systemName: "minus")
						.font(.system(size: 12, weight: .medium))
				}
				.buttonStyle(.plain)
				.disabled(selectedAnimationResourcePrimPath == nil)
				Spacer()
			}
			.padding(.horizontal, 4)
		}
	}

	private var showsAudioPreviewSection: Bool {
		guard let componentIdentifier else { return false }
		return componentIdentifier == "RealityKit.ChannelAudio"
			|| componentIdentifier == "RealityKit.SpatialAudio"
			|| componentIdentifier == "RealityKit.AmbientAudio"
	}

	private var previewResourceSelection: Binding<String> {
		Binding(
			get: {
				if let selectedPreviewResourceTarget {
					return selectedPreviewResourceTarget
				}
				return audioLibraryResources.first?.valueTarget ?? ""
			},
			set: { selectedPreviewResourceTarget = $0 }
		)
	}

	private var animationLibraryResources: [AnimationLibraryResource] {
		parseAnimationLibraryResources(from: descendantAttributes)
	}

	private func previewResourceLabel(for resource: AudioLibraryResource) -> String {
		let target = resource.valueTarget.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !target.isEmpty else { return resource.key }
		return target.split(separator: "/").last.map(String.init) ?? resource.key
	}

	private var physicsBodyEditor: some View {
		VStack(alignment: .leading, spacing: 10) {
			InspectorRow(label: "Mode") {
				Picker("", selection: stringBinding(for: "motionType", fallback: "Dynamic")) {
					Text("Dynamic").tag("Dynamic")
					Text("Kinematic").tag("Kinematic")
					Text("Static").tag("Static")
				}
				.labelsHidden()
				.pickerStyle(.menu)
				.frame(width: 170)
			}

			Toggle(
				"Detect Continuous Collision",
				isOn: boolBinding(for: "isCCDEnabled", fallback: false)
			)
			.font(.system(size: 11))
			.toggleStyle(.checkbox)

			Toggle(
				"Affected by Gravity",
				isOn: boolBinding(for: "gravityEnabled", fallback: true)
			)
			.font(.system(size: 11))
			.toggleStyle(.checkbox)

			InspectorRow(label: "Angular Damping") {
				TextField(
					"",
					value: doubleBinding(for: "angularDamping", fallback: 0),
					format: .number.precision(.fractionLength(0...3))
				)
				.textFieldStyle(.roundedBorder)
				.frame(width: 90)
				.font(.system(size: 11))
			}

			InspectorRow(label: "Linear Damping") {
				TextField(
					"",
					value: doubleBinding(for: "linearDamping", fallback: 0),
					format: .number.precision(.fractionLength(0...3))
				)
				.textFieldStyle(.roundedBorder)
				.frame(width: 90)
				.font(.system(size: 11))
			}

			physicsSubsection(title: "Material", isExpanded: $isMaterialExpanded) {
				InspectorRow(label: "Static Friction") {
					TextField(
						"",
						value: doubleBinding(for: "staticFriction", fallback: 0),
						format: .number.precision(.fractionLength(0...3))
					)
					.textFieldStyle(.roundedBorder)
					.frame(width: 90)
					.font(.system(size: 11))
				}
				InspectorRow(label: "Dynamic Friction") {
					TextField(
						"",
						value: doubleBinding(for: "dynamicFriction", fallback: 0),
						format: .number.precision(.fractionLength(0...3))
					)
					.textFieldStyle(.roundedBorder)
					.frame(width: 90)
					.font(.system(size: 11))
				}
				InspectorRow(label: "Restitution") {
					TextField(
						"",
						value: doubleBinding(for: "restitution", fallback: 0),
						format: .number.precision(.fractionLength(0...3))
					)
					.textFieldStyle(.roundedBorder)
					.frame(width: 90)
					.font(.system(size: 11))
				}
			}

			physicsSubsection(title: "Mass Properties", isExpanded: $isMassPropertiesExpanded) {
				InspectorRow(label: "Mass") {
					HStack(spacing: 6) {
						Text("g")
							.font(.system(size: 10))
							.foregroundStyle(.secondary)
						TextField(
							"",
							value: doubleBinding(for: "m_mass", fallback: 1),
							format: .number.precision(.fractionLength(0...3))
						)
						.textFieldStyle(.roundedBorder)
						.frame(width: 90)
						.font(.system(size: 11))
					}
				}
				physicsVectorRow(
					label: "Inertia",
					unit: "kg·m²",
					value: stringBinding(for: "m_inertia", fallback: "(0.1, 0.1, 0.1)")
				)

				physicsSubsection(title: "Center of Mass", isExpanded: $isCenterOfMassExpanded) {
					physicsVectorRow(
						label: "Position",
						unit: "cm",
						value: stringBinding(for: "position", fallback: "(0, 0, 0)")
					)
					physicsQuaternionRow(
						label: "Orientation",
						value: stringBinding(for: "orientation", fallback: "(1, 0, 0, 0)")
					)
				}
			}

			physicsSubsection(title: "Movement Locking", isExpanded: $isMovementLockingExpanded) {
				physicsLockingRow(
					label: "Translation Locked",
					x: boolBinding(for: "lockTranslationX", fallback: false),
					y: boolBinding(for: "lockTranslationY", fallback: false),
					z: boolBinding(for: "lockTranslationZ", fallback: false)
				)
				physicsLockingRow(
					label: "Rotation Locked",
					x: boolBinding(for: "lockRotationX", fallback: false),
					y: boolBinding(for: "lockRotationY", fallback: false),
					z: boolBinding(for: "lockRotationZ", fallback: false)
				)
			}
		}
	}

	private func physicsSubsection<Content: View>(
		title: String,
		isExpanded: Binding<Bool>,
		@ViewBuilder content: () -> Content
	) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Button(action: { isExpanded.wrappedValue.toggle() }) {
				HStack(spacing: 6) {
					Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
						.font(.system(size: 9))
						.foregroundStyle(.secondary)
					Text(title)
						.font(.system(size: 11, weight: .semibold))
					Spacer()
				}
			}
			.buttonStyle(.plain)
			if isExpanded.wrappedValue {
				content()
			}
		}
	}

	private func physicsVectorRow(label: String, unit: String, value: Binding<String>) -> some View {
		let components = Self.parseVector3(value.wrappedValue)
		return InspectorRow(label: label) {
			HStack(spacing: 6) {
				if !unit.isEmpty {
					Text(unit)
						.font(.system(size: 10))
						.foregroundStyle(.secondary)
				}
				physicsAxisTextField(label: "X", value: components.x) { x in
					value.wrappedValue = Self.formatVector3(x: x, y: components.y, z: components.z)
				}
				physicsAxisTextField(label: "Y", value: components.y) { y in
					value.wrappedValue = Self.formatVector3(x: components.x, y: y, z: components.z)
				}
				physicsAxisTextField(label: "Z", value: components.z) { z in
					value.wrappedValue = Self.formatVector3(x: components.x, y: components.y, z: z)
				}
			}
		}
	}

	private func physicsQuaternionRow(label: String, value: Binding<String>) -> some View {
		let parsed = Self.parseQuaternionComponents(value.wrappedValue)
		return InspectorRow(label: label) {
			HStack(spacing: 6) {
				physicsAxisTextField(label: "X", value: parsed.xyz.x) { x in
					value.wrappedValue = Self.formatQuaternionLiteral(
						w: parsed.w,
						x: x,
						y: parsed.xyz.y,
						z: parsed.xyz.z
					)
				}
				physicsAxisTextField(label: "Y", value: parsed.xyz.y) { y in
					value.wrappedValue = Self.formatQuaternionLiteral(
						w: parsed.w,
						x: parsed.xyz.x,
						y: y,
						z: parsed.xyz.z
					)
				}
				physicsAxisTextField(label: "Z", value: parsed.xyz.z) { z in
					value.wrappedValue = Self.formatQuaternionLiteral(
						w: parsed.w,
						x: parsed.xyz.x,
						y: parsed.xyz.y,
						z: z
					)
				}
			}
		}
	}

	private func physicsAxisTextField(
		label: String,
		value: Double,
		onCommit: @escaping (Double) -> Void
	) -> some View {
		EditableAxisField(value: value, label: label, onCommit: onCommit)
	}

	private func physicsLockingRow(
		label: String,
		x: Binding<Bool>,
		y: Binding<Bool>,
		z: Binding<Bool>
	) -> some View {
		InspectorRow(label: label) {
			HStack(spacing: 8) {
				Toggle("X", isOn: x)
					.toggleStyle(.checkbox)
					.font(.system(size: 11))
				Toggle("Y", isOn: y)
					.toggleStyle(.checkbox)
					.font(.system(size: 11))
				Toggle("Z", isOn: z)
					.toggleStyle(.checkbox)
					.font(.system(size: 11))
			}
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

	private func isColorParameter(_ key: String) -> Bool {
		guard key == "color" else { return false }
		guard let componentIdentifier else { return false }
		return componentIdentifier == "RealityKit.PointLight"
			|| componentIdentifier == "RealityKit.SpotLight"
			|| componentIdentifier == "RealityKit.DirectionalLight"
	}

	private func colorBinding(for key: String, fallback: String) -> Binding<Color> {
		Binding(
			get: {
				let raw: String
				if case let .string(value)? = values[key] {
					raw = value
				} else {
					raw = fallback
				}
				let rgb = Self.parseColorLiteral(raw)
				return Color(red: rgb.x, green: rgb.y, blue: rgb.z)
			},
			set: { color in
				#if os(macOS)
				let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
				let literal = Self.formatVector3(
					x: ns.redComponent,
					y: ns.greenComponent,
					z: ns.blueComponent
				)
				#else
				let literal = fallback
				#endif
				values[key] = .string(literal)
				notifyParameterChange(key: key, value: .string(literal))
			}
		)
	}

		private func shouldDisplay(parameter: InspectorComponentParameter) -> Bool {
			guard componentIdentifier == "RealityKit.Collider" else { return true }
			let shape = currentStringValue(for: "shape", fallback: "Box")
			switch parameter.key {
			case "extent":
				return shape == "Box"
			case "radius":
				return shape == "Sphere" || shape == "Capsule"
			case "height":
				return shape == "Capsule"
			default:
				return true
			}
		}

		private func currentStringValue(for key: String, fallback: String) -> String {
			if case let .string(value)? = values[key] {
				return value
			}
			return fallback
		}

	private func rawBinding(for key: String, fallback: String) -> Binding<String> {
		Binding(
			get: { rawValues[key] ?? fallback },
			set: { rawValues[key] = $0 }
		)
	}

	private static func inferAttributeType(name: String, literal: String) -> String {
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

	private static func inferredTypeMap(
		for attributes: [USDPrimAttributes.AuthoredAttribute]
	) -> [String: String] {
		var result: [String: String] = [:]
		for attribute in attributes {
			result[attribute.name] = Self.inferAttributeType(name: attribute.name, literal: attribute.value)
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

	private func parseUSDStringArray(_ raw: String) -> [String] {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return [] }
		if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
			let body = String(trimmed.dropFirst().dropLast())
			return body.split(separator: ",", omittingEmptySubsequences: true).map { token in
				Self.parseUSDString(String(token).trimmingCharacters(in: .whitespacesAndNewlines))
			}
		}
		if trimmed.hasPrefix("("), trimmed.hasSuffix(")"), trimmed.count >= 2 {
			let body = String(trimmed.dropFirst().dropLast())
			return body.split(separator: ",", omittingEmptySubsequences: true).map { token in
				Self.parseUSDString(String(token).trimmingCharacters(in: .whitespacesAndNewlines))
			}
		}
		return [Self.parseUSDString(trimmed)]
	}

	private func parseUSDRelationshipTargets(_ raw: String) -> [String] {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
			let body = String(trimmed.dropFirst().dropLast())
			return body
				.split(separator: ",", omittingEmptySubsequences: true)
				.map { Self.parseUSDRelationshipTarget(String($0)) }
				.filter { !$0.isEmpty }
		}
		let single = Self.parseUSDRelationshipTarget(trimmed)
		return single.isEmpty ? [] : [single]
	}

	private func selectAudioFileURL() -> URL? {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [.audio]
		panel.prompt = "Add"
		return panel.runModal() == .OK ? panel.url : nil
	}

	private func selectAnimationFileURL() -> URL? {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [
			UTType(filenameExtension: "usda"),
			UTType(filenameExtension: "usdc"),
			UTType(filenameExtension: "usdz"),
		].compactMap { $0 }
		panel.prompt = "Add"
		return panel.runModal() == .OK ? panel.url : nil
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
		if identifier == "RealityKit.MeshSorting", parameter.key == "group" {
			let raw = authoredAttributes["group"] ?? "None"
			let target = parseUSDRelationshipTarget(raw)
			return .string(target.isEmpty ? "None" : target)
		}
		if identifier == "RealityKit.InputTarget" {
			switch parameter.key {
			case "enabled":
				if let raw = authoredAttributes["enabled"] {
					return .bool(parseUSDBool(raw) ?? true)
				}
				return .bool(true)
			case "allowedInput":
				let allowsDirect = parseUSDBool(authoredAttributes["allowsDirectInput"] ?? "")
				let allowsIndirect = parseUSDBool(authoredAttributes["allowsIndirectInput"] ?? "")
				switch (allowsDirect, allowsIndirect) {
				case (.some(true), .some(false)):
					return .string("Direct")
				case (.some(false), .some(true)):
					return .string("Indirect")
				default:
					return .string("All")
				}
			default:
				break
			}
		}
		if identifier == "RealityKit.Anchoring" {
			let targetRaw = parseUSDString(authoredAttributes["type"] ?? "")
			let targetValue = targetRaw.isEmpty ? "World" : targetRaw
			let transform = parseAnchoringTransform(authoredAttributes["transform"] ?? "")
			switch parameter.key {
			case "target":
				return .string(targetValue)
			case "position":
				let position = transform?.positionMeters ?? SIMD3<Double>(0, 0, 0)
				return .string(
					formatVector3(
						x: position.x * 100.0,
						y: position.y * 100.0,
						z: position.z * 100.0
					)
				)
			case "orientation":
				let rotation = transform?.orientationDegrees ?? SIMD3<Double>(0, 0, 0)
				return .string(formatVector3(x: rotation.x, y: rotation.y, z: rotation.z))
			case "scale":
				let scale = transform?.scale ?? SIMD3<Double>(1, 1, 1)
				return .string(formatVector3(x: scale.x, y: scale.y, z: scale.z))
			default:
				break
			}
		}
		if identifier == "RealityKit.CustomDockingRegion" {
			switch parameter.key {
			case "width":
				let maxBounds = parseVector3(authoredAttributes["max"] ?? "(1.2, 0.5, 0)")
				let minBounds = parseVector3(authoredAttributes["min"] ?? "(-1.2, -0.5, 0)")
				let widthCM = max(0.0, (maxBounds.x - minBounds.x) * 100.0)
				return .double(widthCM)
			default:
				break
			}
		}
		if identifier == "RealityKit.CharacterController" {
			switch parameter.key {
			case "height":
				let extents = parseVector3(authoredAttributes["extents"] ?? "(0, 0, 0)")
				return .double(extents.x * 100.0)
			case "radius":
				let extents = parseVector3(authoredAttributes["extents"] ?? "(0, 0, 0)")
				return .double(extents.y * 100.0)
			case "skinWidth":
				let meters = parseUSDDouble(authoredAttributes["skinWidth"] ?? "") ?? 0.01
				return .double(meters * 100.0)
			case "stepLimit":
				let meters = parseUSDDouble(authoredAttributes["stepLimit"] ?? "") ?? 0.2
				return .double(meters * 100.0)
			case "slopeLimit":
				let radians = parseUSDDouble(authoredAttributes["slopeLimit"] ?? "") ?? (45.0 * .pi / 180.0)
				return .double(radians * 180.0 / .pi)
			case "group":
				let group = parseUSDDouble(authoredAttributes["group"] ?? "") ?? 1
				return .string(group >= 4_294_967_295 ? "All" : "Default")
			case "mask":
				let mask = parseUSDDouble(authoredAttributes["mask"] ?? "") ?? 1
				return .string(mask >= 4_294_967_295 ? "All" : "Default")
			case "upVector":
				return .string("(0, 1, 0)")
			default:
				break
			}
		}
		if identifier == "RealityKit.Collider" {
			switch parameter.key {
			case "mode":
				let rawMode = parseUSDString(authoredAttributes["type"] ?? "")
				return .string(rawMode.isEmpty ? "Default" : rawMode)
			case "shape":
				let rawShape = parseUSDString(authoredAttributes["shapeType"] ?? "")
				return .string(rawShape.isEmpty ? "Box" : rawShape)
			case "extent":
				let extents = parseVector3(authoredAttributes["extent"] ?? "(0.2, 0.2, 0.2)")
				return .string(formatVector3(x: extents.x * 100.0, y: extents.y * 100.0, z: extents.z * 100.0))
			case "radius":
				let meters = parseUSDDouble(authoredAttributes["radius"] ?? "") ?? 0.1
				return .double(meters * 100.0)
			case "height":
				let meters = parseUSDDouble(authoredAttributes["height"] ?? "") ?? 0.2
				return .double(meters * 100.0)
			case "group":
				let group = parseUSDDouble(authoredAttributes["group"] ?? "") ?? 1
				return .string(group >= 4_294_967_295 ? "All" : "Default")
			case "mask":
				let mask = parseUSDDouble(authoredAttributes["mask"] ?? "") ?? 4_294_967_295
				return .string(mask >= 4_294_967_295 ? "All" : "Default")
			default:
				break
			}
		}
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
		case ("RealityKit.Accessibility", "isAccessibilityElement"):
			return "isEnabled"
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
		case ("RealityKit.DirectionalLight", "shadowEnabled"):
			return "isEnabled"
		case ("RealityKit.DirectionalLight", "shadowBias"):
			return "depthBias"
		case ("RealityKit.DirectionalLight", "shadowCullMode"):
			return "cullMode"
		case ("RealityKit.DirectionalLight", "shadowProjectionType"):
			return "projectionType"
		case ("RealityKit.DirectionalLight", "shadowOrthographicScale"):
			return "orthographicScale"
			case ("RealityKit.DirectionalLight", "shadowZBounds"):
				return "zBounds"
			case ("RealityKit.MotionState", "linearVelocity"):
				return "m_userSetLinearVelocity"
			case ("RealityKit.MotionState", "angularVelocity"):
				return "m_userSetAngularVelocity"
			case ("RealityKit.Collider", "mode"):
				return "type"
			case ("RealityKit.Collider", "shape"):
				return "shapeType"
			default:
				return key
			}
		}

	private static func parseVector3(_ raw: String) -> SIMD3<Double> {
		let values = parseTuple(raw)
		guard values.count >= 3 else { return SIMD3<Double>(0, 0, 0) }
		return SIMD3<Double>(values[0], values[1], values[2])
	}

	private static func formatVector3(x: Double, y: Double, z: Double) -> String {
		"(\(formatComponent(x)), \(formatComponent(y)), \(formatComponent(z)))"
	}

	private static func parseQuaternionComponents(_ raw: String) -> (w: Double, xyz: SIMD3<Double>) {
		let values = parseTuple(raw)
		guard values.count >= 4 else { return (1, SIMD3<Double>(0, 0, 0)) }
		return (values[0], SIMD3<Double>(values[1], values[2], values[3]))
	}

	private static func formatQuaternionLiteral(w: Double, x: Double, y: Double, z: Double) -> String {
		"(\(formatComponent(w)), \(formatComponent(x)), \(formatComponent(y)), \(formatComponent(z)))"
	}

	private static func parseTuple(_ raw: String) -> [Double] {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.hasPrefix("("), trimmed.hasSuffix(")"), trimmed.count >= 2 else { return [] }
		let body = String(trimmed.dropFirst().dropLast())
		return body
			.split(separator: ",", omittingEmptySubsequences: true)
			.compactMap { parseUSDDouble(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
	}

	private static func parseAnchoringTransform(_ raw: String) -> (
		positionMeters: SIMD3<Double>,
		orientationDegrees: SIMD3<Double>,
		scale: SIMD3<Double>
	)? {
		let values = parseNumericSequence(raw)
		guard values.count >= 16 else { return nil }

		let r0 = SIMD3<Double>(values[0], values[1], values[2])
		let r1 = SIMD3<Double>(values[4], values[5], values[6])
		let r2 = SIMD3<Double>(values[8], values[9], values[10])

		let sx = max(0.000_001, sqrt(r0.x * r0.x + r0.y * r0.y + r0.z * r0.z))
		let sy = max(0.000_001, sqrt(r1.x * r1.x + r1.y * r1.y + r1.z * r1.z))
		let sz = max(0.000_001, sqrt(r2.x * r2.x + r2.y * r2.y + r2.z * r2.z))
		let scale = SIMD3<Double>(sx, sy, sz)

		let m11 = r0.x / sx
		let m12 = r0.y / sx
		let m13 = r0.z / sx
		let m23 = r1.z / sy
		let m33 = r2.z / sz

		let yRadians = asin(max(-1.0, min(1.0, -m13)))
		let cosY = cos(yRadians)
		let xRadians: Double
		let zRadians: Double
		if Swift.abs(cosY) > 0.000_001 {
			xRadians = atan2(m23, m33)
			zRadians = atan2(m12, m11)
		} else {
			xRadians = atan2(-r2.y / sz, r1.y / sy)
			zRadians = 0
		}

		let orientationDegrees = SIMD3<Double>(
			xRadians * 180.0 / .pi,
			yRadians * 180.0 / .pi,
			zRadians * 180.0 / .pi
		)
		let positionMeters = SIMD3<Double>(values[12], values[13], values[14])
		return (positionMeters, orientationDegrees, scale)
	}

	private static func parseNumericSequence(_ raw: String) -> [Double] {
		let pattern = #"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"#
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
		let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
		return regex.matches(in: raw, options: [], range: range).compactMap { match in
			guard let swiftRange = Range(match.range, in: raw) else { return nil }
			return Double(raw[swiftRange])
		}
	}

	private static func formatComponent(_ value: Double) -> String {
		let formatted = String(format: "%.6f", value)
		return formatted.replacingOccurrences(
			of: #"(\.\d*?[1-9])0+$|\.0+$"#,
			with: "$1",
			options: .regularExpression
		)
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
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		if let direct = Double(trimmed) {
			return direct
		}
		let pattern = #"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"#
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
		let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
		guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
			  let swiftRange = Range(match.range, in: trimmed)
		else {
			return nil
		}
		return Double(trimmed[swiftRange])
	}

	private static func parseColorLiteral(_ raw: String) -> SIMD3<Double> {
		let tuple = parseTuple(raw)
		guard tuple.count >= 3 else { return SIMD3<Double>(1, 1, 1) }
		return SIMD3<Double>(
			max(0, min(1, tuple[0])),
			max(0, min(1, tuple[1])),
			max(0, min(1, tuple[2]))
		)
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

	private static func parseUSDRelationshipTarget(_ raw: String) -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), trimmed.count >= 2 {
			return String(trimmed.dropFirst().dropLast())
		}
		return trimmed
	}

	private static func authoredLiteral(
		in attributes: [USDPrimAttributes.AuthoredAttribute],
		names: [String]
	) -> String {
		let lowered = Set(names.map { $0.lowercased() })
		if let exact = attributes.first(where: { lowered.contains($0.name.lowercased()) }) {
			return exact.value
		}
		if let typed = attributes.first(where: { attribute in
			let key = attribute.name.lowercased()
			return lowered.contains(where: { key.hasSuffix(" \($0)") })
		}) {
			return typed.value
		}
		if let loose = attributes.first(where: { attribute in
			let key = attribute.name.lowercased()
			return lowered.contains(where: { key.contains($0) })
		}) {
			return loose.value
		}
		return ""
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
