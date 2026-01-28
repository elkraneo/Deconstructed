import Foundation

/// Represents a file or directory in the .rkassets bundle
public struct AssetItem: Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let fileType: AssetFileType
    public var children: [AssetItem]?

    /// For USDA files, the UUID from main.json
    public var sceneUUID: String?

    /// File modification date for sorting
    public let modificationDate: Date

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        isDirectory: Bool,
        fileType: AssetFileType,
        children: [AssetItem]? = nil,
        sceneUUID: String? = nil,
        modificationDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.fileType = fileType
        self.children = children
        self.sceneUUID = sceneUUID
        self.modificationDate = modificationDate
    }

    // MARK: - Equatable

    public static func == (lhs: AssetItem, rhs: AssetItem) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
