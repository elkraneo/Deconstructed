// swift-tools-version: 6.2

import PackageDescription

// Root manifest for CI-safe dependency resolution.
//
// Xcode project must depend on this package via a *remote* URL reference.
// Local development can be done with SwiftPM mirrors (see docs in `AGENTS.md`).
//
// Sources live under `Packages/DeconstructedLibrary/Sources` to keep the Xcode project layout intact.

let package = Package(
	name: "DeconstructedLibrary",
	platforms: [
		.macOS(.v26),
	],
	products: [
		.library(name: "DeconstructedModels", targets: ["DeconstructedModels"]),
		.library(name: "RCPPackage", targets: ["RCPPackage"]),
		.library(name: "RCPDocument", targets: ["RCPDocument"]),
		.library(name: "ProjectScaffolding", targets: ["ProjectScaffolding"]),
		.library(name: "DeconstructedClients", targets: ["DeconstructedClients"]),
		.library(name: "DeconstructedUI", targets: ["DeconstructedUI"]),
		.library(name: "DeconstructedFeatures", targets: ["DeconstructedFeatures"]),
		.library(name: "ProjectBrowserModels", targets: ["ProjectBrowserModels"]),
		.library(name: "ProjectBrowserClients", targets: ["ProjectBrowserClients"]),
		.library(name: "ProjectBrowserFeature", targets: ["ProjectBrowserFeature"]),
		.library(name: "ProjectBrowserUI", targets: ["ProjectBrowserUI"]),
		.library(name: "ViewportModels", targets: ["ViewportModels"]),
		.library(name: "ViewportUI", targets: ["ViewportUI"]),
		.library(name: "SceneGraphModels", targets: ["SceneGraphModels"]),
		.library(name: "SceneGraphClients", targets: ["SceneGraphClients"]),
		.library(name: "SceneGraphFeature", targets: ["SceneGraphFeature"]),
		.library(name: "SceneGraphUI", targets: ["SceneGraphUI"]),
		.library(name: "DeconstructedUSDInterop", targets: ["DeconstructedUSDInterop"]),
		.library(name: "DeconstructedShellRuntime", targets: ["DeconstructedShellRuntime"]),
		.library(name: "InspectorModels", targets: ["InspectorModels"]),
		.library(name: "InspectorFeature", targets: ["InspectorFeature"]),
		.library(name: "InspectorUI", targets: ["InspectorUI"]),
	],
	dependencies: [
		.package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.25.5"),
		.package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.8.0"),
		.package(url: "https://github.com/reality2713/StageView.git", exact: "0.3.24"),
		.package(url: "https://github.com/Reality2713/SwiftUsdShell-binaries.git", exact: "0.3.126-macos-arm64.3"),
	],
	targets: [
		.target(
			name: "DeconstructedModels",
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedModels"
		),
		.target(
			name: "RCPPackage",
			dependencies: ["DeconstructedModels"],
			path: "Packages/DeconstructedLibrary/Sources/RCPPackage"
		),
		.target(
			name: "RCPDocument",
			dependencies: ["RCPPackage", "DeconstructedModels"],
			path: "Packages/DeconstructedLibrary/Sources/RCPDocument"
		),
		.target(
			name: "ProjectScaffolding",
			dependencies: ["DeconstructedModels"],
			path: "Packages/DeconstructedLibrary/Sources/ProjectScaffolding"
		),
		.target(
			name: "DeconstructedClients",
			dependencies: [
				"RCPPackage",
				"ProjectScaffolding",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedClients"
		),
		.target(
			name: "DeconstructedUI",
			dependencies: [
				"RCPDocument",
				"ProjectBrowserUI",
				"ProjectBrowserFeature",
				"SceneGraphUI",
				"DeconstructedFeatures",
				"DeconstructedModels",
				"ViewportUI",
				"ViewportModels",
				"InspectorUI",
				"InspectorFeature",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedUI",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "DeconstructedFeatures",
			dependencies: [
				"DeconstructedClients",
				"DeconstructedShellRuntime",
				"RCPDocument",
				"ProjectBrowserFeature",
				"SceneGraphFeature",
				"SceneGraphClients",
				"InspectorFeature",
				"ViewportModels",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "RealityKitStageView", package: "StageView"),
			],
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedFeatures",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "ProjectBrowserModels",
			dependencies: ["DeconstructedModels"],
			path: "Packages/DeconstructedLibrary/Sources/ProjectBrowserModels"
		),
		.target(
			name: "ProjectBrowserClients",
			dependencies: [
				"ProjectBrowserModels",
				"DeconstructedModels",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/ProjectBrowserClients"
		),
		.target(
			name: "ProjectBrowserFeature",
			dependencies: [
				"ProjectBrowserModels",
				"ProjectBrowserClients",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "Sharing", package: "swift-sharing"),
			],
			path: "Packages/DeconstructedLibrary/Sources/ProjectBrowserFeature"
		),
		.target(
			name: "ProjectBrowserUI",
			dependencies: [
				"ProjectBrowserFeature",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/ProjectBrowserUI"
		),
		.target(
			name: "ViewportModels",
			path: "Packages/DeconstructedLibrary/Sources/ViewportModels"
		),
		.target(
			name: "ViewportUI",
			dependencies: ["ViewportModels", .product(name: "RealityKitStageView", package: "StageView")],
			path: "Packages/DeconstructedLibrary/Sources/ViewportUI"
		),
		.target(
			name: "SceneGraphModels",
			path: "Packages/DeconstructedLibrary/Sources/SceneGraphModels"
		),
		.target(
			name: "SceneGraphClients",
			dependencies: [
				"SceneGraphModels",
				"DeconstructedModels",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/SceneGraphClients",
			swiftSettings: []
		),
		.target(
			name: "SceneGraphFeature",
			dependencies: [
				"DeconstructedModels",
				"SceneGraphClients",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/SceneGraphFeature",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "SceneGraphUI",
			dependencies: [
				"DeconstructedModels",
				"SceneGraphFeature",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/SceneGraphUI",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "DeconstructedUSDInterop",
			dependencies: [
				"DeconstructedModels",
				.product(name: "SwiftUsdShellOpenUSD", package: "SwiftUsdShell-binaries"),
			],
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "DeconstructedShellRuntime",
			dependencies: [
				"InspectorFeature",
				"DeconstructedUSDInterop",
				"DeconstructedModels",
				"SceneGraphClients",
				.product(name: "SwiftUsdShellOpenUSD", package: "SwiftUsdShell-binaries"),
			],
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedShellRuntime",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "InspectorModels",
			dependencies: [
				.product(name: "Sharing", package: "swift-sharing"),
			],
			path: "Packages/DeconstructedLibrary/Sources/InspectorModels"
		),
		.target(
			name: "InspectorFeature",
			dependencies: [
				"SceneGraphModels",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "SwiftUsdShell", package: "SwiftUsdShell-binaries"),
			],
			path: "Packages/DeconstructedLibrary/Sources/InspectorShellFeature"
		),
		.target(
			name: "InspectorUI",
			dependencies: [
				"InspectorFeature",
				"InspectorModels",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "Sharing", package: "swift-sharing"),
			],
			path: "Packages/DeconstructedLibrary/Sources/InspectorShellUI"
		),
	]
)
