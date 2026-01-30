import ComposableArchitecture
import Foundation
import SceneGraphModels
import USDInterop

public struct SceneGraphClient: Sendable {
	public var loadSceneGraph: @Sendable (_ url: URL) async throws -> [SceneNode]

	public init(loadSceneGraph: @escaping @Sendable (URL) async throws -> [SceneNode]) {
		self.loadSceneGraph = loadSceneGraph
	}
}

private enum SceneGraphClientKey: DependencyKey {
	static let liveValue = SceneGraphClient(loadSceneGraph: { url in
		try loadSceneGraphFromUSD(url: url)
	})
}

public extension DependencyValues {
	var sceneGraphClient: SceneGraphClient {
		get { self[SceneGraphClientKey.self] }
		set { self[SceneGraphClientKey.self] = newValue }
	}
}

private func loadSceneGraphFromUSD(url: URL) throws -> [SceneNode] {
	guard FileManager.default.fileExists(atPath: url.path) else {
		return []
	}

	if let json = USDInteropStage.sceneGraphJSON(url: url),
	   let data = json.data(using: .utf8),
	   let decoded = try? JSONDecoder().decode([CxxSceneNode].self, from: data) {
		return decoded.map { $0.toSceneNode() }
	}

	if let usda = USDInteropStage.exportUSDA(url: url) {
		return parseSceneNodes(usda)
	}

	if let data = try? Data(contentsOf: url),
	   let text = String(data: data, encoding: .utf8) {
		return parseSceneNodes(text)
	}

	return []
}

private struct CxxSceneNode: Decodable {
	let name: String
	let path: String
	let type: String?
	let children: [CxxSceneNode]

	func toSceneNode() -> SceneNode {
		SceneNode(
			id: path,
			name: name,
			typeName: type,
			specifier: .def,
			path: path,
			children: children.map { $0.toSceneNode() }
		)
	}
}

private final class SceneNodeBuilder {
	let name: String
	let typeName: String?
	let specifier: SceneNodeSpecifier
	var children: [SceneNodeBuilder] = []

	init(name: String, typeName: String?, specifier: SceneNodeSpecifier) {
		self.name = name
		self.typeName = typeName
		self.specifier = specifier
	}
}

private func parseSceneNodes(_ source: String) -> [SceneNode] {
	let lines = source.split(whereSeparator: \.isNewline)

	let regex = /^(\s*)(def|over|class)\s+(?:([A-Za-z0-9_:]+)\s+)?\"([^\"]+)\"/

	var roots: [SceneNodeBuilder] = []
	var stack: [SceneNodeBuilder] = []
	var pendingNode: SceneNodeBuilder? = nil

	for rawLine in lines {
		let line = String(rawLine)
		let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.hasPrefix("#") else { continue }

		if let match = line.firstMatch(of: regex) {
			let specifierRaw = String(match.output.2)
			let specifier = SceneNodeSpecifier(rawValue: specifierRaw) ?? .def
			let typeName = match.output.3.map { String($0) }
			let name = String(match.output.4)
			let node = SceneNodeBuilder(name: name, typeName: typeName, specifier: specifier)

			if let parent = stack.last {
				parent.children.append(node)
			} else {
				roots.append(node)
			}

			if line.contains("{") {
				stack.append(node)
				pendingNode = nil
			} else {
				pendingNode = node
			}
		}

		if line.contains("{") && pendingNode != nil {
			stack.append(pendingNode!)
			pendingNode = nil
		}

		if line.contains("}") {
			let closingCount = line.filter { $0 == "}" }.count
			if closingCount > 0 {
				for _ in 0..<closingCount {
					if !stack.isEmpty {
						stack.removeLast()
					}
				}
			}
		}
	}

	return roots.map { buildSceneNode(from: $0, parentPath: "") }
}

private func buildSceneNode(from builder: SceneNodeBuilder, parentPath: String) -> SceneNode {
	let path = parentPath.isEmpty ? "/\(builder.name)" : "\(parentPath)/\(builder.name)"
	let children = builder.children.map { buildSceneNode(from: $0, parentPath: path) }
	return SceneNode(
		id: path,
		name: builder.name,
		typeName: builder.typeName,
		specifier: builder.specifier,
		path: path,
		children: children
	)
}
