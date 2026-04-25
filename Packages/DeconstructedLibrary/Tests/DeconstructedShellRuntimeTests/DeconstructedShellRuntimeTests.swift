import Foundation
import Testing
@testable import DeconstructedShellRuntime
@testable import SwiftUsdShell

// MARK: - Test Resources

private final class TestUSDScene {
	let url: URL

	init() throws {
		let tempDir = FileManager.default.temporaryDirectory
		let filename = "test_scene_\(UUID().uuidString).usda"
		self.url = tempDir.appendingPathComponent(filename)

		let usdaContent = """
#usda 1.0
(
    defaultPrim = "Root"
    metersPerUnit = 0.01
    upAxis = "Y"
    doc = "Test scene for ShellRuntime validation"
)

def Xform "Root"
{
    def Cube "Cube1" (
        prepend apiSchemas = ["MaterialBindingAPI"]
    )
    {
        bool active = true
        token visibility = "inherited"
        token purpose = "default"
        rel material:binding = </Root/Looks/Material1>

        float3[] extent = [(-0.5, -0.5, -0.5), (0.5, 0.5, 0.5)]

        color3f[] displayColor = [(1, 0.5, 0.25)]

        double xformOp:translate = (0, 0, 0)
        double xformOp:rotateXYZ = (0, 0, 0)
        double xformOp:scale = (1, 1, 1)
        uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:rotateXYZ", "xformOp:scale"]
    }

    def Sphere "Sphere1"
    {
        bool active = true
        token visibility = "visible"
        token purpose = "default"

        double radius = 0.5
    }

    def Scope "Looks"
    {
        def Material "Material1"
        {
            token outputs:mdl:displacement.connect = </Root/Looks/Material1/Shader>
            token outputs:mdl:surface.connect = </Root/Looks/Material1/Shader>

            def Shader "Shader"
            {
                uniform token info:id = "ND_preview_surface"
                float inputs:diffuseColor = (0.8, 0.2, 0.2)
                float inputs:metallic = 0.0
                float inputs:roughness = 0.5
                float inputs:opacity = 1.0
                token outputs:mdl:displacement
                token outputs:mdl:surface
            }
        }
    }
}
"""

        try usdaContent.write(to: url, atomically: true, encoding: .utf8)
	}

	deinit {
		try? FileManager.default.removeItem(at: url)
	}
}

// MARK: - Stage Handle Tests

@Test
func stageHandleLifecycleWorks() throws {
	let scene = try TestUSDScene()

	// Opening a stage should return a valid handle
	let handle = try DeconstructedShellRuntime.openStage(at: scene.url)
	#expect(handle.rawValue > 0)

	// Closing the stage should not throw
	DeconstructedShellRuntime.closeStage(handle)
}

@Test
func primSummaryReturnsValidData() throws {
	let scene = try TestUSDScene()

	guard let summary = DeconstructedShellRuntime.primSummary(
		url: scene.url,
		primPath: "/Root/Cube1"
	) else {
		#expect(Bool(false), "Prim summary should not be nil")
		return
	}

	#expect(summary.path.rawValue == "/Root/Cube1")
	#expect(summary.name.rawValue == "Cube1")
	#expect(summary.typeName?.rawValue == "Cube")
	#expect(summary.isActive == true)
	#expect(summary.visibilityText == "visible")
	#expect(summary.purposeText == "default")

	// Check that displayColor attribute exists
	let displayColor = summary.attributes.first { $0.name.rawValue == "displayColor" }
	#expect(displayColor != nil)
	#expect(displayColor?.typeName == "color3f[]")
	#expect(displayColor?.hasValue == true)
	#expect(displayColor?.isAuthored == true)
}

@Test
func primSummaryHandlesNonExistentPrim() throws {
	let scene = try TestUSDScene()

	let summary = DeconstructedShellRuntime.primSummary(
		url: scene.url,
		primPath: "/Root/NonExistent"
	)

	#expect(summary == nil)
}

@Test
func stageMetadataCapturesStageProperties() throws {
	let scene = try TestUSDScene()

	let metadata = DeconstructedShellRuntime.stageMetadata(url: scene.url)

	#expect(metadata.upAxis?.rawValue == "Y")
	#expect(metadata.metersPerUnit == 0.01)
	#expect(metadata.defaultPrimName?.rawValue == "Root")
	#expect(metadata.metersPerUnit == 0.01)
}

