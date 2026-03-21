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
			from: "1.23.1"
		),
		.package(
			url: "https://github.com/pointfreeco/swift-sharing",
			from: "2.3.0"
		),
		// Keep USDInterop pinned to avoid SwiftPM conflicts between transitive requirements.
		//
		// .package(url: "https://github.com/Reality2713/USDInterop", revision: "9a51edd955db053813d8467d088d07639d7aa46c"),
		// .package(
		// 	url: "https://github.com/Reality2713/USDInterop",
		// 	revision: "9a51edd955db053813d8467d088d07639d7aa46c"
		// ),
		.package(
			url: "https://github.com/Reality2713/USDInterop",
			from: "0.1.13"
		),
		.package(url: "https://github.com/reality2713/StageView.git", from: "0.1.4"),
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
				"DeconstructedUSDInterop",
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
				"RCPDocument",
				"ProjectBrowserFeature",
				"SceneGraphFeature",
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
				"DeconstructedUSDInterop",
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
			name: "ProjectBrowserFeature",
			dependencies: [
				"ProjectBrowserModels",
				"ProjectBrowserClients",
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
			name: "ProjectBrowserUI",
			dependencies: [
				"ProjectBrowserClients",
				"ProjectBrowserFeature",
				"ProjectBrowserModels",
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
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
				.product(name: "USDInterfaces", package: "USDInterop"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
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
				"DeconstructedUSDInterop",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
				.product(name: "USDInterfaces", package: "USDInterop"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.target(
			name: "SceneGraphFeature",
			dependencies: [
				"SceneGraphClients",
				"SceneGraphModels",
				"DeconstructedUSDInterop",
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
				"DeconstructedUSDInterop",
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.target(
			name: "DeconstructedUSDInterop",
			dependencies: [
				.product(name: "USDInterfaces", package: "USDInterop"),
				.product(name: "USDOperations", package: "USDInterop"),
				.product(name: "USDInterop", package: "USDInterop"),
				.product(name: "USDInteropCxx", package: "USDInterop"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx),
				.unsafeFlags(["-disable-cmo"], .when(configuration: .release)),
			]
		),
		.target(
			name: "InspectorModels",
			dependencies: [
				.product(name: "Sharing", package: "swift-sharing"),
				.product(name: "USDInterfaces", package: "USDInterop"),
			]
		),
		.target(
			name: "InspectorFeature",
			dependencies: [
				"InspectorModels",
				"SceneGraphModels",
				"DeconstructedUSDInterop",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				),
				.product(name: "USDInterfaces", package: "USDInterop"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
		),
		.target(
			name: "InspectorUI",
			dependencies: [
				"InspectorFeature",
				"InspectorModels",
				"SceneGraphModels",
				.product(name: "Sharing", package: "swift-sharing"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
			]
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
				.product(name: "USDInterfaces", package: "USDInterop"),
			],
			swiftSettings: [
				.interoperabilityMode(.Cxx)
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
	],
	cxxLanguageStandard: .gnucxx17
)
