import Foundation

public struct InspectorComponentParameter: Equatable, Sendable, Hashable, Identifiable {
	public enum Kind: Equatable, Sendable, Hashable {
		case toggle(defaultValue: Bool)
		case text(defaultValue: String, placeholder: String)
		case scalar(defaultValue: Double, unit: String?)
		case choice(defaultValue: String, options: [String])
	}

	public let key: String
	public let label: String
	public let kind: Kind

	public init(key: String, label: String, kind: Kind) {
		self.key = key
		self.label = label
		self.kind = kind
	}

	public var id: String { key }
}

public enum InspectorComponentParameterValue: Equatable, Sendable, Hashable {
	case bool(Bool)
	case string(String)
	case double(Double)
}

public struct InspectorComponentDefinition: Equatable, Sendable, Identifiable, Hashable {
	public enum Placement: Sendable, Hashable {
		case selectedPrim
		case rootPrim
	}

	public enum Category: String, CaseIterable, Sendable, Hashable {
		case general
		case audio
		case lighting
		case physics

		public var displayName: String {
			switch self {
			case .general: return "General"
			case .audio: return "Audio"
			case .lighting: return "Lighting"
			case .physics: return "Physics"
			}
		}
	}

	public let name: String
	public let authoredPrimName: String
	public let category: Category
	public let placement: Placement
	public let summary: String
	public let identifier: String

	public init(
		name: String,
		authoredPrimName: String,
		category: Category,
		placement: Placement = .selectedPrim,
		summary: String,
		identifier: String
	) {
		self.name = name
		self.authoredPrimName = authoredPrimName
		self.category = category
		self.placement = placement
		self.summary = summary
		self.identifier = identifier
	}

	public var id: String { identifier }

	public var isEnabledForAuthoring: Bool {
		switch identifier {
		case "RealityKit.Accessibility",
		     "RealityKit.Anchoring",
		     "RealityKit.AnimationLibrary",
		     "RCP.BehaviorsContainer",
		     "RealityKit.Billboard",
		     "RealityKit.CharacterController",
		     "RealityKit.CustomDockingRegion",
		     "RealityKit.InputTarget",
		     "RealityKit.MeshSorting",
		     "RealityKit.HierarchicalFade",
		     "RealityKit.VFXEmitter",
		     "RealityKit.AudioLibrary",
		     "RealityKit.SpatialAudio",
		     "RealityKit.AmbientAudio",
		     "RealityKit.ChannelAudio",
		     "RealityKit.AudioMixGroups",
		     "RealityKit.Reverb",
		     "RealityKit.DirectionalLight",
		     "RealityKit.EnvironmentLightingConfiguration",
		     "RealityKit.GroundingShadow",
		     "RealityKit.ImageBasedLight",
		     "RealityKit.ImageBasedLightReceiver",
		     "RealityKit.PointLight",
		     "RealityKit.SpotLight",
		     "RealityKit.VirtualEnvironmentProbe",
		     "RealityKit.Collider",
		     "RealityKit.RigidBody",
		     "RealityKit.MotionState",
		     "RealityKit.SceneUnderstanding":
			return true
		default:
			return false
		}
	}

