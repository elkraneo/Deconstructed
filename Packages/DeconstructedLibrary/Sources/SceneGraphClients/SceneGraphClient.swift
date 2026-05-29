import ComposableArchitecture
import DeconstructedModels
import Foundation
import SceneGraphModels

public struct SceneGraphClient: Sendable {
	public var loadSceneGraph: @Sendable (_ url: URL) async throws -> [SceneNode]

	public init(loadSceneGraph: @escaping @Sendable (URL) async throws -> [SceneNode]) {
		self.loadSceneGraph = loadSceneGraph
	}
}

private enum SceneGraphClientKey: DependencyKey {
	static var liveValue: SceneGraphClient {
		SceneGraphClient(loadSceneGraph: { url in
			try loadSceneGraphFromUSD(url: url)
		})
	}

	static var testValue: SceneGraphClient {
		SceneGraphClient(loadSceneGraph: { _ in
			// Avoid touching the filesystem / OpenUSD when running unit tests.
			[]
		})
	}
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

	if let data = try? Data(contentsOf: url),
	   let text = String(data: data, encoding: .utf8) {
		return parseSceneNodes(text)
	}

	return []
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
	// Robust prim-scope tracking (see USDAPrimScopeTracker): naive brace counting
	// desyncs on metadata dictionaries (customData = { }, variants = { }) and
	// mis-nests sibling prims in the navigator.
	let specifierRegex = /^\s*(def|over|class)\b/
	var tracker = USDAPrimScopeTracker()
	var roots: [SceneNodeBuilder] = []
	var buildersByPath: [String: SceneNodeBuilder] = [:]

	for rawLine in source.split(whereSeparator: \.isNewline) {
		let line = String(rawLine)
		let scope = tracker.consume(line)
		guard let path = scope.declaredPath else { continue }

		let specifier = line.firstMatch(of: specifierRegex)
			.flatMap { SceneNodeSpecifier(rawValue: String($0.output.1)) } ?? .def
		let name = path.split(separator: "/").last.map(String.init) ?? path
		let node = SceneNodeBuilder(name: name, typeName: scope.declaredTypeName, specifier: specifier)

		if let parentPath = scope.activePath, let parent = buildersByPath[parentPath] {
			parent.children.append(node)
		} else {
			roots.append(node)
		}
		buildersByPath[path] = node
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
