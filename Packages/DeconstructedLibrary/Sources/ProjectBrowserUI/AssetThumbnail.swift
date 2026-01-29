import DeconstructedModels
import SwiftUI
import ProjectBrowserModels

struct AssetThumbnail: View {
	let item: AssetItem
	let size: CGFloat

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 8)
				.fill(.quaternary)

				switch item.fileType {
				case .usda, .usdz:
					Image(systemName: DeconstructedConstants.SFSymbol.cubeTransparentFill)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.secondary)

			case .texture:
				Image(systemName: DeconstructedConstants.SFSymbol.photoFill)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.blue)

			case .audio:
				Image(systemName: DeconstructedConstants.SFSymbol.waveform)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.purple)

			case .directory:
				Image(systemName: DeconstructedConstants.SFSymbol.folderFill)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.orange)

			case .realityFile:
				Image(systemName: DeconstructedConstants.SFSymbol.arkit)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.cyan)

			case .swift:
				Image(systemName: DeconstructedConstants.SFSymbol.swift)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.orange)

			case .json:
				Image(systemName: DeconstructedConstants.SFSymbol.docText)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.gray)

			case .unknown:
				Image(systemName: DeconstructedConstants.SFSymbol.docFill)
					.font(.system(size: size * 0.4))
					.foregroundStyle(.gray)
			}
		}
		.frame(width: size, height: size)
	}
}
