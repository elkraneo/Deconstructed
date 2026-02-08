import ComposableArchitecture
import AppKit
import Foundation
import InspectorFeature
import InspectorModels
import SceneGraphModels
import SwiftUI
import USDInterfaces

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
								VStack(alignment: .leading, spacing: 16) {
									PrimDataSection(node: selectedNode)

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

									if store.primIsLoading {
										ProgressView()
											.frame(maxWidth: .infinity, alignment: .center)
											.padding(.vertical, 8)
									} else if let message = store.primErrorMessage {
										Text(message)
											.font(.caption)
											.foregroundStyle(.secondary)
									} else if let primAttributes = store.primAttributes {
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
	@State private var isExpanded: Bool = true

	var body: some View {
		InspectorGroupBox(title: "Prim", isExpanded: $isExpanded) {
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
}

struct PrimAttributesSection: View {
	let attributes: USDPrimAttributes
	@State private var isExpanded: Bool = true

	var body: some View {
		InspectorGroupBox(title: "Properties", isExpanded: $isExpanded) {
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
}

struct MaterialBindingsSection: View {
	let currentBindingPath: String?
	let currentStrength: USDMaterialBindingStrength?
	let boundMaterial: USDMaterialInfo?
	let materials: [USDMaterialInfo]
	let onSetBinding: (String?) -> Void
	let onSetStrength: (USDMaterialBindingStrength) -> Void
	@State private var isExpanded: Bool = true
	@State private var selection: String = ""
	@State private var strengthSelection: USDMaterialBindingStrength = .fallbackStrength

	var body: some View {
		InspectorGroupBox(title: "Material Bindings", isExpanded: $isExpanded) {
			VStack(alignment: .leading, spacing: 12) {
				InspectorRow(label: "Binding") {
					HStack(spacing: 8) {
						Picker("", selection: $selection) {
							Text("None").tag("")
							ForEach(materials, id: \.path) { material in
								Text(material.name.isEmpty ? material.path : material.name)
									.tag(material.path)
							}
						}
						.labelsHidden()
						.pickerStyle(.menu)
						.onChange(of: selection) { _, newValue in
							// Avoid re-authoring when we're just syncing to the latest loaded binding.
							if newValue == (currentBindingPath ?? "") { return }
							onSetBinding(newValue.isEmpty ? nil : newValue)
						}

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

				if let currentBindingPath, !currentBindingPath.isEmpty {
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

					Text(currentBindingPath)
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
					if let currentBindingPath, !currentBindingPath.isEmpty {
						Text("Material properties unavailable (material list did not include the bound path).")
							.font(.system(size: 11))
							.foregroundStyle(.secondary)
					}
				}
			}
			.onAppear {
				selection = currentBindingPath ?? ""
				strengthSelection = currentStrength ?? .fallbackStrength
			}
			.onChange(of: currentBindingPath) { _, newValue in
				selection = newValue ?? ""
			}
			.onChange(of: currentStrength) { _, newValue in
				strengthSelection = newValue ?? .fallbackStrength
			}
		}
	}
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
	@State private var isExpanded: Bool = true
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
		InspectorGroupBox(title: "Transform", isExpanded: $isExpanded) {
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

	private static let numberFormat = FloatingPointFormatStyle<Double>.number
		.precision(.fractionLength(0...3))

	var body: some View {
		TextField(label, text: $text)
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
				text = newValue.formatted(Self.numberFormat)
			}
			.onSubmit {
				commit()
			}
	}

	private func commit() {
		let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let parsed = try? Self.numberFormat.parseStrategy.parse(normalized) else {
			text = value.formatted(Self.numberFormat)
			return
		}
		onCommit(parsed)
		text = parsed.formatted(Self.numberFormat)
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
	@State private var isExpanded: Bool = true

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
		InspectorGroupBox(title: "Scene Playback", isExpanded: $isExpanded) {
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
				.padding(8)
				.background(.quaternary.opacity(0.4))
				.clipShape(RoundedRectangle(cornerRadius: 8))
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
}

struct LayerDataSection: View {
	let layerData: SceneLayerData
	let onDefaultPrimChanged: (String) -> Void
	let onMetersPerUnitChanged: (Double) -> Void
	let onUpAxisChanged: (UpAxis) -> Void
	let onConvertVariantsTapped: () -> Void
	@State private var isExpanded: Bool = true

	var body: some View {
		InspectorGroupBox(title: "Layer Data", isExpanded: $isExpanded) {
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
					.padding(.horizontal, 6)
					.padding(.vertical, 4)
					.background(.quaternary.opacity(0.5))
					.clipShape(RoundedRectangle(cornerRadius: 6))
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
					.padding(.horizontal, 6)
					.padding(.vertical, 4)
					.background(.quaternary.opacity(0.5))
					.clipShape(RoundedRectangle(cornerRadius: 6))
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
					.padding(.horizontal, 6)
					.padding(.vertical, 4)
					.background(.quaternary.opacity(0.5))
					.clipShape(RoundedRectangle(cornerRadius: 6))
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
