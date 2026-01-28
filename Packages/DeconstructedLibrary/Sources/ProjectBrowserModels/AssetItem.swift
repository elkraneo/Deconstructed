import Foundation
import CryptoKit

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

	public static func stableID(for url: URL) -> UUID {
		let path = url.standardizedFileURL.path
		let digest = Insecure.MD5.hash(data: Data(path.utf8))
		let bytes = Array(digest)
		return UUID(uuid: (
			bytes[0], bytes[1], bytes[2], bytes[3],
			bytes[4], bytes[5], bytes[6], bytes[7],
			bytes[8], bytes[9], bytes[10], bytes[11],
			bytes[12], bytes[13], bytes[14], bytes[15]
		))
	}

    // MARK: - Equatable

    public static func == (lhs: AssetItem, rhs: AssetItem) -> Bool {
        lhs.id == rhs.id
		&& lhs.name == rhs.name
		&& lhs.children == rhs.children
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
