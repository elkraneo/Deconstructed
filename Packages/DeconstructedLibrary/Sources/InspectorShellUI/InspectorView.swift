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
	let onDescendantChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void
	let onActiveToggle: (Bool) -> Void
	let onDelete: () -> Void
	let onPaste: (String) -> Void
	let onOpenAudioMixer: () -> Void

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

			descendantEditor
		} label: {
			LabeledContent(component.name, value: definition?.name ?? component.typeName)
		}
	}

	@ViewBuilder
	private var descendantEditor: some View {
		switch componentIdentifier {
		case "RealityKit.AudioMixGroups":
			InlineAudioMixGroupsEditor(
				component: component,
				onParameterChange: onDescendantChange,
				onOpenAudioMixer: onOpenAudioMixer
			)
		case "RealityKit.AnimationLibrary":
			AnimationLibraryEditor(
				component: component,
				onParameterChange: onDescendantChange
			)
		case "RCP.BehaviorsContainer":
			BehaviorsEditor(
				component: component,
				onParameterChange: onDescendantChange
			)
		case "RealityKit.RigidBody", "RealityKit.PhysicsBody":
			PhysicsBodyEditor(
				component: component,
				onParameterChange: onDescendantChange
			)
		case "RealityKit.VFXEmitter":
			ParticleEmitterEditor(
				component: component,
				onParameterChange: onDescendantChange
			)
		case "RealityKit.CustomDockingRegion":
			CustomDockingRegionEditor(
				component: component,
				onParameterChange: onDescendantChange
			)
		default:
			if !component.descendants.isEmpty {
				GenericDescendantEditor(
					descendants: component.descendants,
					onParameterChange: onDescendantChange
				)
			}
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

// MARK: - Audio Mix Groups Editor

private func parseUSDRelationshipTargets(_ raw: String) -> [String] {
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

private func parseUSDRelationshipTargetLiteral(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), trimmed.count >= 2 {
		return String(trimmed.dropFirst().dropLast())
	}
	return trimmed
}

private func parseUSDAssetPathLiteral(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.count >= 2, trimmed.first == "@", trimmed.last == "@" else {
		return trimmed
	}
	let start = trimmed.index(after: trimmed.startIndex)
	let end = trimmed.index(before: trimmed.endIndex)
	return String(trimmed[start..<end])
}

private struct InlineAudioMixGroupsEditor: View {
	let component: InspectorComponentSummary
	let onParameterChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void
	let onOpenAudioMixer: () -> Void

	@State private var selectedGroupPath: String?

	private struct AssignedFile: Identifiable {
		let path: String
		let displayName: String
		let mixGroupTarget: String
		var id: String { path }
	}

	private struct MixGroupModel: Identifiable {
		let path: String
		let displayName: String
		let gain: Double
		let mute: Bool
		let speed: Double
		let assignedFiles: [AssignedFile]
		var id: String { path }
	}

	private var assignedFiles: [AssignedFile] {
		component.descendants.compactMap { descendant in
			let fileLiteral = descendant.authoredAttributes.first { $0.name == "file" }?.value ?? ""
			guard !fileLiteral.isEmpty else { return nil }
			let mixGroupLiteral = descendant.authoredAttributes.first { $0.name == "mixGroup" }?.value ?? ""
			let target = parseUSDRelationshipTargets(mixGroupLiteral).first ?? ""
			guard !target.isEmpty else { return nil }
			let relativeAssetPath = parseUSDAssetPathLiteral(fileLiteral)
			let displayName = URL(fileURLWithPath: relativeAssetPath).lastPathComponent
			return AssignedFile(
				path: descendant.path,
				displayName: displayName.isEmpty ? descendant.name : displayName,
				mixGroupTarget: target
			)
		}
	}

	private var mixGroups: [MixGroupModel] {
		let files = assignedFiles
		return component.descendants.compactMap { descendant -> MixGroupModel? in
			let fileLiteral = descendant.authoredAttributes.first { $0.name == "file" }?.value ?? ""
			guard fileLiteral.isEmpty else { return nil }
			let gainLiteral = descendant.authoredAttributes.first { $0.name == "gain" }?.value ?? ""
			let muteLiteral = descendant.authoredAttributes.first { $0.name == "mute" }?.value ?? ""
			let speedLiteral = descendant.authoredAttributes.first { $0.name == "speed" }?.value ?? ""
			guard !gainLiteral.isEmpty || !muteLiteral.isEmpty || !speedLiteral.isEmpty else {
				return nil
			}
			return MixGroupModel(
				path: descendant.path,
				displayName: descendant.name,
				gain: Double(gainLiteral.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
				mute: parseBool(muteLiteral) ?? false,
				speed: Double(speedLiteral.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1,
				assignedFiles: files
					.filter { $0.mixGroupTarget == descendant.path }
					.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
			)
		}
		.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
	}

	var body: some View {
		let groups = mixGroups
		let selectedGroup = groups.first(where: { $0.path == selectedGroupPath }) ?? groups.first

		HStack(alignment: .top, spacing: 16) {
			VStack(alignment: .leading, spacing: 12) {
				HStack(spacing: 8) {
					Text("Audio Mix Groups")
						.font(.system(size: 12, weight: .semibold))
					Spacer()
					Button(action: onOpenAudioMixer) {
						Image(systemName: "slider.horizontal.3")
							.font(.system(size: 12, weight: .medium))
					}
					.buttonStyle(.plain)
					.help("Open Audio Mixer")
				}

				if groups.isEmpty {
					Text("No mix groups.")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				} else {
					ScrollView {
						VStack(alignment: .leading, spacing: 8) {
							ForEach(groups) { group in
								VStack(alignment: .leading, spacing: 4) {
									HStack(spacing: 8) {
										Image(systemName: "slider.horizontal.3")
											.font(.system(size: 11))
											.foregroundStyle(.secondary)
										Text(group.displayName)
											.font(.system(size: 11, weight: .semibold))
										Spacer()
									}
									.padding(.horizontal, 8)
									.padding(.vertical, 6)
									.frame(maxWidth: .infinity, alignment: .leading)
									.background(
										group.path == selectedGroup?.path
											? Color.accentColor.opacity(0.15)
											: Color.clear
									)
									.clipShape(RoundedRectangle(cornerRadius: 6))
									.contentShape(RoundedRectangle(cornerRadius: 6))
									.onTapGesture {
										selectedGroupPath = group.path
									}

									if group.path == selectedGroup?.path {
										if group.assignedFiles.isEmpty {
											Text("No audio assigned.")
												.font(.system(size: 11))
												.foregroundStyle(.secondary)
												.padding(.leading, 20)
										} else {
											ForEach(group.assignedFiles) { file in
												HStack(spacing: 8) {
													Image(systemName: "waveform")
														.font(.system(size: 11))
														.foregroundStyle(.cyan)
													Text(file.displayName)
														.font(.system(size: 11))
														.lineLimit(1)
													Spacer(minLength: 0)
												}
												.padding(.leading, 20)
											}
										}
									}
								}
							}
						}
					}
				}
			}
			.frame(width: 210)

			Divider()

			VStack(alignment: .leading, spacing: 16) {
				if let selectedGroup {
					VStack(alignment: .leading, spacing: 12) {
						HStack {
							Text("Speed")
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
							Spacer()
							TextField(
								"",
								value: Binding(
									get: { selectedGroup.speed },
									set: { onParameterChange(selectedGroup.path, "float", "speed", String($0)) }
								),
								format: .number.precision(.fractionLength(0...3))
							)
							.textFieldStyle(.roundedBorder)
							.frame(width: 70)
							.font(.system(size: 11))
						}

						HStack {
							Text("dB")
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
							Spacer()
							TextField(
								"",
								value: Binding(
									get: { selectedGroup.gain },
									set: { onParameterChange(selectedGroup.path, "float", "gain", String($0)) }
								),
								format: .number.precision(.fractionLength(0...3))
							)
							.textFieldStyle(.roundedBorder)
							.frame(width: 70)
							.font(.system(size: 11))
						}

						VStack(spacing: 6) {
							Text("Level")
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
							Slider(
								value: Binding(
									get: { selectedGroup.gain },
									set: { onParameterChange(selectedGroup.path, "float", "gain", String($0)) }
								),
								in: -60...6
							)
							.rotationEffect(.degrees(-90))
							.frame(width: 32, height: 160)
						}

						Toggle(
							"Mute",
							isOn: Binding(
								get: { selectedGroup.mute },
								set: { onParameterChange(selectedGroup.path, "bool", "mute", $0 ? "1" : "0") }
							)
						)
						.font(.system(size: 11, weight: .semibold))
						.toggleStyle(.button)

						Text(selectedGroup.displayName)
							.font(.system(size: 11, weight: .semibold))
							.foregroundStyle(.secondary)
					}
					.padding(12)
					.frame(width: 180, alignment: .leading)
					.background(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.fill(Color(nsColor: .controlBackgroundColor))
					)
				} else {
					Text("Select a mix group to edit.")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.onAppear {
			if selectedGroupPath == nil {
				selectedGroupPath = mixGroups.first?.path
			}
		}
	}
}

// MARK: - Animation Library Editor

private struct AnimationLibraryEditor: View {
	let component: InspectorComponentSummary
	let onParameterChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void
	@State private var selectedResourcePath: String?

	private struct AnimationResource: Identifiable {
		let path: String
		let displayName: String
		let relativeAssetPath: String
		var id: String { path }
	}

	private var animationResources: [AnimationResource] {
		component.descendants.compactMap { descendant in
			let fileLiteral = descendant.authoredAttributes.first { $0.name == "file" }?.value ?? ""
			guard !fileLiteral.isEmpty else { return nil }
			let nameLiteral = stripUSDQuotes(
				descendant.authoredAttributes.first { $0.name == "name" }?.value ?? ""
			)
			let relativeAssetPath = parseUSDAssetPathLiteral(fileLiteral)
			let resolvedName: String = {
				if !nameLiteral.isEmpty { return nameLiteral }
				let lastComponent = URL(fileURLWithPath: relativeAssetPath).lastPathComponent
				return lastComponent.isEmpty ? descendant.name : lastComponent
			}()
			return AnimationResource(
				path: descendant.path,
				displayName: resolvedName,
				relativeAssetPath: relativeAssetPath
			)
		}
		.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
	}

	private func chooseAnimationFile() -> URL? {
		let panel = NSOpenPanel()
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [
			UTType(filenameExtension: "usd") ?? .data,
			UTType(filenameExtension: "usda") ?? .data,
			UTType(filenameExtension: "usdc") ?? .data,
			UTType(filenameExtension: "usdz") ?? .data,
			UTType(filenameExtension: "realityfile") ?? .data
		]
		panel.prompt = "Select"
		return panel.runModal() == .OK ? panel.url : nil
	}

	var body: some View {
		let resources = animationResources
		VStack(alignment: .leading, spacing: 8) {
			Text("Animation Resources").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)

			VStack(alignment: .leading, spacing: 0) {
				if resources.isEmpty {
					Text("No animation resources.")
						.font(.system(size: 11)).foregroundStyle(.secondary)
						.padding(10)
						.frame(maxWidth: .infinity, alignment: .leading)
				} else {
					ForEach(resources) { resource in
						Button {
							selectedResourcePath = resource.path
						} label: {
							HStack(spacing: 8) {
								Image(systemName: "film").font(.system(size: 11)).foregroundStyle(.cyan)
								Text(resource.displayName).font(.system(size: 11)).lineLimit(1)
								Spacer(minLength: 0)
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 6)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(
								selectedResourcePath == resource.path
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
					guard let url = chooseAnimationFile() else { return }
					// Author a new resource as an attribute on the component; the
					// USDA mutator inserts a child prim that the next reload picks
					// up as a fresh descendant.
					onParameterChange(component.path, "asset", "file", quoteUSDString(url.path))
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 12, weight: .medium))
				}
				.buttonStyle(.plain)

				Button {
					guard let path = selectedResourcePath else { return }
					// NOTE: removing an animation library resource requires a dedicated
					// shell action (removeAnimationLibraryResourceRequested) that does
					// not exist on the shell feature today. As a best-effort fallback we
					// clear the `file` attribute so the row drops out of the resource
					// list on the next reload. Replace with a real remove RPC when it
					// becomes available.
					onParameterChange(path, "asset", "file", "@@")
					selectedResourcePath = nil
				} label: {
					Image(systemName: "minus")
						.font(.system(size: 12, weight: .medium))
				}
				.buttonStyle(.plain)
				.disabled(selectedResourcePath == nil)

				Spacer()
			}
			.padding(.horizontal, 4)
		}
	}
}

// MARK: - Behaviors Editor

private struct BehaviorsEditor: View {
	let component: InspectorComponentSummary
	let onParameterChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void

	private struct BehaviorModel: Identifiable {
		let id: String
		let path: String
		let title: String
		let triggerPath: String?
		let triggerType: String?
		let colliders: [String]
		let actionPath: String?
		let actionType: String?
		let actionTargetPath: String?
		let notificationIdentifier: String?
	}

	private let triggerTypes = ["TapGesture", "Collide", "AddedToScene", "Notification"]
	private let actionTypes = ["PlayTimeline"]

	private func triggerLabel(_ type: String) -> String {
		switch type {
		case "TapGesture": return "OnTap"
		case "Collide": return "OnCollision"
		case "AddedToScene": return "OnAddedToScene"
		case "Notification": return "OnNotification"
		default: return type
		}
	}

	private func parseColliderCSV(_ input: String) -> [String] {
		input
			.replacingOccurrences(of: "<", with: "")
			.replacingOccurrences(of: ">", with: "")
			.split(separator: ",", omittingEmptySubsequences: true)
			.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	private func formatColliderTargets(_ paths: [String]) -> String {
		let targets = paths.map { "<\($0)>" }
		switch targets.count {
		case 0: return "None"
		case 1: return targets[0]
		default: return "[\(targets.joined(separator: ", "))]"
		}
	}

	private func parseBehaviors() -> [BehaviorModel] {
		var drafts: [String: BehaviorModel] = [:]
		var order: [String] = []
		for descendant in component.descendants {
			let p = descendant.path
			let (behaviorPath, kind): (String, String) = {
				if p.hasSuffix("/Trigger") { return (String(p.dropLast("/Trigger".count)), "trigger") }
				if p.hasSuffix("/Action") { return (String(p.dropLast("/Action".count)), "action") }
				return (p, "behavior")
			}()
			let attrs = Dictionary(uniqueKeysWithValues: descendant.authoredAttributes.map { ($0.name, $0.value) })
			if drafts[behaviorPath] == nil {
				let title = behaviorPath.split(separator: "/").last.map(String.init) ?? descendant.name
				drafts[behaviorPath] = BehaviorModel(
					id: behaviorPath, path: behaviorPath, title: title,
					triggerPath: nil, triggerType: nil, colliders: [],
					actionPath: nil, actionType: nil, actionTargetPath: nil,
					notificationIdentifier: nil
				)
				order.append(behaviorPath)
			}
			guard var m = drafts[behaviorPath] else { continue }
			switch kind {
			case "trigger":
				let tt = stripUSDQuotes(attrs["info:id"] ?? "")
				let cols = parseColliderCSV(attrs["colliders"] ?? "")
				let id = stripUSDQuotes(attrs["identifier"] ?? "")
				m = BehaviorModel(id: m.id, path: m.path, title: m.title,
					triggerPath: p, triggerType: tt.isEmpty ? "TapGesture" : tt,
					colliders: cols, actionPath: m.actionPath, actionType: m.actionType,
					actionTargetPath: m.actionTargetPath,
					notificationIdentifier: id.isEmpty ? nil : id)
			case "action":
				let at = stripUSDQuotes(attrs["info:id"] ?? "")
				let target = parseColliderCSV(attrs["animationLibraryKeyOverrideKey"] ?? "").first
				m = BehaviorModel(id: m.id, path: m.path, title: m.title,
					triggerPath: m.triggerPath, triggerType: m.triggerType, colliders: m.colliders,
					actionPath: p, actionType: at.isEmpty ? "PlayTimeline" : at,
					actionTargetPath: target,
					notificationIdentifier: m.notificationIdentifier)
			default: break
			}
			drafts[behaviorPath] = m
		}
		return order.compactMap { drafts[$0] }
	}

	private func actionTargetOptions(from models: [BehaviorModel]) -> [String] {
		var options: [String] = ["None"]
		for model in models {
			if let triggerPath = model.triggerPath, !options.contains(triggerPath) {
				options.append(triggerPath)
			}
		}
		return options
	}

	var body: some View {
		let behaviors = parseBehaviors()
		VStack(alignment: .leading, spacing: 8) {
			if behaviors.isEmpty {
				Text("No behaviors authored yet.").font(.system(size: 11)).foregroundStyle(.secondary)
			} else {
				ForEach(behaviors) { behavior in
					VStack(alignment: .leading, spacing: 6) {
						Text(behavior.title).font(.system(size: 11, weight: .semibold))
						if let triggerPath = behavior.triggerPath {
							LabeledContent("Trigger") {
								Picker("", selection: Binding(
									get: { behavior.triggerType ?? "TapGesture" },
									set: { onParameterChange(triggerPath, "token", "info:id", quoteUSDString($0)) }
								)) {
									ForEach(triggerTypes, id: \.self) { t in Text(triggerLabel(t)).tag(t) }
								}
								.labelsHidden()
							}
							if behavior.triggerType == "Collide" {
								LabeledContent("Colliders") {
									TextField("/Root/A, /Root/B", text: Binding(
										get: { behavior.colliders.joined(separator: ", ") },
										set: { onParameterChange(triggerPath, "rel", "colliders", formatColliderTargets(parseColliderCSV($0))) }
									))
									.textFieldStyle(.roundedBorder)
								}
							}
							if behavior.triggerType == "Notification" {
								LabeledContent("Identifier") {
									TextField("", text: Binding(
										get: { behavior.notificationIdentifier ?? "" },
										set: { onParameterChange(triggerPath, "string", "identifier", quoteUSDString($0)) }
									))
									.textFieldStyle(.roundedBorder)
								}
							}
						}
						if let actionPath = behavior.actionPath {
							LabeledContent("Action") {
								Picker("", selection: Binding(
									get: { behavior.actionType ?? "PlayTimeline" },
									set: { onParameterChange(actionPath, "token", "info:id", quoteUSDString($0)) }
								)) {
									ForEach(actionTypes, id: \.self) { a in Text(a).tag(a) }
								}
								.labelsHidden()
							}
							LabeledContent("Action Target") {
								Picker("", selection: Binding(
									get: { behavior.actionTargetPath ?? "None" },
									set: { newValue in
										let literal = newValue == "None" ? "None" : "<\(newValue)>"
										onParameterChange(actionPath, "rel", "animationLibraryKeyOverrideKey", literal)
									}
								)) {
									ForEach(actionTargetOptions(from: behaviors), id: \.self) { option in
										if option == "None" {
											Text("None").tag(option)
										} else {
											Text(option).tag(option)
										}
									}
								}
								.labelsHidden()
							}
						}
					}
					.padding(8)
					.background(.quaternary.opacity(0.35))
					.clipShape(RoundedRectangle(cornerRadius: 6))
				}
			}

			// NOTE: Creating new behavior prims requires runtime support that's not
			// yet wired through the shell. The Add menu writes a placeholder
			// `_addBehavior` attribute on the component path — the adapter currently
			// no-ops on unknown attribute names, so this is purely an intent signal
			// until the runtime gains a real createBehavior endpoint.
			Menu {
				ForEach(triggerTypes, id: \.self) { t in
					Button("Add \(triggerLabel(t))") {
						onParameterChange(component.path, "string", "_addBehavior", quoteUSDString(t))
					}
				}
			} label: {
				Label("Add Behavior", systemImage: "plus.circle")
					.font(.system(size: 11, weight: .semibold))
			}
			.menuStyle(.borderlessButton)
		}
	}
}

// MARK: - Physics Body Editor

private struct PhysicsBodyEditor: View {
	let component: InspectorComponentSummary
	let onParameterChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void

	@State private var materialExpanded = true
	@State private var massExpanded = true
	@State private var centerOfMassExpanded = false
	@State private var lockingExpanded = false

	private func value(_ name: String) -> String? {
		component.authoredAttributes.first { $0.name == name }?.value
	}

	private func parseVec3(_ s: String?) -> SIMD3<Double> {
		guard let s else { return .zero }
		let parts = s.trimmingCharacters(in: CharacterSet(charactersIn: "() "))
			.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
		guard parts.count == 3, let x = Double(parts[0]), let y = Double(parts[1]), let z = Double(parts[2]) else { return .zero }
		return SIMD3(x, y, z)
	}

	private func parseQuat(_ s: String?) -> SIMD4<Double> {
		guard let s else { return SIMD4(0, 0, 0, 1) }
		let parts = s.trimmingCharacters(in: CharacterSet(charactersIn: "() "))
			.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
		guard parts.count == 4, let x = Double(parts[0]), let y = Double(parts[1]), let z = Double(parts[2]), let w = Double(parts[3]) else { return SIMD4(0, 0, 0, 1) }
		return SIMD4(x, y, z, w)
	}

	private func scalarField(_ name: String, type: String, label: String) -> some View {
		LabeledContent(label) {
			TextField("", value: Binding(
				get: { Double(value(name) ?? "0") ?? 0 },
				set: { onParameterChange(component.path, type, name, String($0)) }
			), format: .number.precision(.fractionLength(0...3)))
			.textFieldStyle(.roundedBorder)
			.frame(width: 90)
		}
	}

	private func lockToggle(_ name: String) -> Binding<Bool> {
		Binding(
			get: { value(name).flatMap(parseBool) ?? false },
			set: { onParameterChange(component.path, "bool", name, $0 ? "true" : "false") }
		)
	}

	private func modeBinding() -> Binding<String> {
		Binding(
			get: { value("motionType").map(stripUSDQuotes) ?? "Dynamic" },
			set: { onParameterChange(component.path, "token", "motionType", quoteUSDString($0)) }
		)
	}

	private func boolBinding(_ name: String, fallback: Bool) -> Binding<Bool> {
		Binding(
			get: { value(name).flatMap(parseBool) ?? fallback },
			set: { onParameterChange(component.path, "bool", name, $0 ? "true" : "false") }
		)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			LabeledContent("Mode") {
				Picker("", selection: modeBinding()) {
					Text("Dynamic").tag("Dynamic")
					Text("Kinematic").tag("Kinematic")
					Text("Static").tag("Static")
				}
				.labelsHidden()
				.pickerStyle(.menu)
				.frame(width: 170)
			}

			Toggle("Detect Continuous Collision", isOn: boolBinding("isCCDEnabled", fallback: false))
				.toggleStyle(.checkbox)
				.font(.system(size: 11))

			Toggle("Affected by Gravity", isOn: boolBinding("gravityEnabled", fallback: true))
				.toggleStyle(.checkbox)
				.font(.system(size: 11))

			scalarField("angularDamping", type: "float", label: "Angular Damping")
			scalarField("linearDamping", type: "float", label: "Linear Damping")

			PhysicsSubsection(title: "Physics Material", isExpanded: $materialExpanded) {
				scalarField("staticFriction", type: "float", label: "Static Friction")
				scalarField("dynamicFriction", type: "float", label: "Dynamic Friction")
				scalarField("restitution", type: "float", label: "Restitution")
			}
			PhysicsSubsection(title: "Mass Properties", isExpanded: $massExpanded) {
				scalarField("mass", type: "float", label: "Mass (kg)")
				PhysicsVector3Row(label: "Inertia", unit: "kg·m²", value: parseVec3(value("inertia"))) { v in
					onParameterChange(component.path, "float3", "inertia", String(format: "(%.3g, %.3g, %.3g)", v.x, v.y, v.z))
				}
				PhysicsSubsection(title: "Center of Mass", isExpanded: $centerOfMassExpanded) {
					PhysicsVector3Row(label: "Position", unit: "m", value: parseVec3(value("centerOfMass"))) { v in
						onParameterChange(component.path, "float3", "centerOfMass", String(format: "(%.3g, %.3g, %.3g)", v.x, v.y, v.z))
					}
					PhysicsQuatRow(label: "Orientation", value: parseQuat(value("centerOfMassOrientation"))) { v in
						onParameterChange(component.path, "quatf", "centerOfMassOrientation", String(format: "(%.3g, %.3g, %.3g, %.3g)", v.x, v.y, v.z, v.w))
					}
				}
			}
			PhysicsSubsection(title: "Movement Locking", isExpanded: $lockingExpanded) {
				LabeledContent("Translation") {
					HStack(spacing: 12) {
						Toggle("X", isOn: lockToggle("lockTranslationX"))
						Toggle("Y", isOn: lockToggle("lockTranslationY"))
						Toggle("Z", isOn: lockToggle("lockTranslationZ"))
					}
				}
				LabeledContent("Rotation") {
					HStack(spacing: 12) {
						Toggle("X", isOn: lockToggle("lockRotationX"))
						Toggle("Y", isOn: lockToggle("lockRotationY"))
						Toggle("Z", isOn: lockToggle("lockRotationZ"))
					}
				}
			}
		}
	}
}

private struct PhysicsSubsection<Content: View>: View {
	let title: String
	@Binding var isExpanded: Bool
	@ViewBuilder let content: () -> Content

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Button {
				isExpanded.toggle()
			} label: {
				HStack(spacing: 6) {
					Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
						.font(.system(size: 9)).foregroundStyle(.secondary)
					Text(title).font(.system(size: 11, weight: .semibold))
					Spacer()
				}
			}
			.buttonStyle(.plain)
			if isExpanded { content() }
		}
		.padding(.vertical, 4)
	}
}

private struct PhysicsVector3Row: View {
	let label: String
	let unit: String?
	let value: SIMD3<Double>
	let onChange: (SIMD3<Double>) -> Void

	var body: some View {
		LabeledContent(unit.map { "\(label) (\($0))" } ?? label) {
			HStack(spacing: 6) {
				PhysicsAxis(label: "X", value: value.x) { onChange(SIMD3($0, value.y, value.z)) }
				PhysicsAxis(label: "Y", value: value.y) { onChange(SIMD3(value.x, $0, value.z)) }
				PhysicsAxis(label: "Z", value: value.z) { onChange(SIMD3(value.x, value.y, $0)) }
			}
		}
	}
}

private struct PhysicsQuatRow: View {
	let label: String
	let value: SIMD4<Double>
	let onChange: (SIMD4<Double>) -> Void

	var body: some View {
		LabeledContent(label) {
			HStack(spacing: 6) {
				PhysicsAxis(label: "X", value: value.x) { onChange(SIMD4($0, value.y, value.z, value.w)) }
				PhysicsAxis(label: "Y", value: value.y) { onChange(SIMD4(value.x, $0, value.z, value.w)) }
				PhysicsAxis(label: "Z", value: value.z) { onChange(SIMD4(value.x, value.y, $0, value.w)) }
				PhysicsAxis(label: "W", value: value.w) { onChange(SIMD4(value.x, value.y, value.z, $0)) }
			}
		}
	}
}

private struct PhysicsAxis: View {
	let label: String
	let value: Double
	let onChange: (Double) -> Void

	var body: some View {
		VStack(spacing: 2) {
			Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
			TextField("", value: Binding(get: { value }, set: onChange),
				format: .number.precision(.fractionLength(0...3)))
				.textFieldStyle(.roundedBorder)
				.frame(width: 44)
		}
	}
}

// MARK: - Particle Emitter Editor

private enum ParticleEmitterTab: Hashable {
	case emitter
	case particles
}

private enum ParticleEmitterSelection: Hashable {
	case main
	case spawned
}

private struct ParticleEmitterEditor: View {
	let component: InspectorComponentSummary
	let onParameterChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void

	@State private var selectedTab: ParticleEmitterTab = .emitter
	@State private var selectedEmitter: ParticleEmitterSelection = .main
	@State private var timingExpanded = true
	@State private var shapeExpanded = true
	@State private var spawningExpanded = true
	@State private var mainSectionExpanded = true
	@State private var propertiesExpanded = true
	@State private var colorExpanded = true
	@State private var texturesExpanded = true
	@State private var animationExpanded = false
	@State private var motionExpanded = true
	@State private var renderingExpanded = true
	@State private var forceFieldsExpanded = true

	// MARK: Descendant lookup

	private var mainEmitterDescendant: ComponentDescendantAttributes? {
		component.descendants.first { $0.name.lowercased().contains("main") }
	}

	private var spawnedEmitterDescendant: ComponentDescendantAttributes? {
		component.descendants.first { $0.name.lowercased().contains("spawn") }
	}

	private var selectedEmitterDescendant: ComponentDescendantAttributes? {
		selectedEmitter == .main ? mainEmitterDescendant : spawnedEmitterDescendant
	}

	private var selectedEmitterPath: String {
		selectedEmitterDescendant?.path
			?? (component.path + "/currentState/" + (selectedEmitter == .main ? "mainEmitter" : "spawnedEmitter"))
	}

	private var currentStatePath: String { component.path }

	// MARK: Attribute readers

	private func currentStateRaw(_ name: String) -> String? {
		component.authoredAttributes.first { $0.name == name }?.value
	}

	private func emitterRaw(_ name: String) -> String? {
		selectedEmitterDescendant?.authoredAttributes.first { $0.name == name }?.value
	}

	private func currentStateBool(_ name: String, fallback: Bool) -> Bool {
		currentStateRaw(name).flatMap(parseBool) ?? fallback
	}

	private func currentStateDouble(_ name: String, fallback: Double) -> Double {
		guard let raw = currentStateRaw(name) else { return fallback }
		return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback
	}

	private func currentStateString(_ name: String, fallback: String) -> String {
		currentStateRaw(name).map(stripUSDQuotes) ?? fallback
	}

	private func emitterBool(_ name: String, fallback: Bool) -> Bool {
		emitterRaw(name).flatMap(parseBool) ?? fallback
	}

	private func emitterDouble(_ name: String, fallback: Double) -> Double {
		guard let raw = emitterRaw(name) else { return fallback }
		return Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback
	}

	private func emitterString(_ name: String, fallback: String) -> String {
		emitterRaw(name).map(stripUSDQuotes) ?? fallback
	}

	// MARK: Vector helpers

	private static func parseVector3(_ raw: String) -> (x: Double, y: Double, z: Double) {
		let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
		let parts = trimmed.split(separator: ",").map {
			Double($0.trimmingCharacters(in: .whitespaces)) ?? 0
		}
		guard parts.count == 3 else { return (0, 0, 0) }
		return (parts[0], parts[1], parts[2])
	}

	private static func formatVector3(_ x: Double, _ y: Double, _ z: Double) -> String {
		String(format: "(%.3f, %.3f, %.3f)", x, y, z)
	}

	// MARK: Writers

	private func writeCurrentStateBool(_ name: String, _ value: Bool) {
		onParameterChange(currentStatePath, "bool", name, value ? "1" : "0")
	}

	private func writeCurrentStateDouble(_ name: String, _ value: Double) {
		onParameterChange(currentStatePath, "float", name, String(format: "%g", value))
	}

	private func writeCurrentStateToken(_ name: String, _ value: String) {
		onParameterChange(currentStatePath, "token", name, value)
	}

	private func writeCurrentStateVector(_ name: String, _ value: (Double, Double, Double)) {
		onParameterChange(currentStatePath, "float3", name, Self.formatVector3(value.0, value.1, value.2))
	}

	private func writeEmitterBool(_ name: String, _ value: Bool) {
		onParameterChange(selectedEmitterPath, "bool", name, value ? "1" : "0")
	}

	private func writeEmitterDouble(_ name: String, _ value: Double) {
		onParameterChange(selectedEmitterPath, "float", name, String(format: "%g", value))
	}

	private func writeEmitterInt(_ name: String, _ value: Int) {
		onParameterChange(selectedEmitterPath, "int", name, String(value))
	}

	private func writeEmitterToken(_ name: String, _ value: String) {
		onParameterChange(selectedEmitterPath, "token", name, value)
	}

	private func writeEmitterString(_ name: String, _ value: String) {
		onParameterChange(selectedEmitterPath, "string", name, quoteUSDString(value))
	}

	private func writeEmitterVector(_ name: String, _ value: (Double, Double, Double)) {
		onParameterChange(selectedEmitterPath, "float3", name, Self.formatVector3(value.0, value.1, value.2))
	}

	// MARK: Body

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Picker("Tab", selection: $selectedTab) {
				Text("Emitter").tag(ParticleEmitterTab.emitter)
				Text("Particles").tag(ParticleEmitterTab.particles)
			}
			.pickerStyle(.segmented)
			.labelsHidden()

			if selectedTab == .particles {
				emitterDropdown
			}

			Divider()

			VStack(alignment: .leading, spacing: 16) {
				if selectedTab == .emitter {
					emitterTabContent
				} else {
					particlesTabContent
				}
			}
		}
	}

	// MARK: Dropdown

	private var emitterDropdown: some View {
		HStack {
			Text("Emitter").font(.system(size: 11)).foregroundStyle(.secondary)
			Spacer()
			Picker("", selection: $selectedEmitter) {
				Text("Main").tag(ParticleEmitterSelection.main)
				Text("Secondary").tag(ParticleEmitterSelection.spawned)
			}
			.labelsHidden()
			.pickerStyle(.menu)
			.frame(width: 120)
			.disabled(!currentStateBool("isSpawningEnabled", fallback: false))
		}
	}

	// MARK: Emitter tab

	@ViewBuilder
	private var emitterTabContent: some View {
		DisclosureGroup("Timing", isExpanded: $timingExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peToggle("Loop", value: currentStateBool("loops", fallback: true)) { writeCurrentStateBool("loops", $0) }
				peScalarRow("Emission Duration", unit: "s", value: currentStateDouble("emissionDuration", fallback: 1.0)) {
					writeCurrentStateDouble("emissionDuration", $0)
				}
				peScalarRow("Idle Duration", unit: "s", value: currentStateDouble("idleDuration", fallback: 0)) {
					writeCurrentStateDouble("idleDuration", $0)
				}
				peScalarRow("Warmup Duration", unit: "s", value: currentStateDouble("warmupDuration", fallback: 0)) {
					writeCurrentStateDouble("warmupDuration", $0)
				}
				peScalarRow("Speed", unit: "×", value: currentStateDouble("simulationSpeed", fallback: 1.0)) {
					writeCurrentStateDouble("simulationSpeed", $0)
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Shape", isExpanded: $shapeExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peChoiceRow("Emitter Shape", value: currentStateString("emitterShape", fallback: "Plane"), options: [
					"Box", "Sphere", "Cone", "Cylinder", "Plane", "Point", "Torus"
				]) { writeCurrentStateToken("emitterShape", quoteUSDString($0)) }

				let shape = currentStateString("emitterShape", fallback: "Plane")
				if shape == "Torus" {
					peScalarRow("Inner Radius", unit: nil, value: currentStateDouble("torusInnerRadius", fallback: 0.5)) {
						writeCurrentStateDouble("torusInnerRadius", $0)
					}
				}
				if ["Sphere", "Cone", "Cylinder", "Torus"].contains(shape) {
					peScalarRow("Radial Amount", unit: nil, value: currentStateDouble("radialAmount", fallback: .pi)) {
						writeCurrentStateDouble("radialAmount", $0)
					}
				}

				peChoiceRow("Birth Location", value: currentStateString("birthLocation", fallback: "Surface"), options: ["Surface", "Volume", "Vertices"]) {
					writeCurrentStateToken("birthLocation", quoteUSDString($0))
				}
				peChoiceRow("Birth Direction", value: currentStateString("birthDirection", fallback: "Normal"), options: ["Normal", "World", "Local"]) {
					writeCurrentStateToken("birthDirection", quoteUSDString($0))
				}

				peVectorRow("Shape Size", value: Self.parseVector3(currentStateRaw("shapeSize") ?? "(0.1, 0.1, 0.1)")) { writeCurrentStateVector("shapeSize", $0) }

				peToggle("Particles in Local Space", value: currentStateBool("isLocal", fallback: false)) { writeCurrentStateBool("isLocal", $0) }
				peToggle("Fields in Local Space", value: currentStateBool("simulationInLocalSpace", fallback: false)) {
					writeCurrentStateBool("simulationInLocalSpace", $0)
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Spawning", isExpanded: $spawningExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peChoiceRow("Spawn Occasion", value: currentStateString("spawnOccasion", fallback: "OnDeath"), options: ["OnBirth", "OnDeath", "OnUpdate"]) {
					writeCurrentStateToken("spawnOccasion", quoteUSDString($0))
				}
				peScalarRow("Velocity Factor", unit: nil, value: currentStateDouble("spawnVelocityFactor", fallback: 1.0)) {
					writeCurrentStateDouble("spawnVelocityFactor", $0)
				}
				peScalarRow("Spread Factor", unit: nil, value: currentStateDouble("spawnSpreadFactor", fallback: 0)) {
					writeCurrentStateDouble("spawnSpreadFactor", $0)
				}
				peScalarRow("Spread Variation", unit: nil, value: currentStateDouble("spawnSpreadFactorVariation", fallback: 0)) {
					writeCurrentStateDouble("spawnSpreadFactorVariation", $0)
				}
				peToggle("Inherit Color", value: currentStateBool("spawnInheritParentColor", fallback: false)) {
					writeCurrentStateBool("spawnInheritParentColor", $0)
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))
	}

	// MARK: Particles tab

	@ViewBuilder
	private var particlesTabContent: some View {
		if selectedEmitter == .main {
			peToggle(
				"Secondary Emitter Enabled",
				value: currentStateBool("isSpawningEnabled", fallback: false)
			) { writeCurrentStateBool("isSpawningEnabled", $0) }
				.font(.system(size: 11, weight: .semibold))
		}

		DisclosureGroup("Main", isExpanded: $mainSectionExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peScalarRow("Birth Rate", unit: nil, value: emitterDouble("birthRate", fallback: 100), fractionDigits: 0) {
					writeEmitterDouble("birthRate", $0)
				}
				peScalarRow("Birth Rate Variation", unit: nil, value: emitterDouble("birthRateVariation", fallback: 0), fractionDigits: 0) {
					writeEmitterDouble("birthRateVariation", $0)
				}
				peIntRow("Burst Count", value: Int(emitterDouble("burstCount", fallback: 100))) { writeEmitterInt("burstCount", $0) }
				peIntRow("Burst Count Variation", value: Int(emitterDouble("burstCountVariation", fallback: 0))) {
					writeEmitterInt("burstCountVariation", $0)
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Properties", isExpanded: $propertiesExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peScalarRow("Life Span", unit: "s", value: emitterDouble("particleLifeSpan", fallback: 1.0)) { writeEmitterDouble("particleLifeSpan", $0) }
				peScalarRow("Life Span Variation", unit: "s", value: emitterDouble("particleLifeSpanVariation", fallback: 0)) {
					writeEmitterDouble("particleLifeSpanVariation", $0)
				}
				peScalarRow("Size", unit: "cm", value: emitterDouble("particleSize", fallback: 0.02)) { writeEmitterDouble("particleSize", $0) }
				peScalarRow("Size Variation", unit: "cm", value: emitterDouble("particleSizeVariation", fallback: 0)) {
					writeEmitterDouble("particleSizeVariation", $0)
				}
				peScalarRow("Size Over Life", unit: nil, value: emitterDouble("sizeOverLife", fallback: 1.0)) { writeEmitterDouble("sizeOverLife", $0) }
				peScalarRow("Size Over Life Power", unit: nil, value: emitterDouble("sizeOverLifePower", fallback: 1.0)) {
					writeEmitterDouble("sizeOverLifePower", $0)
				}
				peScalarRow("Mass", unit: "g", value: emitterDouble("particleMass", fallback: 1.0)) { writeEmitterDouble("particleMass", $0) }
				peScalarRow("Mass Variation", unit: "g", value: emitterDouble("particleMassVariation", fallback: 0)) {
					writeEmitterDouble("particleMassVariation", $0)
				}
				peChoiceRow(
					"Orientation Mode",
					value: emitterString("billboardMode", fallback: "Billboard"),
					options: ["Billboard", "BillboardYAligned", "Free"]
				) { writeEmitterToken("billboardMode", quoteUSDString($0)) }
				peScalarRow("Angle", unit: "°", value: emitterDouble("particleAngle", fallback: 0)) { writeEmitterDouble("particleAngle", $0) }
				peScalarRow("Angle Variation", unit: "°", value: emitterDouble("particleAngleVariation", fallback: 0)) {
					writeEmitterDouble("particleAngleVariation", $0)
				}
				peScalarRow("Stretch Factor", unit: nil, value: emitterDouble("stretchFactor", fallback: 0)) { writeEmitterDouble("stretchFactor", $0) }
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Color", isExpanded: $colorExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Start Color").font(.system(size: 11))
					Spacer()
					Toggle("Range", isOn: Binding(
						get: { emitterBool("useStartColorRange", fallback: false) },
						set: { writeEmitterBool("useStartColorRange", $0) }
					))
					.toggleStyle(.checkbox)
					.font(.system(size: 10))
				}
				peColorRow(value: emitterString("startColorA", fallback: "(1, 1, 1, 1)")) {
					writeEmitterString("startColorA", $0)
				}
				if emitterBool("useStartColorRange", fallback: false) {
					peColorRow(value: emitterString("startColorB", fallback: "(1, 1, 1, 1)")) {
						writeEmitterString("startColorB", $0)
					}
				}

				Divider()

				HStack {
					Text("End Color").font(.system(size: 11))
					Spacer()
					Toggle("Enable", isOn: Binding(
						get: { emitterBool("useEndColor", fallback: false) },
						set: { writeEmitterBool("useEndColor", $0) }
					))
					.toggleStyle(.checkbox)
					.font(.system(size: 10))
				}
				if emitterBool("useEndColor", fallback: false) {
					Toggle("Range", isOn: Binding(
						get: { emitterBool("useEndColorRange", fallback: false) },
						set: { writeEmitterBool("useEndColorRange", $0) }
					))
					.toggleStyle(.checkbox)
					.font(.system(size: 10))
					peColorRow(value: emitterString("endColorA", fallback: "(1, 1, 1, 1)")) {
						writeEmitterString("endColorA", $0)
					}
					if emitterBool("useEndColorRange", fallback: false) {
						peColorRow(value: emitterString("endColorB", fallback: "(1, 1, 1, 1)")) {
							writeEmitterString("endColorB", $0)
						}
					}
				}

				Divider()

				peScalarRow("Color Evolution Power", unit: nil, value: emitterDouble("colorEvolutionPower", fallback: 1.0)) {
					writeEmitterDouble("colorEvolutionPower", $0)
				}
				peChoiceRow(
					"Opacity Over Life",
					value: emitterString("opacityOverLife", fallback: "QuickFadeInOut"),
					options: ["Constant", "EaseFadeIn", "EaseFadeOut", "GradualFadeInOut", "LinearFadeIn", "LinearFadeOut", "QuickFadeInOut"]
				) { writeEmitterToken("opacityOverLife", quoteUSDString($0)) }
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Textures", isExpanded: $texturesExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peChoiceRow("Blend Mode", value: emitterString("blendMode", fallback: "Alpha"), options: ["Alpha", "Additive", "Opaque"]) {
					writeEmitterToken("blendMode", quoteUSDString($0))
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Animation", isExpanded: $animationExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peToggle("Is Animated", value: emitterBool("isAnimated", fallback: false)) { writeEmitterBool("isAnimated", $0) }
				if emitterBool("isAnimated", fallback: false) {
					peScalarRow("Frame Rate", unit: nil, value: emitterDouble("frameRate", fallback: 12.0)) { writeEmitterDouble("frameRate", $0) }
					peScalarRow("Frame Rate Variation", unit: nil, value: emitterDouble("frameRateVariation", fallback: 0)) {
						writeEmitterDouble("frameRateVariation", $0)
					}
					peIntRow("Initial Frame", value: Int(emitterDouble("initialFrame", fallback: 0))) { writeEmitterInt("initialFrame", $0) }
					peIntRow("Initial Frame Variation", value: Int(emitterDouble("initialFrameVariation", fallback: 0))) {
						writeEmitterInt("initialFrameVariation", $0)
					}
					peIntRow("Row Count", value: Int(emitterDouble("rowCount", fallback: 1))) { writeEmitterInt("rowCount", $0) }
					peIntRow("Column Count", value: Int(emitterDouble("columnCount", fallback: 1))) { writeEmitterInt("columnCount", $0) }
					peChoiceRow("Animation Mode", value: emitterString("animationRepeatMode", fallback: "Looping"), options: ["Looping", "AutoReverse", "PlayOnce"]) {
						writeEmitterToken("animationRepeatMode", quoteUSDString($0))
					}
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Motion", isExpanded: $motionExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peVectorRow("Acceleration", value: Self.parseVector3(emitterRaw("acceleration") ?? "(0, 0, 0)")) {
					writeEmitterVector("acceleration", $0)
				}
				peScalarRow("Drag", unit: nil, value: emitterDouble("dampingFactor", fallback: 0)) { writeEmitterDouble("dampingFactor", $0) }
				peScalarRow("Spreading Angle", unit: "°", value: emitterDouble("spreadingAngle", fallback: 0)) {
					writeEmitterDouble("spreadingAngle", $0)
				}
				peScalarRow("Angular Velocity", unit: "rad/s", value: emitterDouble("particleAngularVelocity", fallback: 0)) {
					writeEmitterDouble("particleAngularVelocity", $0)
				}
				peScalarRow("Angular Velocity Var", unit: "rad/s", value: emitterDouble("particleAngularVelocityVariation", fallback: 0)) {
					writeEmitterDouble("particleAngularVelocityVariation", $0)
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Rendering", isExpanded: $renderingExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peToggle("Lighting Enabled", value: emitterBool("isLightingEnabled", fallback: false)) {
					writeEmitterBool("isLightingEnabled", $0)
				}
				peChoiceRow(
					"Sort Order",
					value: emitterString("sortOrder", fallback: "Unsorted"),
					options: ["Unsorted", "IncreasingID", "DecreasingID", "IncreasingAge", "DecreasingAge", "IncreasingDepth", "DecreasingDepth"]
				) { writeEmitterToken("sortOrder", quoteUSDString($0)) }
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))

		DisclosureGroup("Force Fields", isExpanded: $forceFieldsExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				peVectorRow("Attraction Center", value: Self.parseVector3(emitterRaw("radialGravityCenter") ?? "(0, 0, 0)")) {
					writeEmitterVector("radialGravityCenter", $0)
				}
				peScalarRow("Attraction Strength", unit: nil, value: emitterDouble("radialGravityStrength", fallback: 0)) {
					writeEmitterDouble("radialGravityStrength", $0)
				}
				peVectorRow("Vortex Direction", value: Self.parseVector3(emitterRaw("vortexDirection") ?? "(0, 0, 0)")) {
					writeEmitterVector("vortexDirection", $0)
				}
				peScalarRow("Vortex Strength", unit: nil, value: emitterDouble("vortexStrength", fallback: 0)) {
					writeEmitterDouble("vortexStrength", $0)
				}
				peScalarRow("Noise Strength", unit: nil, value: emitterDouble("noiseStrength", fallback: 0)) {
					writeEmitterDouble("noiseStrength", $0)
				}
				peScalarRow("Noise Scale", unit: nil, value: emitterDouble("noiseScale", fallback: 1.0)) {
					writeEmitterDouble("noiseScale", $0)
				}
				peScalarRow("Noise Speed", unit: nil, value: emitterDouble("noiseAnimationSpeed", fallback: 1.0)) {
					writeEmitterDouble("noiseAnimationSpeed", $0)
				}
			}
			.padding(.vertical, 4)
		}
		.font(.system(size: 11, weight: .semibold))
	}

	// MARK: Row helpers

	@ViewBuilder
	private func peToggle(_ label: String, value: Bool, onChange: @escaping (Bool) -> Void) -> some View {
		Toggle(label, isOn: Binding(get: { value }, set: onChange))
			.toggleStyle(.checkbox)
			.font(.system(size: 11))
	}

	@ViewBuilder
	private func peScalarRow(
		_ label: String,
		unit: String?,
		value: Double,
		fractionDigits: Int = 3,
		onChange: @escaping (Double) -> Void
	) -> some View {
		HStack {
			Text(label).font(.system(size: 11))
			Spacer()
			HStack(spacing: 4) {
				TextField(
					"",
					value: Binding(get: { value }, set: onChange),
					format: .number.precision(.fractionLength(0...fractionDigits))
				)
				.textFieldStyle(.roundedBorder)
				.frame(width: 70)
				if let unit {
					Text(unit).font(.system(size: 10)).foregroundStyle(.secondary)
				}
			}
		}
	}

	@ViewBuilder
	private func peIntRow(_ label: String, value: Int, onChange: @escaping (Int) -> Void) -> some View {
		HStack {
			Text(label).font(.system(size: 11))
			Spacer()
			TextField(
				"",
				text: Binding(
					get: { String(value) },
					set: { if let v = Int($0) { onChange(v) } }
				)
			)
			.textFieldStyle(.roundedBorder)
			.frame(width: 80)
		}
	}

	@ViewBuilder
	private func peChoiceRow(
		_ label: String,
		value: String,
		options: [String],
		onChange: @escaping (String) -> Void
	) -> some View {
		HStack {
			Text(label).font(.system(size: 11))
			Spacer()
			Picker("", selection: Binding(get: { value }, set: onChange)) {
				ForEach(options, id: \.self) { Text($0).tag($0) }
			}
			.labelsHidden()
			.pickerStyle(.menu)
			.frame(width: 150)
		}
	}

	@ViewBuilder
	private func peVectorRow(
		_ label: String,
		value: (x: Double, y: Double, z: Double),
		onChange: @escaping ((Double, Double, Double)) -> Void
	) -> some View {
		HStack {
			Text(label).font(.system(size: 11))
			Spacer()
			HStack(spacing: 4) {
				peAxisField(axis: "X", value: value.x) { onChange(($0, value.y, value.z)) }
				peAxisField(axis: "Y", value: value.y) { onChange((value.x, $0, value.z)) }
				peAxisField(axis: "Z", value: value.z) { onChange((value.x, value.y, $0)) }
			}
		}
	}

	@ViewBuilder
	private func peAxisField(axis: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
		TextField(
			axis,
			text: Binding(
				get: { String(format: "%.3f", value) },
				set: { if let v = Double($0) { onChange(v) } }
			)
		)
		.textFieldStyle(.roundedBorder)
		.frame(width: 50)
	}

	@ViewBuilder
	private func peColorRow(value: String, onChange: @escaping (String) -> Void) -> some View {
		HStack {
			Spacer()
			TextField(
				"RGBA",
				text: Binding(get: { value }, set: onChange)
			)
			.textFieldStyle(.roundedBorder)
			.frame(width: 170)
		}
	}
}

