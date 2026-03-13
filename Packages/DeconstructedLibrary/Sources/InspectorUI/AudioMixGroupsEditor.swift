import AppKit
import InspectorFeature
import SwiftUI
import UniformTypeIdentifiers
import USDInterfaces

public struct AudioMixGroupsEditor: View {
	public let componentPath: String
	public let descendantAttributes: [ComponentDescendantAttributes]
	public let onAddMixGroup: (String) -> Void
	public let onAssignAudioMixGroupResource: (String, String, URL) -> Void
	public let onRawAttributeChanged: (String, String, String, String, String) -> Void

	@State private var rawValues: [String: String] = [:]
	@State private var rawAttributeTypes: [String: String] = [:]

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
		let groups = audioMixGroupEditorModels
		VStack(alignment: .leading, spacing: 10) {
			if groups.isEmpty {
				Text("No mix groups.")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			} else {
				ForEach(groups) { group in
					VStack(alignment: .leading, spacing: 8) {
						Text(group.displayName)
							.font(.system(size: 11, weight: .semibold))
							.foregroundStyle(.secondary)

						InspectorRow(label: "Speed") {
							TextField(
								"",
								value: audioMixGroupDoubleBinding(
									groupPath: group.primPath,
									attributeName: "speed",
									fallback: group.speed
								),
								format: .number.precision(.fractionLength(0...3))
							)
							.textFieldStyle(.roundedBorder)
							.frame(width: 90)
							.font(.system(size: 11))
						}

						InspectorRow(label: "dB") {
							TextField(
								"",
								value: audioMixGroupDoubleBinding(
									groupPath: group.primPath,
									attributeName: "gain",
									fallback: group.gain
								),
								format: .number.precision(.fractionLength(0...3))
							)
							.textFieldStyle(.roundedBorder)
							.frame(width: 90)
							.font(.system(size: 11))
						}

						Toggle(
							"Mute",
							isOn: audioMixGroupBoolBinding(
								groupPath: group.primPath,
								attributeName: "mute",
								fallback: group.mute
							)
						)
						.font(.system(size: 11))
						.toggleStyle(.checkbox)

						VStack(alignment: .leading, spacing: 4) {
							Text("Assigned Audio")
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
							if group.assignedFiles.isEmpty {
								Text("No audio assigned.")
									.font(.system(size: 11))
									.foregroundStyle(.secondary)
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
								}
							}
						}

						HStack(spacing: 10) {
							Button("Choose...") {
								guard let selectedURL = selectAudioFileURL() else { return }
								onAssignAudioMixGroupResource(
									componentPath,
									group.primPath,
									selectedURL
								)
							}
							.buttonStyle(.borderless)
							Spacer()
						}
					}
					.padding(10)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(.quaternary.opacity(0.35))
					.clipShape(RoundedRectangle(cornerRadius: 8))
				}
			}

