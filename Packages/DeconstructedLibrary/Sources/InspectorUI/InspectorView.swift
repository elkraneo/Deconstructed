import ComposableArchitecture
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

struct PrimDataSection: View {
	let node: SceneNode
	@State private var isExpanded: Bool = true

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Button(action: { isExpanded.toggle() }) {
				HStack(spacing: 4) {
					Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
						.font(.system(size: 10))
						.foregroundStyle(.secondary)
					Text("Prim")
						.font(.system(size: 12, weight: .semibold))
					Spacer()
				}
			}
			.buttonStyle(.plain)

			if isExpanded {
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
}

struct PrimAttributesSection: View {
	let attributes: USDPrimAttributes
	@State private var isExpanded: Bool = true

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Button(action: { isExpanded.toggle() }) {
				HStack(spacing: 4) {
					Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
						.font(.system(size: 10))
						.foregroundStyle(.secondary)
					Text("Properties")
						.font(.system(size: 12, weight: .semibold))
					Spacer()
				}
			}
			.buttonStyle(.plain)

			if isExpanded {
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
}

struct LayerDataSection: View {
	let layerData: SceneLayerData
	let onDefaultPrimChanged: (String) -> Void
	let onMetersPerUnitChanged: (Double) -> Void
	let onUpAxisChanged: (UpAxis) -> Void
	let onConvertVariantsTapped: () -> Void
	@State private var isExpanded: Bool = true

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Button(action: { isExpanded.toggle() }) {
				HStack(spacing: 4) {
					Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
						.font(.system(size: 10))
						.foregroundStyle(.secondary)
					Text("Layer Data")
						.font(.system(size: 12, weight: .semibold))
					Spacer()
				}
			}
			.buttonStyle(.plain)

			if isExpanded {
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
						.textFieldStyle(.roundedBorder)
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
				}
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
