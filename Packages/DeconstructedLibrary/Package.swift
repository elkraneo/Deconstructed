// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "DeconstructedLibrary",
	platforms: [
		.macOS(.v26)
	],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "DeconstructedModels",
			targets: ["DeconstructedModels"]
		),
		.library(
			name: "RCPPackage",
			targets: ["RCPPackage"]
		),
		.library(
			name: "RCPDocument",
			targets: ["RCPDocument"]
		),
		.library(
			name: "ProjectScaffolding",
			targets: ["ProjectScaffolding"]
		),
		.library(
			name: "DeconstructedClients",
			targets: ["DeconstructedClients"]
		),
		.library(
			name: "DeconstructedUI",
			targets: ["DeconstructedUI"]
		),
		.library(
			name: "DeconstructedFeatures",
			targets: ["DeconstructedFeatures"]
		),
		.library(
			name: "ProjectBrowserModels",
			targets: ["ProjectBrowserModels"]
		),
		.library(
			name: "ProjectBrowserClients",
			targets: ["ProjectBrowserClients"]
		),
		.library(
			name: "ProjectBrowserFeature",
			targets: ["ProjectBrowserFeature"]
		),
		.library(
			name: "ProjectBrowserUI",
			targets: ["ProjectBrowserUI"]
		),
		.library(
			name: "ViewportModels",
			targets: ["ViewportModels"]
		),
		.library(
			name: "ViewportUI",
			targets: ["ViewportUI"]
		),
		.library(
			name: "SceneGraphModels",
			targets: ["SceneGraphModels"]
		),
		.library(
			name: "SceneGraphClients",
			targets: ["SceneGraphClients"]
		),
		.library(
			name: "SceneGraphFeature",
			targets: ["SceneGraphFeature"]
		),
		.library(
			name: "SceneGraphUI",
			targets: ["SceneGraphUI"]
		),
		.library(
			name: "DeconstructedUSDInterop",
			targets: ["DeconstructedUSDInterop"]
		),
		.library(
			name: "DeconstructedShellRuntime",
			targets: ["DeconstructedShellRuntime"]
		),
		.library(
			name: "InspectorModels",
			targets: ["InspectorModels"]
		),
		.library(
			name: "InspectorFeature",
			targets: ["InspectorFeature"]
		),
		.library(
			name: "InspectorUI",
			targets: ["InspectorUI"]
		),
	],
	dependencies: [
		.package(
			url: "https://github.com/pointfreeco/swift-composable-architecture",
			from: "1.25.5"
		),
		.package(
			url: "https://github.com/pointfreeco/swift-sharing",
			from: "2.8.0"
		),
		// USDInterop is archived; replaced by SwiftUsdShellOpenUSD via the
		// SwiftUsdShell-binaries / SwiftUsd-binaries binary distribution.
		// See Docs/USDInterop-Sunset-Migration.md.
		.package(url: "https://github.com/reality2713/StageView.git", exact: "0.3.24"),
		.package(url: "https://github.com/Reality2713/SwiftUsd-binaries.git", exact: "0.3.124-macos-arm64.2"),
		.package(url: "https://github.com/Reality2713/SwiftUsdShell-binaries.git", exact: "0.3.124-macos-arm64.2"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "DeconstructedModels"
		),
		.target(
			name: "RCPPackage",
			dependencies: [
				"DeconstructedModels"
			]
		),
		.target(
			name: "RCPDocument",
			dependencies: [
				"RCPPackage",
				"DeconstructedModels",
			]
		),
		.target(
			name: "ProjectScaffolding",
			dependencies: [
				"DeconstructedModels"
			]
		),
		.target(
			name: "DeconstructedClients",
			dependencies: [
				"RCPPackage",
				"ProjectScaffolding",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
			]
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
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
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
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
				.product(name: "RealityKitStageView", package: "StageView"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.target(
			name: "ProjectBrowserModels",
			dependencies: [
				"DeconstructedModels"
			]
		),
		.target(
			name: "ProjectBrowserClients",
			dependencies: [
				"ProjectBrowserModels",
				"DeconstructedModels",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
			]
		),
		.target(
			name: "ProjectBrowserFeature",
			dependencies: [
				"ProjectBrowserModels",
				"ProjectBrowserClients",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
			]
		),
		.target(
			name: "ProjectBrowserUI",
			dependencies: [
				"ProjectBrowserClients",
				"ProjectBrowserFeature",
				"ProjectBrowserModels",
			]
		),
		.target(
			name: "ViewportModels"
		),
		.target(
			name: "ViewportUI",
			dependencies: [
				"ViewportModels",
				.product(name: "RealityKitStageView", package: "StageView"),
			]
		),
		.target(
			name: "SceneGraphModels"
		),
		.target(
			name: "SceneGraphClients",
			dependencies: [
				"SceneGraphModels",
				"DeconstructedModels",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
			],
			swiftSettings: [
			]
		),
		.target(
			name: "SceneGraphFeature",
			dependencies: [
				"SceneGraphClients",
				"SceneGraphModels",
				"DeconstructedModels",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.target(
			name: "SceneGraphUI",
			dependencies: [
				"SceneGraphFeature",
				"SceneGraphModels",
				"DeconstructedModels",
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.target(
			name: "DeconstructedUSDInterop",
			dependencies: [
				"DeconstructedModels",
				.product(name: "OpenUSD", package: "SwiftUsd-binaries"),
				.product(name: "SwiftUsdShell", package: "SwiftUsdShell-binaries"),
				.product(name: "SwiftUsdShellOpenUSD", package: "SwiftUsdShell-binaries"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx),
				.unsafeFlags(["-disable-cmo"], .when(configuration: .release)),
			]
		),
			.target(
				name: "DeconstructedShellRuntime",
				dependencies: [
					"InspectorFeature",
					"DeconstructedUSDInterop",
					"DeconstructedModels",
					"SceneGraphClients",
					.product(name: "SwiftUsdShell", package: "SwiftUsdShell-binaries"),
					.product(name: "SwiftUsdShellOpenUSD", package: "SwiftUsdShell-binaries"),
				],
				swiftSettings: [
					.interoperabilityMode(.Cxx)
				]
			),
		.target(
			name: "InspectorModels",
			dependencies: [
				.product(name: "Sharing", package: "swift-sharing"),
			]
		),
		.target(
			name: "InspectorFeature",
			dependencies: [
				"SceneGraphModels",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
				.product(name: "SwiftUsdShell", package: "SwiftUsdShell-binaries"),
			],
			path: "Sources/InspectorShellFeature"
		),
		.target(
			name: "InspectorUI",
			dependencies: [
				"InspectorFeature",
				"InspectorModels",
				.product(name: "Sharing", package: "swift-sharing"),
			],
			path: "Sources/InspectorShellUI"
		),
		.testTarget(
			name: "DeconstructedCoreTests",
			dependencies: [
				"RCPPackage",
				"InspectorFeature",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
			]
		),
		.testTarget(
			name: "ProjectBrowserFeatureTests",
			dependencies: ["ProjectBrowserFeature"],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.testTarget(
			name: "DeconstructedFeaturesTests",
			dependencies: [
				"DeconstructedFeatures",
				"ProjectBrowserFeature",
				"DeconstructedModels",
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.testTarget(
			name: "DeconstructedShellRuntimeTests",
			dependencies: [
				"DeconstructedShellRuntime",
				.product(name: "SwiftUsdShell", package: "SwiftUsdShell-binaries"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
	],
	cxxLanguageStandard: .gnucxx17
)
