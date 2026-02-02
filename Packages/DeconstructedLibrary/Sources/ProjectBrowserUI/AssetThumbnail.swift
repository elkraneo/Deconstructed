import AppKit
import DeconstructedModels
import ProjectBrowserClients
import SwiftUI
import ProjectBrowserModels

struct AssetThumbnail: View {
	let item: AssetItem
	let size: CGFloat
	/// Optional version ID that changes when thumbnail should be reloaded
	let thumbnailVersion: UUID?
	@State private var thumbnail: NSImage?
	@State private var refreshID = UUID()

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
				placeholderIcon
			}
		}
		.frame(width: size, height: size)
		.id(refreshID) // Force redraw when thumbnail loads
		.task(id: TaskID(item: item, version: thumbnailVersion)) {
			await loadThumbnail()
		}
	}

	/// Composite task ID that includes both item ID and thumbnail version
	private struct TaskID: Hashable {
		let itemID: AssetItem.ID
		let version: UUID?

		init(item: AssetItem, version: UUID?) {
			self.itemID = item.id
			self.version = version
		}
	}

	@ViewBuilder
	private var placeholderIcon: some View {
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

	private func loadThumbnail() async {
		guard item.fileType == .usda || item.fileType == .usdz else {
			thumbnail = nil
			return
		}
		
		print("[AssetThumbnail] Loading thumbnail for: \(item.url.lastPathComponent)")
		let loadedThumbnail = await Self.thumbnailGenerator.thumbnail(for: item.url, size: size)
		
		await MainActor.run {
			if let loadedThumbnail {
				print("[AssetThumbnail] Got thumbnail: \(loadedThumbnail.size.width)x\(loadedThumbnail.size.height) for \(item.url.lastPathComponent)")
				self.thumbnail = loadedThumbnail
				self.refreshID = UUID() // Force view refresh
			} else {
				print("[AssetThumbnail] No thumbnail returned for: \(item.url.lastPathComponent)")
			}
		}
	}
}
