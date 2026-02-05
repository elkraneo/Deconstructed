import ComposableArchitecture
import DeconstructedUSDInterop
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
											metersPerUnit: store.layerData?.metersPerUnit
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

struct TransformSection: View {
	let transform: TransformData
	let metersPerUnit: Double?
	@State private var isExpanded: Bool = true

	private var lengthUnitLabel: String {
		guard let metersPerUnit else { return "m" }
		if abs(metersPerUnit - 0.01) < 0.0001 { return "cm" }
		return "m"
	}

	var body: some View {
		InspectorGroupBox(title: "Transform", isExpanded: $isExpanded) {
			VStack(alignment: .leading, spacing: 10) {
				TransformRow(
					label: "Position",
					unit: lengthUnitLabel,
					values: transform.position
				)
				TransformRow(
					label: "Rotation",
					unit: "°",
					values: transform.rotationDegrees
				)
				TransformRow(
					label: "Scale",
					unit: "",
					values: transform.scale
				)
			}
		}
	}
}

private struct TransformRow: View {
	let label: String
	let unit: String
	let values: SIMD3<Double>

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

			axisField(values.x, label: "X")
			axisField(values.y, label: "Y")
			axisField(values.z, label: "Z")
		}
	}

	private func axisField(_ value: Double, label: String) -> some View {
		Text(formatNumber(value))
			.font(.system(size: 11, weight: .medium))
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
	}

	private func formatNumber(_ value: Double) -> String {
		if abs(value) < 0.0001 { return "0" }
		return String(format: "%.2f", value)
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
