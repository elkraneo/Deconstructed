import Foundation

/// Helper for generating Swift package content
public enum PackageTemplate {
	public static func content(projectName: String) -> String {
		return """
	 // swift-tools-version:6.2
	 // The swift-tools-version declares the minimum version of Swift required to build this package.
	
	import PackageDescription
	
	let package = Package(
		 name: "\(projectName)",
		 platforms: [
			 .macOS(.v26)
		 ],
		 products: [
			 // Products define the executables and libraries a package produces, and make them visible to other packages.
			 .library(
				 name: "\(projectName)",
				 targets: ["\(projectName)"]),
		 ],
		 dependencies: [
			 // Dependencies declare other packages that this package depends on.
			 // .package(url: /* package url */, from: "1.0.0"),
		 ],
		 targets: [
			 // Targets are the basic building blocks of a package. A target can define a module or a test suite.
			 // Targets can depend on other targets in this package, and on products in packages this package depends on.
			 .target(
				 name: "\(projectName)",
				 dependencies: []),
		 ]
	 )
	"""
	}
}

/// Helper for generating the bundle accessor Swift file
public enum BundleAccessorTemplate {
	public static func content(projectName: String) -> String {
		return """
	import Foundation

	/// Bundle for the \(projectName) project
	public let \(projectName.lowercased())Bundle = Bundle.module
	"""
	}
}

/// Helper for generating an empty USD scene
public enum SceneTemplate {
	public static func emptyScene(creator: String = "Deconstructed Version 1.0") -> String {
		return """
	#usda 1.0
	(
		customLayerData = {
			string creator = "\(creator)"
		}
		defaultPrim = "Root"
		metersPerUnit = 1
		upAxis = "Y"
	)

	def Xform "Root"
	{
	}
	"""
	}
}
