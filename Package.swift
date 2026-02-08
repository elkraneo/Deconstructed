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
		.library(name: "DeconstructedUSDPipeline", targets: ["DeconstructedUSDPipeline"]),
		.library(name: "InspectorModels", targets: ["InspectorModels"]),
		.library(name: "InspectorFeature", targets: ["InspectorFeature"]),
		.library(name: "InspectorUI", targets: ["InspectorUI"]),
	],
	dependencies: [
		.package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.1"),
		.package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.3.0"),
		.package(url: "https://github.com/Reality2713/USDInterop", revision: "9a51edd955db053813d8467d088d07639d7aa46c"),
		.package(url: "https://github.com/Reality2713/USDInteropAdvanced-binaries", from: "0.2.15"),
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
				"DeconstructedUSDInterop",
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
				"RCPDocument",
				"ProjectBrowserFeature",
				"SceneGraphFeature",
				"InspectorFeature",
				"ViewportModels",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
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
				"DeconstructedUSDInterop",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/ProjectBrowserClients",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "ProjectBrowserFeature",
			dependencies: [
				"ProjectBrowserModels",
				"ProjectBrowserClients",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "Sharing", package: "swift-sharing"),
			],
			path: "Packages/DeconstructedLibrary/Sources/ProjectBrowserFeature",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "ProjectBrowserUI",
			dependencies: [
				"ProjectBrowserFeature",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/ProjectBrowserUI",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "ViewportModels",
			path: "Packages/DeconstructedLibrary/Sources/ViewportModels"
		),
		.target(
			name: "ViewportUI",
			dependencies: ["ViewportModels", .product(name: "USDInterfaces", package: "USDInterop")],
			path: "Packages/DeconstructedLibrary/Sources/ViewportUI",
			swiftSettings: [.interoperabilityMode(.Cxx)]
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
				"DeconstructedUSDInterop",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "USDInterfaces", package: "USDInterop"),
				.product(name: "USDInteropCxx", package: "USDInterop"),
				.product(name: "USDInteropAdvancedCore", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedUtils", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedInspection", package: "USDInteropAdvanced-binaries"),
			],
			path: "Packages/DeconstructedLibrary/Sources/SceneGraphClients",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "SceneGraphFeature",
			dependencies: [
				"DeconstructedUSDInterop",
				"SceneGraphClients",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/SceneGraphFeature",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "SceneGraphUI",
			dependencies: [
				"DeconstructedUSDInterop",
				"SceneGraphFeature",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			],
			path: "Packages/DeconstructedLibrary/Sources/SceneGraphUI",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "DeconstructedUSDInterop",
			dependencies: [
				.product(name: "USDInterop", package: "USDInterop"),
				.product(name: "USDInterfaces", package: "USDInterop"),
				.product(name: "USDInteropCxx", package: "USDInterop"),
				.product(name: "USDInteropAdvanced", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedCore", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedUtils", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedEditing", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedInspection", package: "USDInteropAdvanced-binaries"),
			],
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "DeconstructedUSDPipeline",
			dependencies: [
				.product(name: "USDInteropCxx", package: "USDInterop"),
				.product(name: "USDInteropAdvanced", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedAppleTools", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedCore", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedEditing", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedInspection", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedPlugins", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedSession", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedSurgery", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedUtils", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedWorkflows", package: "USDInteropAdvanced-binaries"),
			],
			path: "Packages/DeconstructedLibrary/Sources/DeconstructedUSDPipeline",
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
				"InspectorModels",
				"DeconstructedUSDInterop",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "USDInterfaces", package: "USDInterop"),
				.product(name: "USDInteropCxx", package: "USDInterop"),
				.product(name: "USDInteropAdvancedCore", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedUtils", package: "USDInteropAdvanced-binaries"),
				.product(name: "USDInteropAdvancedInspection", package: "USDInteropAdvanced-binaries"),
			],
			path: "Packages/DeconstructedLibrary/Sources/InspectorFeature",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
		.target(
			name: "InspectorUI",
			dependencies: [
				"InspectorFeature",
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				.product(name: "USDInterfaces", package: "USDInterop"),
			],
			path: "Packages/DeconstructedLibrary/Sources/InspectorUI",
			swiftSettings: [.interoperabilityMode(.Cxx)]
		),
	]
)
