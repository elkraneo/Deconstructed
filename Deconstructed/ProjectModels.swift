import Foundation

/// Represents the `ProjectData/main.json` file
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

    static func initial(scenePath: String, sceneUUID: String) -> RCPProjectData {
        return RCPProjectData(
            pathsToIds: [scenePath: sceneUUID],
            projectID: Int64.random(in: Int64.min...Int64.max),
            uuidToIntID: [sceneUUID: Int64.random(in: Int64.min...Int64.max)]
        )
    }
}

/// Represents the `WorkspaceData/Settings.rcprojectdata` file
nonisolated struct RCPSettings: Codable, Sendable {
    var cameraPresets: [String: CameraPreset]?
    var secondaryToolbarData: ToolbarData
    var unitDefaults: [String: String]?

    struct CameraPreset: Codable, Sendable {}

    struct ToolbarData: Codable, Sendable {
        var isGridVisible: Bool
    }

    static func initial() -> RCPSettings {
        return RCPSettings(
            cameraPresets: [:],
            secondaryToolbarData: ToolbarData(isGridVisible: true),
            unitDefaults: [
                "kg": "g",
                "kg⋅m²": "kg⋅m²",
                "m": "cm",
                "m/s": "m/s",
                "m/s²": "m/s²",
                "s": "s",
                "°": "°"
            ]
        )
    }
}

/// Represents `WorkspaceData/SceneMetadataList.json`
/// Structure: { "uuid": { "objectMetadataList": [[uuid, name], {isExpanded, isLocked}] } }
nonisolated struct RCPSceneMetadataList: Sendable {
    var scenes: [String: SceneMetadata]

    struct SceneMetadata: Sendable {
        var uuid: String
        var name: String
        var isExpanded: Bool
        var isLocked: Bool
    }

    static func initial(sceneUUID: String, sceneName: String = "Root") -> RCPSceneMetadataList {
        return RCPSceneMetadataList(scenes: [
            sceneUUID: SceneMetadata(
                uuid: sceneUUID,
                name: sceneName,
                isExpanded: true,
                isLocked: false
            )
        ])
    }

    /// Custom JSON encoding to match RCP's format
    func encode() throws -> Data {
        var root: [String: Any] = [:]

        for (key, metadata) in scenes {
            let objectMetadataList: [Any] = [
                [metadata.uuid, metadata.name],
                ["isExpanded": metadata.isExpanded, "isLocked": metadata.isLocked]
            ]
            root[key] = ["objectMetadataList": objectMetadataList]
        }

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
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

/// Helper for generating the bundle accessor Swift file
nonisolated struct BundleAccessorTemplate: Sendable {
    static func content(projectName: String) -> String {
        return """
        import Foundation

        /// Bundle for the \(projectName) project
        public let \(projectName.lowercased())Bundle = Bundle.module
        """
    }
}

/// Helper for generating an empty USD scene
nonisolated struct SceneTemplate: Sendable {
    static func emptyScene(creator: String = "Deconstructed Version 1.0") -> String {
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
