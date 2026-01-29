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
		)
	],
	dependencies: [
		.package(
			url: "https://github.com/pointfreeco/swift-composable-architecture",
			from: "1.23.1"
		)
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
				"DeconstructedModels"
			]
		),
		.target(
			name: "ProjectScaffolding"
		),
		.target(
			name: "DeconstructedClients",
			dependencies: [
				"RCPPackage",
				"ProjectScaffolding",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				)
			]
		),
		.target(
			name: "DeconstructedUI",
			dependencies: [
				"RCPDocument",
				"ProjectBrowserUI",
				"ProjectBrowserFeature",
				"DeconstructedFeatures",
				"ViewportUI",
				"ViewportModels",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				)
			]
		),
		.target(
			name: "DeconstructedFeatures",
			dependencies: [
				"DeconstructedClients",
				"RCPDocument",
				"ProjectBrowserFeature",
				"ViewportModels",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				)
			]
		),
		.target(
			name: "ProjectBrowserModels"
		),
		.target(
			name: "ProjectBrowserClients",
			dependencies: [
				"ProjectBrowserModels",
				"DeconstructedModels",
				.product(
					name: "ComposableArchitecture",
					package: "swift-composable-architecture"
				)
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
				)
			]
		),
		.target(
			name: "ProjectBrowserUI",
			dependencies: [
				"ProjectBrowserFeature",
				"ProjectBrowserModels"
			]
		),
		.target(
			name: "ViewportModels"
		),
		.target(
			name: "ViewportUI",
			dependencies: [
				"ViewportModels"
			]
		),
		.testTarget(
			name: "DeconstructedCoreTests",
			dependencies: ["RCPPackage"]
		),
		.testTarget(
			name: "ProjectBrowserFeatureTests",
			dependencies: ["ProjectBrowserFeature"]
		),
	]
)