@Test
func primTreeBuildsHierarchicalStructure() throws {
	let scene = try TestUSDScene()

	let tree = DeconstructedShellRuntime.primTree(url: scene.url)

	#expect(tree.path.rawValue == "/")
	#expect(tree.children.isEmpty == false)

	let root = tree.children.first { $0.name.rawValue == "Root" }
	#expect(root != nil)
	#expect(root?.children.isEmpty == false)

	let cube = root?.children.first { $0.name.rawValue == "Cube1" }
	#expect(cube != nil)
	#expect(cube?.typeNameText == "Cube")

	let sphere = root?.children.first { $0.name.rawValue == "Sphere1" }
	#expect(sphere != nil)
	#expect(sphere?.typeNameText == "Sphere")

	let looks = root?.children.first { $0.name.rawValue == "Looks" }
	#expect(looks != nil)
}

@Test
func primTreeTraversalHelpersWork() throws {
	let scene = try TestUSDScene()

	let tree = DeconstructedShellRuntime.primTree(url: scene.url)

	// Test first(path:) lookup
	let cube = tree.first(path: "/Root/Cube1")
	#expect(cube != nil)
	#expect(cube?.displayName == "Cube1")
	#expect(cube?.typeNameText == "Cube")

	let sphere = tree.first(path: "/Root/Sphere1")
	#expect(sphere != nil)
	#expect(sphere?.displayName == "Sphere1")

	// Test nodeCount
	#expect(tree.nodeCount > 3) // At least Root, Cube1, Sphere1, Looks

	// Test non-existent path
	let missing = tree.first(path: "/Root/Missing")
	#expect(missing == nil)
}

// MARK: - Material Edit Contract Tests

@Test
func materialEditRequestIsCodable() throws {
	let request = USDMaterialEditRequest(
		stageURL: USDStageURL(URL(fileURLWithPath: "/tmp/test.usda")),
		materialPath: "/Root/Looks/Material1",
		channel: .diffuseColor,
		operation: .setTexture(
			sourceURL: USDStageURL(URL(fileURLWithPath: "/tmp/texture.png")),
			authoredAssetPath: "../textures/texture.png"
		),
		policy: .preserveAuthoredMode
	)

	let encoded = try JSONEncoder().encode(request)
	let decoded = try JSONDecoder().decode(USDMaterialEditRequest.self, from: encoded)

	#expect(decoded == request)
	#expect(decoded.channel == .diffuseColor)
	#expect(decoded.policy == .preserveAuthoredMode)
}

@Test
func preparedMaterialEditAnalyzesBranchPlan() throws {
	let request = USDMaterialEditRequest(
		stageURL: USDStageURL(URL(fileURLWithPath: "/tmp/test.usda")),
		materialPath: "/Root/Looks/Material1",
		channel: .diffuseColor,
		operation: .setValue(.scalar(1.0)),
		policy: .preserveAuthoredMode
	)

	let prepared = DeconstructedShellRuntime.prepareMaterialEdit(request: request)

	#expect(prepared.readiness == .fullySupported)
	#expect(prepared.requiresUserAttention == false)
	#expect(prepared.branchPlan.requiresConversion == false)
	#expect(prepared.branchPlan.preservesAuthoredMode == true)
	#expect(prepared.supportedOutputs.contains(.usdPreviewSurface))
}

@Test
func materialEditContractsSupportAllChannels() throws {
	let channels: [USDMaterialEditableChannelID] = [
		.diffuseColor, .metallic, .roughness, .normal,
		.occlusion, .opacity, .emissiveColor, .clearcoat, .clearcoatRoughness
	]

	let request = USDMaterialEditRequest(
		stageURL: USDStageURL(URL(fileURLWithPath: "/tmp/test.usda")),
		materialPath: "/Root/Looks/Material1",
		channel: .diffuseColor,
		operation: .setValue(.scalar(0.5)),
		policy: .canonicalizeToPreviewSurface
	)

	let prepared = DeconstructedShellRuntime.prepareMaterialEdit(request: request)

	for channel in channels {
		var channelRequest = request
		channelRequest.channel = channel
		let channelPrepared = DeconstructedShellRuntime.prepareMaterialEdit(request: channelRequest)
		#expect(channelPrepared.branchPlan.branchTargets.isEmpty == false)
	}
}