// MARK: - Custom Docking Region Editor

private struct CustomDockingRegionEditor: View {
	let component: InspectorComponentSummary
	let onParameterChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void

	private func value(_ name: String) -> String? {
		component.authoredAttributes.first { $0.name == name }?.value
	}

	private static func parseVector3(_ raw: String) -> (x: Double, y: Double, z: Double) {
		let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
		let parts = trimmed.split(separator: ",").map {
			Double($0.trimmingCharacters(in: .whitespaces)) ?? 0
		}
		guard parts.count == 3 else { return (0, 0, 0) }
		return (parts[0], parts[1], parts[2])
	}

	/// Width in centimeters. RCP stores width implicitly in the m_bounds struct
	/// (max.x - min.x) measured in meters; falls back to a direct `width`
	/// attribute literal if the runtime has flattened it.
	private var widthValue: Double {
		if let raw = value("width"), let direct = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
			return direct
		}
		let maxBounds = Self.parseVector3(value("max") ?? "(1.2, 0.5, 0)")
		let minBounds = Self.parseVector3(value("min") ?? "(-1.2, -0.5, 0)")
		return max(0.0, (maxBounds.x - minBounds.x) * 100.0)
	}

	private var previewVideoRaw: String {
		guard let raw = value("previewVideo") else { return "" }
		return stripUSDQuotes(raw)
	}

	private var previewVideoLabel: String {
		let unquoted = previewVideoRaw
		if unquoted.isEmpty { return "None" }
		return unquoted.split(separator: "/").last.map(String.init) ?? unquoted
	}

	private func chooseVideo() -> URL? {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
		panel.prompt = "Choose"
		return panel.runModal() == .OK ? panel.url : nil
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Text("Width").font(.system(size: 11))
				Spacer()
				HStack(spacing: 6) {
					TextField(
						"",
						value: Binding(
							get: { widthValue },
							set: { onParameterChange(component.path, "float", "width", String(format: "%g", $0)) }
						),
						format: .number.precision(.fractionLength(0...3))
					)
					.textFieldStyle(.roundedBorder)
					.frame(width: 90)
					Text("cm").font(.system(size: 10)).foregroundStyle(.secondary)
				}
			}

			VStack(alignment: .leading, spacing: 4) {
				Text("Preview Video")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
				Text(previewVideoLabel)
					.font(.system(size: 11))
					.foregroundStyle(.primary)
					.lineLimit(1)
			}

			HStack(spacing: 10) {
				Button("Choose…") {
					guard let url = chooseVideo() else { return }
					onParameterChange(component.path, "customDataAsset", "previewVideo", quoteUSDString(url.path))
				}
				.buttonStyle(.borderless)
				Button("Clear") {
					onParameterChange(component.path, "customDataAsset", "previewVideo", quoteUSDString(""))
				}
				.buttonStyle(.borderless)
				.disabled(previewVideoLabel == "None")
				Spacer()
			}
		}
	}
}

