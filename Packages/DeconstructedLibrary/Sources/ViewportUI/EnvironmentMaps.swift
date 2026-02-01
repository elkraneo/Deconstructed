import Foundation

/// Utilities for accessing bundled HDRI environment maps.
public enum EnvironmentMaps {

	/// Returns the paths to all available environment maps (ibl.hdr files).
	public static func availableEnvironments() -> [String] {
		guard let resourcesURL = environmentsRootURL() else {
			print("[EnvironmentMaps] Could not find environment resources directory")
			return []
		}

		let fileManager = FileManager.default
		guard let contents = try? fileManager.contentsOfDirectory(atPath: resourcesURL.path) else {
			print("[EnvironmentMaps] Could not list Environments directory")
			return []
		}

		// Find folders that contain ibl.hdr files
		var environments: [String] = []
		for folder in contents.sorted() {
			let iblURL = resourcesURL.appendingPathComponent(folder).appendingPathComponent("ibl.hdr")
			if fileManager.fileExists(atPath: iblURL.path) {
				environments.append(iblURL.path)
			}
		}

		print("[EnvironmentMaps] Found \(environments.count) environment maps")
		return environments
	}

	private static func environmentsRootURL() -> URL? {
		if let bundleURL = Bundle.main.url(forResource: "Environments", withExtension: "bundle") {
			return bundleURL
		}

		if let mainURL = Bundle.main.url(forResource: "Environments", withExtension: nil) {
			return mainURL
		}

		if let mainResourceURL = Bundle.main.resourceURL {
			let fallbackURL = mainResourceURL.appendingPathComponent("Environments")
			if FileManager.default.fileExists(atPath: fallbackURL.path) {
				return fallbackURL
			}
		}

		return nil
	}

	/// Returns a human-readable name for an environment path.
	/// Example: "/path/01_arquicklook_ibl/ibl.hdr" -> "Arquicklook Ibl"
	public static func displayName(for path: String) -> String {
		let url = URL(fileURLWithPath: path)
		let folderName = url.deletingLastPathComponent().lastPathComponent

		// Remove leading number prefix (e.g., "01_")
		let withoutPrefix = folderName.replacingOccurrences(
			of: #"^\d+_"#,
			with: "",
			options: .regularExpression
		)
		// Replace underscores with spaces and title case
		return withoutPrefix
			.replacingOccurrences(of: "_", with: " ")
			.capitalized
	}

	/// Returns the reference HDR path for a given IBL path.
	/// The reference HDR is used for skybox rendering.
	public static func referencePath(for iblPath: String) -> String? {
		let url = URL(fileURLWithPath: iblPath)
		let refURL = url.deletingLastPathComponent().appendingPathComponent("ref.hdr")
		if FileManager.default.fileExists(atPath: refURL.path) {
			return refURL.path
		}
		return nil
	}
}
