import AppKit
import DeconstructedModels
import ProjectBrowserClients
import SwiftUI
import ProjectBrowserModels

struct AssetThumbnail: View {
	let item: AssetItem
	let size: CGFloat
	@State private var thumbnail: NSImage?

	private static let thumbnailGenerator = ThumbnailGenerator()

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 8)
				.fill(.quaternary)

			if let thumbnail {
				Image(nsImage: thumbnail)
					.resizable()
					.scaledToFit()
					.padding(6)
			} else {
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
		}
		.frame(width: size, height: size)
		.task(id: thumbnailTaskKey) {
			await loadThumbnail()
		}
	}

	private var thumbnailTaskKey: String {
		"\(item.url.path)|\(Int(size))"
	}

	private func loadThumbnail() async {
		guard item.fileType == .usda || item.fileType == .usdz else {
			await MainActor.run { thumbnail = nil }
			return
		}
		let image = await Self.thumbnailGenerator.thumbnail(for: item.url, size: size)
		await MainActor.run {
			self.thumbnail = image
			print("[AssetThumbnail] Set thumbnail for \(item.name): \(image != nil ? "YES" : "nil")")
		}
	}
}