// MARK: - Generic Descendant Editor

private struct GenericDescendantEditor: View {
	let descendants: [ComponentDescendantAttributes]
	let onParameterChange: (_ targetPrimPath: String, _ attributeType: String, _ attributeName: String, _ valueLiteral: String) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(descendants) { descendant in
				let visible = descendant.authoredAttributes.filter { $0.name != "info:id" }
				if !visible.isEmpty {
					Text(descendant.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
					ForEach(visible) { attribute in
						descendantAttributeEditor(
							for: attribute,
							targetPrimPath: descendant.path,
							labelPrefix: descendant.name
						)
					}
				}
			}
		}
	}

	@ViewBuilder
	private func descendantAttributeEditor(
		for attribute: InspectorAuthoredAttribute,
		targetPrimPath: String,
		labelPrefix: String
	) -> some View {
		let label = "\(labelPrefix).\(attribute.name)"
		if let bool = parseBool(attribute.value) {
			Toggle(label, isOn: Binding(
				get: { bool },
				set: { onParameterChange(targetPrimPath, "bool", attribute.name, $0 ? "true" : "false") }
			))
		} else if let number = Double(attribute.value.trimmingCharacters(in: .whitespacesAndNewlines)) {
			LabeledContent(label) {
				TextField("", value: Binding(
					get: { number },
					set: { onParameterChange(targetPrimPath, "double", attribute.name, String($0)) }
				), format: .number.precision(.fractionLength(0...4)))
				.textFieldStyle(.roundedBorder)
				.frame(minWidth: 80)
			}
		} else {
			LabeledContent(label) {
				TextField("", text: Binding(
					get: { stripUSDQuotes(attribute.value) },
					set: { onParameterChange(targetPrimPath, "string", attribute.name, quoteUSDString($0)) }
				))
				.textFieldStyle(.roundedBorder)
			}
		}
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

private struct TransformEditor: View {
	let transform: SwiftUsdShell.USDTransformData
	let onChange: (SwiftUsdShell.USDTransformData) -> Void
	@State private var isUniformScale: Bool = true

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			TransformVectorRow(label: "Position", values: transform.position) { newValue in
				onChange(updateTransform(transform, position: newValue))
			}
			TransformVectorRow(label: "Rotation (deg)", values: transform.rotationDegrees) { newValue in
				onChange(updateTransform(transform, rotationDegrees: newValue))
			}
			UniformScaleRow(
				values: transform.scale,
				isUniformScale: $isUniformScale
			) { newValue in
				onChange(updateTransform(transform, scale: newValue))
			}
		}
	}
}