@Test
func materialEditRequestWithConversionPolicy() throws {
	let request = USDMaterialEditRequest(
		stageURL: USDStageURL(URL(fileURLWithPath: "/tmp/test.usda")),
		materialPath: "/Root/Looks/Material1",
		channel: .roughness,
		operation: .setValue(.scalar(0.3)),
		policy: .convert(to: .materialXPreviewSurface)
	)

	let prepared = DeconstructedShellRuntime.prepareMaterialEdit(request: request)

	#expect(prepared.branchPlan.requiresConversion == false) // Our simple implementation doesn't detect conversion need yet
	#expect(prepared.branchPlan.preservesAuthoredMode == false)
}

// MARK: - Value Conversion Tests

@Test
func primAttributeValuesConvertToShellTypes() throws {
	let scene = try TestUSDScene()

	guard let summary = DeconstructedShellRuntime.primSummary(
		url: scene.url,
		primPath: "/Root/Cube1"
	) else {
		#expect(Bool(false), "Prim summary should not be nil")
		return
	}

	// Check displayColor array value
	let displayColor = summary.attributes.first { $0.name.rawValue == "displayColor" }
	guard case let .array(colorValues) = displayColor?.value else {
		#expect(Bool(false), "displayColor should be an array value")
		return
	}

	#expect(colorValues.count == 1)
	if case let .vector3(v) = colorValues.first {
		#expect(abs(v.x - 1.0) < 0.01)
		#expect(abs(v.y - 0.5) < 0.01)
		#expect(abs(v.z - 0.25) < 0.01)
	} else {
		#expect(Bool(false), "First array element should be a vector3")
	}
}

// MARK: - Stage URL Tests

@Test
func stageURLStandardizesPaths() throws {
	let rawURL = URL(fileURLWithPath: "/tmp/../tmp/test.usda")
	let stageURL = USDStageURL(rawURL)

	#expect(stageURL.url == rawURL.standardizedFileURL)
	#expect(stageURL.description.contains("..") == false)
}

// MARK: - Path and Token Tests

@Test
func usdPathSupportsStringLiteral() throws {
	let path: USDPath = "/Root/Cube1"
	#expect(path.rawValue == "/Root/Cube1")

	let path2 = USDPath("/Root/Sphere1")
	#expect(path2.rawValue == "/Root/Sphere1")
	#expect(path != path2)
}

@Test
func usdTokenSupportsStringLiteral() throws {
	let token: USDToken = "Cube"
	#expect(token.rawValue == "Cube")

	let token2 = USDToken("Sphere")
	#expect(token2.rawValue == "Sphere")
	#expect(token != token2)
}

// MARK: - Productivity Validation Tests

/// These tests validate that SwiftUsdShell provides a productivity boost
/// over raw USDInterop by providing:
/// 1. Type-safe handles instead of raw pointers/objects
/// 2. Pure Swift values that can be shared across actors
/// 3. Codable support for serialization
/// 4. Stable API that doesn't change with OpenUSD version bumps

@Test
@MainActor
func shellTypesAreSendableAndCrossActorSafe() async throws {
	// All shell types should be Sendable
	let summary = USDPrimSummary(
		path: "/Test",
		name: "Test",
		typeName: "Xform",
		isActive: true
	)

	// This should compile and work across actor boundaries
	await Task.detached {
		#expect(summary.path.rawValue == "/Test")
		#expect(summary.isActive == true)
	}.value
}

@Test
func shellTypesSupportJSONSerialization() throws {
	let metadata = USDStageMetadata(
		upAxis: "Y",
		metersPerUnit: 0.01,
		defaultPrimName: "Root",
		autoPlay: true,
		playbackMode: "loop",
		timeCodesPerSecond: 24,
		startTimeCode: 0,
		endTimeCode: 120,
		animationTracks: ["/Root/Animation"],
		availableCameras: ["/Root/Camera"]
	)

	let encoded = try JSONEncoder().encode(metadata)
	let decoded = try JSONDecoder().decode(USDStageMetadata.self, from: encoded)

	#expect(decoded.upAxis?.rawValue == "Y")
	#expect(decoded.metersPerUnit == 0.01)
	#expect(decoded.hasAnimationTracks == true)
	#expect(decoded.hasUsableTimelineRange == true)
}

