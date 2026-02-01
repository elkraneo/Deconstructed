import AppKit
import ComposableArchitecture
import CryptoKit
import Foundation
import USDInterop

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

public final class ThumbnailGenerator: @unchecked Sendable {
	private let cacheDirectory: URL
	private let renderSize: CGFloat = 512

	public init() {
		let bundleID = Bundle.main.bundleIdentifier ?? "edu.210x7.Deconstructed"
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
			if let cachedImage = NSImage(contentsOf: cachedPath),
			   cachedImage.size.width > 0, cachedImage.size.height > 0 {
				return cachedImage
			} else {
				try? FileManager.default.removeItem(at: cachedPath)
			}
		}

		return await generateThumbnail(url: url, output: cachedPath, size: renderSize)
	}

	private func generateThumbnail(url: URL, output: URL, size: CGFloat) async -> NSImage? {
		let bounds = USDInteropStage.sceneBounds(url: url)
		guard let bounds, bounds.maxExtent > 0 else {
			print("[ThumbnailGenerator] No bounds for: \(url.lastPathComponent)")
			return nil
		}

		let fov: Float = 60.0 * .pi / 180.0
		let distance = bounds.maxExtent / (2.0 * tan(fov / 2.0)) * 1.5

		let yawDeg: Float = 45.0
		let pitchDeg: Float = 20.0
		let yaw = yawDeg * .pi / 180.0
		let pitch = pitchDeg * .pi / 180.0

		let cameraPos = bounds.center + SIMD3<Float>(
			distance * sin(yaw) * cos(pitch),
			distance * sin(pitch),
			distance * cos(yaw) * cos(pitch)
		)

		let dir = bounds.center - cameraPos
		let horizontalDist = sqrt(dir.x * dir.x + dir.z * dir.z)
		let rotateY = atan2(dir.x, dir.z) * 180.0 / .pi
		let rotateX = -atan2(dir.y, horizontalDist) * 180.0 / .pi

		let sessionLayer = """
		#usda 1.0
		(
		    doc = "Deconstructed thumbnail session layer"
		)

		def Camera "ThumbnailCamera"
		{
		    float focalLength = 35
		    float horizontalAperture = 36
		    float verticalAperture = 24
		    float2 clippingRange = (0.01, 100000)
		    float3 xformOp:translate = (\(cameraPos.x), \(cameraPos.y), \(cameraPos.z))
		    float3 xformOp:rotateXYZ = (\(rotateX), \(rotateY), 0)
		    uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:rotateXYZ"]
		}
		"""

		let sessionURL = FileManager.default.temporaryDirectory.appendingPathComponent("thumb_\(UUID().uuidString).usda")
		do {
			try sessionLayer.write(to: sessionURL, atomically: true, encoding: .utf8)
		} catch {
			print("[ThumbnailGenerator] Failed to write session layer: \(error)")
			return nil
		}

		defer { try? FileManager.default.removeItem(at: sessionURL) }

		return await withCheckedContinuation { continuation in
			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/usr/bin/usdrecord")
			process.arguments = [
				"-w", String(Int(size)),
				"--sessionLayer", sessionURL.path,
				"--camera", "ThumbnailCamera",
				url.path,
				output.path
			]

			do {
				try process.run()
				process.waitUntilExit()

				if process.terminationStatus == 0 {
					continuation.resume(returning: NSImage(contentsOf: output))
				} else {
					print("[ThumbnailGenerator] usdrecord failed: \(process.terminationStatus)")
					continuation.resume(returning: nil)
				}
			} catch {
				print("[ThumbnailGenerator] Process error: \(error)")
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
		url.standardizedFileURL.absoluteString
	}
}
