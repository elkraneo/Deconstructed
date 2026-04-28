/// Primitive shape types that can be inserted into a USD scene.
public enum USDPrimitiveType: String, CaseIterable, Sendable {
	case capsule = "Capsule"
	case cone = "Cone"
	case cube = "Cube"
	case cylinder = "Cylinder"
	case sphere = "Sphere"

	/// The USD type name for this primitive.
	public var typeName: String { rawValue }

	/// A human-readable display name.
	public var displayName: String { rawValue }

	/// The SF Symbol icon name for this primitive.
	public var iconName: String {
		switch self {
		case .capsule: return "capsule"
		case .cone: return "cone"
		case .cube: return "cube"
		case .cylinder: return "cylinder"
		case .sphere: return "circle"
		}
	}
}

/// Structural prim types (grouping containers).
public enum USDStructuralType: String, CaseIterable, Sendable {
	case xform = "Xform"
	case scope = "Scope"

	/// The USD type name for this structural type.
	public var typeName: String { rawValue }

	/// A human-readable display name.
	public var displayName: String {
		switch self {
		case .xform: return "Transform"
		case .scope: return "Scope"
		}
	}

	/// The SF Symbol icon name for this type.
	public var iconName: String {
		switch self {
		case .xform: return "move.3d"
		case .scope: return "folder"
		}
	}
}