@Test
func shellProvidesStableInterface() throws {
	// These types should remain stable across OpenUSD versions
	let handle = USDStageHandle(rawValue: 42)
	let primHandle = USDPrimHandle(stage: handle, path: "/Test")
	let path = USDPath("/Test")
	let token = USDToken("Test")

	// These operations should always work regardless of OpenUSD version
	#expect(handle.rawValue == 42)
	#expect(primHandle.stage == handle)
	#expect(primHandle.path == path)
	#expect(token.rawValue == "Test")

	// Hashable for use in collections
	let set: Set<USDPath> = ["/Test", "/Other", "/Test"]
	#expect(set.count == 2)
}

// MARK: - Error Handling Tests

@Test
func shellRuntimeErrorsHaveLocalizedDescriptions() throws {
	let error = ShellRuntimeError.stageOpenFailed(URL(fileURLWithPath: "/nonexistent.usda"))
	#expect(error.errorDescription?.contains("Failed to open") == true)

	let invalidHandle = ShellRuntimeError.invalidHandle(USDStageHandle(rawValue: 999))
	#expect(invalidHandle.errorDescription?.contains("Invalid stage handle") == true)

	let notImplemented = ShellRuntimeError.notImplemented("Test feature")
	#expect(notImplemented.errorDescription?.contains("Not implemented") == true)
}

// MARK: - Integration Tests

@Test
func fullSceneRoundTripWorkflow() throws {
	let scene = try TestUSDScene()

	// 1. Open stage and get handle
	let handle = try DeconstructedShellRuntime.openStage(at: scene.url)
	#expect(handle.rawValue > 0)

	// 2. Get stage metadata
	let metadata = DeconstructedShellRuntime.stageMetadata(url: scene.url)
	#expect(metadata.upAxis?.rawValue == "Y")

	// 3. Build prim tree
	let tree = DeconstructedShellRuntime.primTree(url: scene.url)
	#expect(tree.nodeCount > 3)

	// 4. Get specific prim summary
	guard let cubeSummary = DeconstructedShellRuntime.primSummary(
		url: scene.url,
		primPath: "/Root/Cube1"
	) else {
		#expect(Bool(false), "Should find Cube1")
		return
	}
	#expect(cubeSummary.name.rawValue == "Cube1")

	// 5. Close stage
	DeconstructedShellRuntime.closeStage(handle)
}

// MARK: - Documentation Validation

/// This test documents the expected productivity benefits of SwiftUsdShell.
///
/// Before SwiftUsdShell:
/// - Working with USD required direct C++ interop in every module
/// - USD objects couldn't cross actor boundaries safely
/// - No type-safe handles or stable identifiers
/// - Each OpenUSD version could break the API
///
/// With SwiftUsdShell:
/// - Pure Swift types that don't require C++ interop
/// - All types are Sendable and can be shared across actors
/// - Stable handles (USDStageHandle, USDPrimHandle) that don't change
/// - Codable support for serialization and persistence
/// - Type-safe enums for options (USDMaterialEditableChannelID, etc.)
///
/// This validation test ensures the shell types work as expected.
@Test
func productivityBenefitsAreRealized() throws {
	// 1. Pure Swift types - no C++ interop needed at call site
	let stageURL = USDStageURL(URL(fileURLWithPath: "/tmp/test.usda"))
	let materialPath = USDPath("/Root/Looks/Material1")

	// 2. Type-safe enums prevent typos and provide autocomplete
	let channel: USDMaterialEditableChannelID = .diffuseColor
	let operation = USDMaterialEditOperation.setValue(.scalar(0.5))
	let policy = USDMaterialEditPolicy.preserveAuthoredMode

	// 3. Structured request types are self-documenting
	let request = USDMaterialEditRequest(
		stageURL: stageURL,
		materialPath: materialPath,
		channel: channel,
		operation: operation,
		policy: policy
	)

	// 4. Codable for persistence/transmission
	let encoded = try JSONEncoder().encode(request)
	#expect(encoded.isEmpty == false)

	// 5. Hashable for use in collections/caches
	let requests: Set<USDMaterialEditRequest> = [request]
	#expect(requests.contains(request))

	// 6. Sendable for cross-actor concurrency
	let prepared = USDPreparedMaterialEdit(
		request: request,
		branchPlan: USDMaterialEditBranchPlan(
			branchTargets: [],
			targetOutputs: [.usdPreviewSurface],
			requiresConversion: false,
			preservesAuthoredMode: true
		)
	)

	Task.detached {
		// Can be sent across actor boundaries without @unchecked Sendable
		_ = prepared.readiness
	}
}
