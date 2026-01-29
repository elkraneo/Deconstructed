import DeconstructedCore
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
		case .usda, .usdz: return DeconstructedConstants.SFSymbol.cubeTransparentFill
		case .texture: return DeconstructedConstants.SFSymbol.photoFill
		case .audio: return DeconstructedConstants.SFSymbol.waveform
		case .realityFile: return DeconstructedConstants.SFSymbol.arkit
		case .swift: return DeconstructedConstants.SFSymbol.swift
		case .json: return DeconstructedConstants.SFSymbol.docText
		case .directory: return DeconstructedConstants.SFSymbol.folderFill
		case .unknown: return DeconstructedConstants.SFSymbol.docFill
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
		case DeconstructedConstants.FileExtension.usda, DeconstructedConstants.FileExtension.usd:
			return .usda
		case DeconstructedConstants.FileExtension.usdz, DeconstructedConstants.FileExtension.usdc:
			return .usdz
		case DeconstructedConstants.FileExtension.png, DeconstructedConstants.FileExtension.jpg,
			 DeconstructedConstants.FileExtension.jpeg, DeconstructedConstants.FileExtension.exr,
			 DeconstructedConstants.FileExtension.hdr:
			return .texture
		case DeconstructedConstants.FileExtension.wav, DeconstructedConstants.FileExtension.mp3,
			 DeconstructedConstants.FileExtension.aiff:
			return .audio
		case DeconstructedConstants.FileExtension.reality:
			return .realityFile
		case DeconstructedConstants.FileExtension.swift:
			return .swift
		case DeconstructedConstants.FileExtension.json:
			return .json
		default:
			return .unknown
		}
	}
}
