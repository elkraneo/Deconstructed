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

/// Generates thumbnails for USD files using Apple's usdrecord tool
public actor ThumbnailGenerator {
	private let cacheDirectory: URL
	private let sessionLayerDirectory: URL
	private var inFlightTasks: [URL: Task<NSImage?, Never>] = [:]
	private let renderSize: CGFloat = 512

	public init() {
		let bundleID = Bundle.main.bundleIdentifier ?? "com.stepintovision.Deconstructed"
		let cacheBase = FileManager.default
			.urls(for: .cachesDirectory, in: .userDomainMask)
			.first?
			.appendingPathComponent(bundleID, isDirectory: true)
			?? FileManager.default.temporaryDirectory.appendingPathComponent(bundleID, isDirectory: true)

		self.cacheDirectory = cacheBase.appendingPathComponent("Thumbnails", isDirectory: true)
		self.sessionLayerDirectory = cacheBase.appendingPathComponent("SessionLayers", isDirectory: true)
		try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
		try? FileManager.default.createDirectory(at: sessionLayerDirectory, withIntermediateDirectories: true)
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
		// Generate session layer with positioned camera
		let sessionLayerPath = sessionLayerDirectory.appendingPathComponent("\(cacheKeyBase(for: url))_session.usda")
		print("[ThumbnailGenerator] Generating thumbnail for: \(url.lastPathComponent)")
		let sessionLayerCreated = createSessionLayer(for: url, output: sessionLayerPath)
		print("[ThumbnailGenerator] Session layer created: \(sessionLayerCreated) at \(sessionLayerPath.path)")

		return await withCheckedContinuation { continuation in
			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/usr/bin/usdrecord")

			var args = ["-w", String(Int(size))]

			// Add session layer and camera if we successfully created one
			if sessionLayerCreated {
				args.append(contentsOf: ["--sessionLayer", sessionLayerPath.path])
				args.append(contentsOf: ["--camera", "ThumbnailCamera"])
			}

			args.append(contentsOf: [url.path, output.path])
			process.arguments = args

			do {
				try process.run()
				process.waitUntilExit()

				// Clean up session layer
				if sessionLayerCreated {
					try? FileManager.default.removeItem(at: sessionLayerPath)
				}

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

	/// Creates a session layer with a camera positioned to frame the scene.
	private func createSessionLayer(for url: URL, output: URL) -> Bool {
		let bounds = USDInteropStage.sceneBounds(url: url)
		print("[ThumbnailGenerator] Bounds for \(url.lastPathComponent): \(String(describing: bounds))")
		guard let bounds, bounds.maxExtent > 0 else {
			print("[ThumbnailGenerator] No valid bounds for \(url.lastPathComponent)")
			return false
		}

		// Camera positioning math (matches ViewportView.frameScene)
		let fov: Float = 60.0 * .pi / 180.0
		let distance = bounds.maxExtent / (2.0 * tan(fov / 2.0)) * 1.5

		// Position camera at an angle (slightly above and to the side)
		// Spherical coordinates: yaw around Y axis, pitch down from horizontal
		let yawDeg: Float = 45.0
		let pitchDeg: Float = 20.0  // Positive = looking down
		let yaw = yawDeg * .pi / 180.0
		let pitch = pitchDeg * .pi / 180.0

		// Camera position in world space (center + spherical offset)
		let cameraPos = bounds.center + SIMD3<Float>(
			distance * sin(yaw) * cos(pitch),
			distance * sin(pitch),
			distance * cos(yaw) * cos(pitch)
		)

		// Compute Euler angles to look at center
		// Direction from camera to center (where we want to look)
		let dir = bounds.center - cameraPos
		let horizontalDist = sqrt(dir.x * dir.x + dir.z * dir.z)

		// rotateY = atan2(x, z) - rotation around Y axis in degrees
		// rotateX = -atan2(y, horiz) - negative because looking down needs positive X rotation
		let rotateY = atan2(dir.x, dir.z) * 180.0 / .pi
		let rotateX = -atan2(dir.y, horizontalDist) * 180.0 / .pi

		print("[ThumbnailGenerator] Camera pos: \(cameraPos), rotateXYZ: (\(rotateX), \(rotateY), 0)")

		// Generate USDA session layer
		let usda = """
		#usda 1.0
		(
		    doc = "Deconstructed thumbnail session layer"
		)

		def Camera "ThumbnailCamera"
		{
		    float focalLength = 35
		    float horizontalAperture = 36
		    float verticalAperture = 24
		    float2 clippingRange = (0.001, 1000)
		    float3 xformOp:translate = (\(cameraPos.x), \(cameraPos.y), \(cameraPos.z))
		    float3 xformOp:rotateXYZ = (\(rotateX), \(rotateY), 0)
		    uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:rotateXYZ"]
		}
		"""

		do {
			try usda.write(to: output, atomically: true, encoding: .utf8)
			return true
		} catch {
			print("[ThumbnailGenerator] Failed to create session layer: \(error)")
			return false
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
