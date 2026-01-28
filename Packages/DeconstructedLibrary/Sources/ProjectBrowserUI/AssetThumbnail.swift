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
				Image(systemName: "cube.transparent.fill")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.secondary)

			case .texture:
				Image(systemName: "photo.fill")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.blue)

			case .audio:
				Image(systemName: "waveform")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.purple)

			case .directory:
				Image(systemName: "folder.fill")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.orange)

			case .realityFile:
				Image(systemName: "arkit")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.cyan)

			case .swift:
				Image(systemName: "swift")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.orange)

			case .json:
				Image(systemName: "doc.text")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.gray)

			case .unknown:
				Image(systemName: "doc.fill")
					.font(.system(size: size * 0.4))
					.foregroundStyle(.gray)
			}
		}
		.frame(width: size, height: size)
	}
}