	public var parameterLayout: [InspectorComponentParameter] {
		switch identifier {
		case "RealityKit.Accessibility":
			return [
				InspectorComponentParameter(
					key: "isAccessibilityElement",
					label: "Is Accessibility Element",
					kind: .toggle(defaultValue: false)
				),
				InspectorComponentParameter(
					key: "label",
					label: "Label",
					kind: .text(defaultValue: "", placeholder: "String identifying the Entity")
				),
				InspectorComponentParameter(
					key: "value",
					label: "Value",
					kind: .text(defaultValue: "", placeholder: "String representing the value")
				)
			]
		case "RealityKit.Billboard":
			return [
				InspectorComponentParameter(
					key: "blendFactor",
					label: "Blend Factor",
					kind: .scalar(defaultValue: 0, unit: nil)
				)
			]
		case "RealityKit.Reverb":
			return [
				InspectorComponentParameter(
					key: "preset",
					label: "Preset",
					kind: .choice(
						defaultValue: "Medium Room",
						options: [
							"Small Room",
							"Medium Room",
							"Large Room",
							"Cathedral",
							"Plate"
						]
					)
				)
			]
		case "RealityKit.ImageBasedLight":
			return [
				InspectorComponentParameter(
					key: "isGlobalIBL",
					label: "Is Global IBL",
					kind: .toggle(defaultValue: false)
				)
			]
		case "RealityKit.VirtualEnvironmentProbe":
			return [
				InspectorComponentParameter(
					key: "blendMode",
					label: "Blend Mode",
					kind: .choice(
						defaultValue: "single",
						options: ["single", "additive", "multiply"]
					)
				)
			]
		case "RealityKit.Collider":
			return [
				InspectorComponentParameter(
					key: "group",
					label: "Group",
					kind: .scalar(defaultValue: 1, unit: nil)
				),
				InspectorComponentParameter(
					key: "mask",
					label: "Mask",
					kind: .scalar(defaultValue: 4294967295, unit: nil)
				),
				InspectorComponentParameter(
					key: "type",
					label: "Type",
					kind: .text(defaultValue: "Default", placeholder: "Collision type token")
				)
			]
		case "RealityKit.PointLight":
			return [
				InspectorComponentParameter(
					key: "color",
					label: "Color",
					kind: .text(defaultValue: "(1, 1, 1)", placeholder: "(r, g, b)")
				),
				InspectorComponentParameter(
					key: "intensity",
					label: "Intensity",
					kind: .scalar(defaultValue: 26963.76, unit: nil)
				),
				InspectorComponentParameter(
					key: "attenuationRadius",
					label: "Attenuation Radius",
					kind: .scalar(defaultValue: 10, unit: nil)
				),
				InspectorComponentParameter(
					key: "attenuationFalloff",
					label: "Attenuation Falloff",
					kind: .scalar(defaultValue: 2, unit: nil)
				)
			]
		case "RealityKit.SpotLight":
			return [
				InspectorComponentParameter(
					key: "color",
					label: "Color",
					kind: .text(defaultValue: "(1, 1, 1)", placeholder: "(r, g, b)")
				),
				InspectorComponentParameter(
					key: "intensity",
					label: "Intensity",
					kind: .scalar(defaultValue: 26963.76, unit: nil)
				),
				InspectorComponentParameter(
					key: "innerAngle",
					label: "Inner Angle",
					kind: .scalar(defaultValue: 45, unit: nil)
				),
				InspectorComponentParameter(
					key: "outerAngle",
					label: "Outer Angle",
					kind: .scalar(defaultValue: 45, unit: nil)
				),
				InspectorComponentParameter(
					key: "attenuationRadius",
					label: "Attenuation Radius",
					kind: .scalar(defaultValue: 10, unit: nil)
				),
				InspectorComponentParameter(
					key: "attenuationFalloff",
					label: "Attenuation Falloff",
					kind: .scalar(defaultValue: 2, unit: nil)
				),
				InspectorComponentParameter(
					key: "shadowEnabled",
					label: "Shadow Enabled",
					kind: .toggle(defaultValue: false)
				),
				InspectorComponentParameter(
					key: "shadowBias",
					label: "Shadow Bias",
					kind: .scalar(defaultValue: 0, unit: nil)
				),
				InspectorComponentParameter(
					key: "shadowCullMode",
					label: "Shadow Cull Mode",
					kind: .choice(defaultValue: "Default", options: ["Default", "Back", "Front", "None"])
				),
				InspectorComponentParameter(
					key: "shadowNear",
					label: "Shadow Near",
					kind: .choice(defaultValue: "Automatic", options: ["Automatic", "Fixed"])
				),
				InspectorComponentParameter(
					key: "shadowFar",
					label: "Shadow Far",
					kind: .choice(defaultValue: "Automatic", options: ["Automatic", "Fixed"])
				)
			]
		case "RealityKit.DirectionalLight":
			return [
				InspectorComponentParameter(
					key: "color",
					label: "Color",
					kind: .text(defaultValue: "(1, 1, 1)", placeholder: "(r, g, b)")
				),
				InspectorComponentParameter(
					key: "intensity",
					label: "Intensity",
					kind: .scalar(defaultValue: 26963.76, unit: nil)
				),
				InspectorComponentParameter(
					key: "shadowEnabled",
					label: "Shadow Enabled",
					kind: .toggle(defaultValue: false)
				),
				InspectorComponentParameter(
					key: "shadowBias",
					label: "Shadow Bias",
					kind: .scalar(defaultValue: 0, unit: nil)
				),
				InspectorComponentParameter(
					key: "shadowCullMode",
					label: "Shadow Cull Mode",
					kind: .choice(defaultValue: "Default", options: ["Default", "Back", "Front", "None"])
				),
				InspectorComponentParameter(
					key: "shadowProjectionType",
					label: "Shadow Projection",
					kind: .choice(defaultValue: "Automatic", options: ["Automatic", "Fixed"])
				),
				InspectorComponentParameter(
					key: "shadowOrthographicScale",
					label: "Orthographic Scale",
					kind: .scalar(defaultValue: 1, unit: nil)
				),
				InspectorComponentParameter(
					key: "shadowZBounds",
					label: "Z Bounds",
					kind: .text(defaultValue: "(0.02, 20)", placeholder: "(near, far)")
				)
			]
		default:
			return []
		}
	}
}

