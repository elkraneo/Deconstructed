import Foundation

public enum SceneNodeSpecifier: String, Sendable, CaseIterable {
	case def
	case over
	case `class`
}

public struct SceneNode: Identifiable, Sendable, Hashable {
	public let id: String
	public let name: String
	public let typeName: String?
	public let specifier: SceneNodeSpecifier
	public let path: String
	public var children: [SceneNode]

	public init(
		id: String,
		name: String,
		typeName: String?,
		specifier: SceneNodeSpecifier,
		path: String,
		children: [SceneNode] = []
	) {
		self.id = id
		self.name = name
		self.typeName = typeName
		self.specifier = specifier
		self.path = path
		self.children = children
	}

	public var displayName: String {
		name
	}

	public static func == (lhs: SceneNode, rhs: SceneNode) -> Bool {
		lhs.id == rhs.id
		&& lhs.name == rhs.name
		&& lhs.typeName == rhs.typeName
		&& lhs.specifier == rhs.specifier
		&& lhs.children == rhs.children
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
		hasher.combine(name)
		hasher.combine(typeName)
		hasher.combine(specifier)
		hasher.combine(children)
	}
}