private struct TransformVectorRow: View {
	let label: String
	let values: SIMD3<Double>
	let onChange: (SIMD3<Double>) -> Void

	var body: some View {
		HStack(spacing: 8) {
			Text(label)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.frame(width: 100, alignment: .leading)
			Spacer()
			EditableAxisField(value: values.x, label: "X") { v in
				onChange(SIMD3(v, values.y, values.z))
			}
			EditableAxisField(value: values.y, label: "Y") { v in
				onChange(SIMD3(values.x, v, values.z))
			}
			EditableAxisField(value: values.z, label: "Z") { v in
				onChange(SIMD3(values.x, values.y, v))
			}
		}
	}
}

private struct UniformScaleRow: View {
	let values: SIMD3<Double>
	@Binding var isUniformScale: Bool
	let onChange: (SIMD3<Double>) -> Void

	var body: some View {
		HStack(spacing: 8) {
			Text("Scale")
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
				.frame(width: 80, alignment: .leading)

			Button {
				isUniformScale.toggle()
				guard isUniformScale else { return }
				let v = (values.x + values.y + values.z) / 3.0
				onChange(SIMD3<Double>(repeating: v))
			} label: {
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

			EditableAxisField(value: values.x, label: "X") { v in
				onChange(updatedScale(.x, value: v))
			}
			EditableAxisField(value: values.y, label: "Y") { v in
				onChange(updatedScale(.y, value: v))
			}
			EditableAxisField(value: values.z, label: "Z") { v in
				onChange(updatedScale(.z, value: v))
			}
		}
	}

	private enum Axis { case x, y, z }

	private func updatedScale(_ axis: Axis, value: Double) -> SIMD3<Double> {
		if isUniformScale {
			return SIMD3<Double>(repeating: value)
		}
		var updated = values
		switch axis {
		case .x: updated.x = value
		case .y: updated.y = value
		case .z: updated.z = value
		}
		return updated
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
			.onAppear { text = value.formatted(Self.numberFormat) }
			.onChange(of: value) { _, newValue in
				if !isEditing && !isFocused {
					text = newValue.formatted(Self.numberFormat)
				}
			}
			.onChange(of: isFocused) { wasFocused, nowFocused in
				if wasFocused && !nowFocused {
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
				text = value.formatted(Self.numberFormat)
				isEditing = false
				isFocused = false
			}
	}

	private func commit() {
		guard let parsed = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			text = value.formatted(Self.numberFormat)
			return
		}
		onCommit(parsed)
		text = parsed.formatted(Self.numberFormat)
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
		VStack(spacing: 0) {
			ScrollView {
				content
					.padding()
			}

			if store.selectedNodeID != nil {
				Divider()
				AddComponentRow { name, identifier in
					store.send(.addComponentRequested(componentName: name, componentIdentifier: identifier))
				}
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
				.background(.thinMaterial)
			}
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
						TransformEditor(transform: transform) { updated in
							store.send(.primTransformEdited(updated))
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
								onDescendantChange: { targetPrimPath, attributeType, attributeName, valueLiteral in
									store.send(.setComponentParameterRequested(
										componentPath: targetPrimPath,
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
								},
								onOpenAudioMixer: onOpenAudioMixer
							)
						}
					}
				} label: {
					Text("Components").font(.headline)
				}

				// Audio Mix Groups, Animation Library, and other component-specific
				// editors are now rendered inline within each component's disclosure
				// in the Components section above. The flat filter that used to live
				// here was misleading (it keyed on typeName, not the info:id
				// identifier) and duplicated affordances now handled per-component.
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