			HStack(spacing: 10) {
				Button {
					onAddMixGroup(componentPath)
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 12, weight: .medium))
				}
				.buttonStyle(.plain)
				Spacer()
			}
			.padding(.horizontal, 4)
		}
		.onChange(of: authoredAttributesSignature) { _ in
			rawValues = [:]
			rawAttributeTypes = [:]
		}
	}

	private struct AudioMixGroupAssignedFileEditorModel: Identifiable {
		let primPath: String
		let displayName: String
		let relativeAssetPath: String
		let mixGroupTarget: String

		var id: String { primPath }
	}

	private struct AudioMixGroupEditorModel: Identifiable {
		let primPath: String
		let displayName: String
		let gain: Double
		let mute: Bool
		let speed: Double
		let assignedFiles: [AudioMixGroupAssignedFileEditorModel]

		var id: String { primPath }
	}

	private var authoredAttributesSignature: String {
		descendantAttributes
			.flatMap(\.authoredAttributes)
			.map { "\($0.name)=\($0.value)" }
			.sorted()
			.joined(separator: "|")
	}

	private var audioMixGroupEditorModels: [AudioMixGroupEditorModel] {
		let files = descendantAttributes.compactMap { descendant -> AudioMixGroupAssignedFileEditorModel? in
			let fileLiteral = authoredLiteralValue(
				in: descendant.authoredAttributes,
				names: ["file"],
				allowLooseMatch: false
			)
			guard !fileLiteral.isEmpty else { return nil }
			let mixGroupTarget = parseUSDRelationshipTargets(
				authoredLiteralValue(
					in: descendant.authoredAttributes,
					names: ["mixGroup"],
					allowLooseMatch: false
				)
			).first ?? ""
			guard !mixGroupTarget.isEmpty else { return nil }
			let relativeAssetPath = parseUSDAssetPathLiteral(fileLiteral)
			let displayName = URL(fileURLWithPath: relativeAssetPath).lastPathComponent
			return AudioMixGroupAssignedFileEditorModel(
				primPath: descendant.primPath,
				displayName: displayName.isEmpty ? descendant.displayName : displayName,
				relativeAssetPath: relativeAssetPath,
				mixGroupTarget: mixGroupTarget
			)
		}

		return descendantAttributes.compactMap { descendant in
			let fileLiteral = authoredLiteralValue(
				in: descendant.authoredAttributes,
				names: ["file"],
				allowLooseMatch: false
			)
			guard fileLiteral.isEmpty else { return nil }
			let gainLiteral = authoredLiteralValue(
				in: descendant.authoredAttributes,
				names: ["gain"],
				allowLooseMatch: false
			)
			let muteLiteral = authoredLiteralValue(
				in: descendant.authoredAttributes,
				names: ["mute"],
				allowLooseMatch: false
			)
			let speedLiteral = authoredLiteralValue(
				in: descendant.authoredAttributes,
				names: ["speed"],
				allowLooseMatch: false
			)
			guard !gainLiteral.isEmpty || !muteLiteral.isEmpty || !speedLiteral.isEmpty else {
				return nil
			}
			return AudioMixGroupEditorModel(
				primPath: descendant.primPath,
				displayName: descendant.displayName,
				gain: Self.parseUSDDouble(gainLiteral) ?? 0,
				mute: Self.parseUSDBool(muteLiteral) ?? false,
				speed: Self.parseUSDDouble(speedLiteral) ?? 1,
				assignedFiles: files
					.filter { $0.mixGroupTarget == descendant.primPath }
					.sorted {
						$0.displayName.localizedStandardCompare($1.displayName)
							== .orderedAscending
					}
			)
		}
		.sorted {
			$0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
		}
	}

	private func audioMixGroupDoubleBinding(
		groupPath: String,
		attributeName: String,
		fallback: Double
	) -> Binding<Double> {
		let storageKey = "\(groupPath)#\(attributeName)"
		return Binding(
			get: {
				if let raw = rawValues[storageKey],
				   let parsed = Self.parseUSDDouble(raw)
				{
					return parsed
				}
				return fallback
			},
			set: { newValue in
				let literal = Self.formatComponent(newValue)
				rawValues[storageKey] = literal
				rawAttributeTypes[storageKey] = "float"
				onRawAttributeChanged(
					groupPath,
					componentPath,
					"float",
					attributeName,
					literal
				)
			}
		)
	}

	private func audioMixGroupBoolBinding(
		groupPath: String,
		attributeName: String,
		fallback: Bool
	) -> Binding<Bool> {
		let storageKey = "\(groupPath)#\(attributeName)"
		return Binding(
			get: {
				if let raw = rawValues[storageKey],
				   let parsed = Self.parseUSDBool(raw)
				{
					return parsed
				}
				return fallback
			},
			set: { newValue in
				let literal = newValue ? "1" : "0"
				rawValues[storageKey] = literal
				rawAttributeTypes[storageKey] = "bool"
				onRawAttributeChanged(
					groupPath,
					componentPath,
					"bool",
					attributeName,
					literal
				)
			}
		)
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
		guard trimmed.count >= 2, trimmed.first == "@", trimmed.last == "@"
		else {
			return trimmed
		}
		let start = trimmed.index(after: trimmed.startIndex)
		let end = trimmed.index(before: trimmed.endIndex)
		return String(trimmed[start..<end])
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
		var normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		if normalized.hasSuffix(",") {
			normalized.removeLast()
		}
		if normalized.count >= 2, normalized.first == "\"", normalized.last == "\"" {
			normalized = String(normalized.dropFirst().dropLast())
		}
		switch normalized.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
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
}
