import AppKit
import ComposableArchitecture
import CryptoKit
import Foundation

@DependencyClient
public struct ThumbnailClient: Sendable {
	public var generate: @Sendable (_ url: URL, _ size: CGFloat) async -> NSImage?
	public var invalidate: @Sendable (_ url: URL) async -> Void
}

extension ThumbnailClient: DependencyKey {
	public static let liveValue: Self = {
		let generator = ThumbnailGenerator()
		return Self(
			generate: { url, size in await generator.thumbnail(for: url, size: size) },
			invalidate: { url in await generator.invalidateCache(for: url) }
		)
	}()
}

/// Generates thumbnails for USD files using Apple's usdrecord tool
public actor ThumbnailGenerator {
	private let cacheDirectory: URL
	private var inFlightTasks: [URL: Task<NSImage?, Never>] = [:]
	private let renderSize: CGFloat = 512

	public init() {
		let bundleID = Bundle.main.bundleIdentifier ?? "com.stepintovision.Deconstructed"
		self.cacheDirectory = FileManager.default
			.urls(for: .cachesDirectory, in: .userDomainMask)
			.first?
			.appendingPathComponent(bundleID, isDirectory: true)
			.appendingPathComponent("Thumbnails", isDirectory: true)
			?? FileManager.default.temporaryDirectory.appendingPathComponent("DeconstructedThumbnails", isDirectory: true)
		try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
	}

	public func thumbnail(for url: URL, size: CGFloat = 256) async -> NSImage? {
		let cacheKey = cacheKeyBase(for: url)
		let cachedPath = cacheDirectory.appendingPathComponent("\(cacheKey).png")

		if FileManager.default.fileExists(atPath: cachedPath.path) {
			return NSImage(contentsOf: cachedPath)
		}

		if let existingTask = inFlightTasks[url] {
			return await existingTask.value
		}

		let task = Task<NSImage?, Never> {
			return await generateThumbnail(url: url, output: cachedPath, size: renderSize)
		}
		inFlightTasks[url] = task
		let result = await task.value
		inFlightTasks[url] = nil
		return result
	}

	private func generateThumbnail(url: URL, output: URL, size: CGFloat) async -> NSImage? {
		await withCheckedContinuation { continuation in
			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/usr/bin/usdrecord")
			process.arguments = [
				"-w", String(Int(size)),
				url.path,
				output.path
			]

			do {
				try process.run()
				process.waitUntilExit()

				if process.terminationStatus == 0 {
					continuation.resume(returning: NSImage(contentsOf: output))
				} else {
					continuation.resume(returning: nil)
				}
			} catch {
				continuation.resume(returning: nil)
			}
		}
	}

	public func invalidateCache(for url: URL) {
		let cacheKey = cacheKeyBase(for: url)
		let cachedPath = cacheDirectory.appendingPathComponent("\(cacheKey).png")
		try? FileManager.default.removeItem(at: cachedPath)
	}

	private func cacheKeyBase(for url: URL) -> String {
		let digest = Insecure.MD5.hash(data: Data(hashInput(for: url).utf8))
		return digest.map { String(format: "%02x", $0) }.joined()
	}

	private func hashInput(for url: URL) -> String {
		// Mirrors RCP shape (MD5 hex filename) with an easily swappable input source.
		// Replace this when we discover RCP's internal hashing input.
		url.standardizedFileURL.absoluteString
	}
}
