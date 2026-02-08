import AppKit
import RealityKit

/// Factory for creating the outline `ShaderGraphMaterial` / `CustomMaterial`.
enum OutlineMaterial {
	/// Creates an unlit material that extrudes geometry along normals
	/// and renders only back-faces, producing an inverted-hull outline.
	static func make(configuration: OutlineConfiguration) throws -> any RealityKit.Material {
		// Use a simple UnlitMaterial with the outline color.
		// The geometry extrusion is handled by the outline entity's scale offset,
		// and front-face culling gives us the outline silhouette.
		var material = UnlitMaterial()
		let cgColor = configuration.color.cgColor.converted(
			to: CGColorSpaceCreateDeviceRGB(),
			intent: .defaultIntent,
			options: nil
		) ?? CGColor(red: 1, green: 0.5, blue: 0, alpha: 1)

		let r = Float(cgColor.components?[0] ?? 1)
		let g = Float(cgColor.components?[1] ?? 0.5)
		let b = Float(cgColor.components?[2] ?? 0)

		material.color = .init(
			tint: .init(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
		)
		material.faceCulling = .front
		return material
	}
}