public enum InspectorComponentCatalog {
	public static let accessibility = InspectorComponentDefinition(
		name: "Accessibility",
		authoredPrimName: "Accessibility",
		category: .general,
		summary: "Enables an entity to be accessed by an assistive application.",
		identifier: "RealityKit.Accessibility"
	)

	// Catalog extracted from RCP UI + local USD fixtures.
	public static let all: [InspectorComponentDefinition] = [
		InspectorComponentDefinition(
			name: "Accessibility",
			authoredPrimName: "Accessibility",
			category: .general,
			summary: "Enables an entity to be accessed by an assistive application.",
			identifier: "RealityKit.Accessibility"
		),
		InspectorComponentDefinition(
			name: "Anchoring",
			authoredPrimName: "Anchoring",
			category: .general,
			summary: "Indicates how an entity will be attached to an anchor once loaded.",
			identifier: "RealityKit.Anchoring"
		),
		InspectorComponentDefinition(
			name: "Animation Library",
			authoredPrimName: "AnimationLibrary",
			category: .general,
			summary: "A collection of animations that an entity can play.",
			identifier: "RealityKit.AnimationLibrary"
		),
		InspectorComponentDefinition(
			name: "Behaviors",
			authoredPrimName: "RCP_BehaviorsContainer",
			category: .general,
			summary: "Provides entities a way to trigger specific timelines through various system inputs.",
			identifier: "RCP.BehaviorsContainer"
		),
		InspectorComponentDefinition(
			name: "Billboard",
			authoredPrimName: "Billboard",
			category: .general,
			summary: "Defines a specific viewing behavior relative to the user's view.",
			identifier: "RealityKit.Billboard"
		),
		InspectorComponentDefinition(
			name: "Character Controller",
			authoredPrimName: "CharacterController",
			category: .general,
			summary: "Manages the assigned entity's character movement.",
			identifier: "RealityKit.CharacterController"
		),
		InspectorComponentDefinition(
			name: "Docking Region",
			authoredPrimName: "CustomDockingRegion",
			category: .general,
			summary: "Predefines where a media player attaches in immersive view.",
			identifier: "RealityKit.CustomDockingRegion"
		),
		InspectorComponentDefinition(
			name: "Input Target",
			authoredPrimName: "InputTarget",
			category: .general,
			summary: "Enables the entity to receive system input.",
			identifier: "RealityKit.InputTarget"
		),
		InspectorComponentDefinition(
			name: "Model Sorting",
			authoredPrimName: "MeshSorting",
			category: .general,
			summary: "Allows an entity's models to be rendered in explicit order.",
			identifier: "RealityKit.MeshSorting"
		),
		InspectorComponentDefinition(
			name: "Opacity",
			authoredPrimName: "HierarchicalFade",
			category: .general,
			summary: "Adjusts visibility from 0 to 1.",
			identifier: "RealityKit.HierarchicalFade"
		),
		InspectorComponentDefinition(
			name: "Particle Emitter",
			authoredPrimName: "VFXEmitter",
			category: .general,
			summary: "Generates a particle emitter with configurable parameters.",
			identifier: "RealityKit.VFXEmitter"
		),
		InspectorComponentDefinition(
			name: "Scene Understanding",
			authoredPrimName: "SceneUnderstanding",
			category: .general,
			placement: .rootPrim,
			summary: "Specifies participation in scene-understanding features.",
			identifier: "RealityKit.SceneUnderstanding"
		),

		InspectorComponentDefinition(
			name: "Audio Library",
			authoredPrimName: "AudioLibrary",
			category: .audio,
			summary: "A collection of audio resources that an entity can play.",
			identifier: "RealityKit.AudioLibrary"
		),
		InspectorComponentDefinition(
			name: "Spatial Audio",
			authoredPrimName: "SpatialAudio",
			category: .audio,
			summary: "Configures spatial audio rendering from an entity.",
			identifier: "RealityKit.SpatialAudio"
		),
		InspectorComponentDefinition(
			name: "Ambient Audio",
			authoredPrimName: "AmbientAudio",
			category: .audio,
			summary: "Configures ambient rendering of sounds from an entity.",
			identifier: "RealityKit.AmbientAudio"
		),
		InspectorComponentDefinition(
			name: "Channel Audio",
			authoredPrimName: "ChannelAudio",
			category: .audio,
			summary: "Configures channel-based rendering of sounds from an entity.",
			identifier: "RealityKit.ChannelAudio"
		),
		InspectorComponentDefinition(
			name: "Audio Mix Groups",
			authoredPrimName: "AudioMixGroups",
			category: .audio,
			summary: "Assigns sounds to mix groups and applies mix adjustments.",
			identifier: "RealityKit.AudioMixGroups"
		),
		InspectorComponentDefinition(
			name: "Reverb",
			authoredPrimName: "Reverb",
			category: .audio,
			summary: "Applies reverb behavior in immersive spaces.",
			identifier: "RealityKit.Reverb"
		),

		InspectorComponentDefinition(
			name: "Directional Light",
			authoredPrimName: "DirectionalLight",
			category: .lighting,
			summary: "Defines a directional light source.",
			identifier: "RealityKit.DirectionalLight"
		),
		InspectorComponentDefinition(
			name: "Environment Lighting Configuration",
			authoredPrimName: "EnvironmentLightingConfiguration",
			category: .lighting,
			summary: "Adjusts indirect environment lighting configuration.",
			identifier: "RealityKit.EnvironmentLightingConfiguration"
		),
		InspectorComponentDefinition(
			name: "Grounding Shadow",
			authoredPrimName: "GroundingShadow",
			category: .lighting,
			summary: "Casts grounding shadows from a virtual overhead light.",
			identifier: "RealityKit.GroundingShadow"
		),
		InspectorComponentDefinition(
			name: "Image Based Light",
			authoredPrimName: "ImageBasedLight",
			category: .lighting,
			summary: "Inserts dedicated LatLong image or realityenv lighting.",
			identifier: "RealityKit.ImageBasedLight"
		),
		InspectorComponentDefinition(
			name: "Image Based Light Receiver",
			authoredPrimName: "ImageBasedLightReceiver",
			category: .lighting,
			summary: "Enables entities to receive specific IBL components.",
			identifier: "RealityKit.ImageBasedLightReceiver"
		),
		InspectorComponentDefinition(
			name: "Point Light",
			authoredPrimName: "PointLight",
			category: .lighting,
			summary: "Defines a point light source.",
			identifier: "RealityKit.PointLight"
		),
		InspectorComponentDefinition(
			name: "Spot Light",
			authoredPrimName: "SpotLight",
			category: .lighting,
			summary: "Defines a spot light source.",
			identifier: "RealityKit.SpotLight"
		),
		InspectorComponentDefinition(
			name: "Virtual Environment Probe",
			authoredPrimName: "VirtualEnvironmentProbe",
			category: .lighting,
			summary: "Defines a virtual environment probe for scene lighting.",
			identifier: "RealityKit.VirtualEnvironmentProbe"
		),

		InspectorComponentDefinition(
			name: "Collision",
			authoredPrimName: "Collider",
			category: .physics,
			summary: "Enables an entity to collide with other collision entities.",
			identifier: "RealityKit.Collider"
		),
		InspectorComponentDefinition(
			name: "Physics Body",
			authoredPrimName: "RigidBody",
			category: .physics,
			summary: "Defines entity behavior in physics body simulations.",
			identifier: "RealityKit.RigidBody"
		),
		InspectorComponentDefinition(
			name: "Physics Motion",
			authoredPrimName: "MotionState",
			category: .physics,
			summary: "Controls entity body motion in physics simulations.",
			identifier: "RealityKit.MotionState"
		)
	]

	public static var enabledForAuthoring: [InspectorComponentDefinition] {
		all.filter(\.isEnabledForAuthoring)
	}

	public static var grouped: [(InspectorComponentDefinition.Category, [InspectorComponentDefinition])] {
		InspectorComponentDefinition.Category.allCases.compactMap { category in
			let items = all.filter { $0.category == category }
			return items.isEmpty ? nil : (category, items)
		}
	}

	public static func definition(forAuthoredPrimName name: String) -> InspectorComponentDefinition? {
		all.first { $0.authoredPrimName == name }
	}
}
