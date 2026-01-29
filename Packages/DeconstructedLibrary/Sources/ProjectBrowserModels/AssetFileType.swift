import Foundation

public enum AssetFileType: String, CaseIterable, Sendable, Equatable {
	case usda
	case usdz
	case texture      // .png, .jpg, .exr, .hdr
	case audio        // .wav, .mp3, .aiff
	case realityFile  // .reality
	case swift
	case json
	case directory
	case unknown

	public var iconName: String {
		switch self {
		case .usda, .usdz: return "cube.transparent.fill"
		case .texture: return "photo.fill"
		case .audio: return "waveform"
		case .realityFile: return "arkit"
		case .swift: return "swift"
		case .json: return "doc.text"
		case .directory: return "folder.fill"
		case .unknown: return "doc.fill"
		}
	}

	public var displayName: String {
		switch self {
		case .usda: return "USD ASCII"
		case .usdz: return "USDZ"
		case .texture: return "Texture"
		case .audio: return "Audio"
		case .realityFile: return "Reality File"
		case .swift: return "Swift"
		case .json: return "JSON"
		case .directory: return "Folder"
		case .unknown: return "Unknown"
		}
	}

	/// File types that can be browsed in the filter
	public static var browsable: [AssetFileType] {
		[.usda, .usdz, .texture, .audio, .realityFile, .swift]
	}

	/// Determines file type from URL extension
	public static func from(_ url: URL) -> AssetFileType {
		let ext = url.pathExtension.lowercased()
		switch ext {
		case "usda", "usd": return .usda
		case "usdz", "usdc": return .usdz
		case "png", "jpg", "jpeg", "exr", "hdr": return .texture
		case "wav", "mp3", "aiff": return .audio
		case "reality": return .realityFile
		case "swift": return .swift
		case "json": return .json
		default: return .unknown
		}
	}
}
