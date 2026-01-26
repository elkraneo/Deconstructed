import Foundation

/// Represents the `ProjectData/main.json` file
/// Marked nonisolated to allow Codable usage from any isolation context
nonisolated struct RCPProjectData: Codable, Sendable {
    var pathsToIds: [String: String]
    var projectID: Int64
    var uuidToIntID: [String: Int64]

    static func initial() -> RCPProjectData {
        return RCPProjectData(
            pathsToIds: [:],
            projectID: Int64.random(in: Int64.min...Int64.max),
            uuidToIntID: [:]
        )
    }
}

/// Represents the `WorkspaceData/Settings.rcprojectdata` file
nonisolated struct RCPSettings: Codable, Sendable {
    struct ToolbarData: Codable, Sendable {
        var isGridVisible: Bool
    }

    var secondaryToolbarData: ToolbarData

    static func initial() -> RCPSettings {
        return RCPSettings(secondaryToolbarData: ToolbarData(isGridVisible: true))
    }
}

/// Helper for generating Swift package content
nonisolated struct PackageTemplate: Sendable {
    static func content(projectName: String) -> String {
        return """
        // swift-tools-version:6.2
        import PackageDescription

        let package = Package(
            name: "\(projectName)",
            platforms: [.macOS(.v26)],
            products: [.library(name: "\(projectName)", targets: ["\(projectName)"])],
            targets: [.target(name: "\(projectName)", dependencies: [])]
        )
        """
    }
}
