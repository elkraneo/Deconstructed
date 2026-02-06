import AppKit
import ComposableArchitecture
import CryptoKit
import DeconstructedUSDInterop
import Foundation

@DependencyClient
public struct ThumbnailClient: Sendable {
	public var generate: @Sendable (_ url: URL, _ size: CGFloat) async -> NSImage? = { _, _ in nil }
	public var invalidate: @Sendable (_ url: URL) async -> Void = { _ in }
}

extension ThumbnailClient: DependencyKey {
	public static var liveValue: Self {
		let generator = ThumbnailGenerator()
		return Self(
			generate: { @Sendable url, size in await generator.thumbnail(for: url, size: size) },
			invalidate: { @Sendable url in await generator.invalidateCache(for: url) }
		)
	}
}

public actor ThumbnailGenerator {
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

		// Check for cached thumbnail - use Data-based loading for reliability
		if FileManager.default.fileExists(atPath: cachedPath.path) {
			if let imageData = try? Data(contentsOf: cachedPath),
			   let cachedImage = NSImage(data: imageData),
			   cachedImage.size.width > 0, cachedImage.size.height > 0 {
				print("[ThumbnailGenerator] Using cached thumbnail for: \(url.lastPathComponent)")
				return cachedImage
			} else {
				print("[ThumbnailGenerator] Invalid cache entry, removing: \(url.lastPathComponent)")
				try? FileManager.default.removeItem(at: cachedPath)
			}
		}

		return await generateThumbnail(url: url, output: cachedPath, size: renderSize)
	}

	private func generateThumbnail(url: URL, output: URL, size: CGFloat) async -> NSImage? {
		let bounds = try? DeconstructedUSDInterop.getSceneBounds(url: url)
		if let bounds, bounds.maxExtent > 0 {
			print("[ThumbnailGenerator] Using bounds-based camera for: \(url.lastPathComponent)")
			return await generateThumbnailWithBounds(url: url, output: output, size: size, bounds: bounds)
		} else {
			print("[ThumbnailGenerator] No bounds for: \(url.lastPathComponent), falling back to default camera")
			return await generateThumbnailWithDefaultCamera(url: url, output: output, size: size)
		}
	}

	private func generateThumbnailWithBounds(
		url: URL,
		output: URL,
		size: CGFloat,
		bounds: USDSceneBounds
	) async -> NSImage? {
		// Default camera is at (0, 0, 10) looking at origin
		// We want to position camera based on scene bounds
		let fov: Float = 60.0 * .pi / 180.0
		let distance = bounds.maxExtent / (2.0 * tan(fov / 2.0)) * 2.0 // 2x for safety margin

		// Position camera at isometric angle
		let yawDeg: Float = 45.0
		let pitchDeg: Float = 30.0
		let yaw = yawDeg * .pi / 180.0
		let pitch = pitchDeg * .pi / 180.0

		// Calculate camera position relative to scene center
		let offset = SIMD3<Float>(
			distance * sin(yaw) * cos(pitch),
			distance * sin(pitch),
			distance * cos(yaw) * cos(pitch)
		)
		let cameraPos = bounds.center + offset

		// Camera rotation uses the same yaw/pitch angles used for positioning.
		// The camera looks DOWN at the scene, so pitch is negated.
		// rotateY (yaw) rotates the camera to face the scene.
		let rotateX = -pitchDeg  // Negative pitch to look down at the scene
		let rotateY = yawDeg     // Same yaw angle used for camera position

		print("[ThumbnailGenerator] Camera position: (\(cameraPos.x), \(cameraPos.y), \(cameraPos.z))")
		print("[ThumbnailGenerator] Camera rotation: (\(rotateX), \(rotateY), 0)")
		print("[ThumbnailGenerator] Scene bounds center: (\(bounds.center.x), \(bounds.center.y), \(bounds.center.z))")
		print("[ThumbnailGenerator] Scene maxExtent: \(bounds.maxExtent)")

			// Position camera and rotate it to look at the scene.
		// xformOpOrder applies left-to-right: translate to position, then rotate in place.
		
		let sessionLayer = """
		#usda 1.0
		(
		    doc = "Deconstructed thumbnail session layer"
		    metersPerUnit = 1
		    upAxis = "Y"
		)

		def Xform "CameraXform"
		{
		    float3 xformOp:translate = (\(cameraPos.x), \(cameraPos.y), \(cameraPos.z))
		    float3 xformOp:rotateXYZ = (\(rotateX), \(rotateY), 0)
		    uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:rotateXYZ"]

		    def Camera "ThumbnailCamera"
		    {
		        float focalLength = 50
		        float horizontalAperture = 36
		        float verticalAperture = 24
		        float2 clippingRange = (0.001, 10000)
		        token projection = "perspective"
		    }
		}
		"""

		let sessionURL = FileManager.default.temporaryDirectory.appendingPathComponent("thumb_\(UUID().uuidString).usda")
		do {
			try sessionLayer.write(to: sessionURL, atomically: true, encoding: .utf8)
			// Debug: print the session layer
			if let content = try? String(contentsOf: sessionURL, encoding: .utf8) {
				print("[ThumbnailGenerator] Session layer contents:\n\(content)")
			}
		} catch {
			print("[ThumbnailGenerator] Failed to write session layer: \(error)")
			return nil
		}

		defer { try? FileManager.default.removeItem(at: sessionURL) }

		return await runUsdrecord(url: url, output: output, size: size, sessionLayer: sessionURL, cameraName: "/CameraXform/ThumbnailCamera")
	}

	private func generateThumbnailWithDefaultCamera(url: URL, output: URL, size: CGFloat) async -> NSImage? {
		return await runUsdrecord(url: url, output: output, size: size, sessionLayer: nil, cameraName: nil)
	}

	private func runUsdrecord(url: URL, output: URL, size: CGFloat, sessionLayer: URL?, cameraName: String?) async -> NSImage? {
		await withCheckedContinuation { continuation in
			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/usr/bin/usdrecord")

			var arguments: [String] = [
				"-w", String(Int(size))
			]

			if let sessionLayer = sessionLayer {
				arguments.append("--sessionLayer")
				arguments.append(sessionLayer.path)
			}

			if let cameraName = cameraName {
				arguments.append("--camera")
				arguments.append(cameraName)
			}

			arguments.append(url.path)
			arguments.append(output.path)

			process.arguments = arguments
			
			print("[ThumbnailGenerator] Running usdrecord for: \(url.lastPathComponent)")
			print("[ThumbnailGenerator] Output path: \(output.path)")

			do {
				try process.run()
				process.waitUntilExit()

				if process.terminationStatus == 0 {
					// Check if file exists and has content
					let fileManager = FileManager.default
					if fileManager.fileExists(atPath: output.path) {
						if let attrs = try? fileManager.attributesOfItem(atPath: output.path),
						   let fileSize = attrs[.size] as? UInt64 {
							print("[ThumbnailGenerator] Output file exists, size: \(fileSize) bytes")
							
						if fileSize > 0 {
							// Small delay to ensure file is fully written and flushed
							Thread.sleep(forTimeInterval: 0.05) // 50ms
							
							// Load image using Data for better compatibility
							if let imageData = try? Data(contentsOf: output),
							   let image = NSImage(data: imageData) {
								print("[ThumbnailGenerator] Successfully loaded image: \(image.size.width)x\(image.size.height)")
								continuation.resume(returning: image)
								return
							} else {
								print("[ThumbnailGenerator] Failed to load NSImage from output file")
							}
						} else {
								print("[ThumbnailGenerator] Output file is empty")
							}
						} else {
							print("[ThumbnailGenerator] Could not get file attributes")
						}
					} else {
						print("[ThumbnailGenerator] Output file does not exist: \(output.path)")
					}
					continuation.resume(returning: nil)
				} else {
					print("[ThumbnailGenerator] usdrecord failed with exit code: \(process.terminationStatus)")
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
