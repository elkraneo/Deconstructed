import Foundation

public struct ReverbPresetOption: Sendable, Hashable {
	public let token: String
	public let displayName: String

	public init(token: String, displayName: String) {
		self.token = token
		self.displayName = displayName
	}
}

public enum ReverbPreset {
	public static let defaultToken = "MediumRoomTreated"
	public static let defaultDisplayName = "Medium Room Treated"

	public static let options: [ReverbPresetOption] = [
		ReverbPresetOption(token: "Anechoic", displayName: "Anechoic"),
		ReverbPresetOption(token: "VerySmallRoomBright", displayName: "Very Small Room Bright"),
		ReverbPresetOption(token: "SmallRoom", displayName: "Small Room"),
		ReverbPresetOption(token: "SmallRoomBright", displayName: "Small Room Bright"),
		ReverbPresetOption(token: "MediumRoomDry", displayName: "Medium Room Dry"),
		ReverbPresetOption(token: "MediumRoomTreated", displayName: "Medium Room Treated"),
		ReverbPresetOption(token: "LargeRoom", displayName: "Large Room"),
		ReverbPresetOption(token: "LargeRoomTreated", displayName: "Large Room Treated"),
		ReverbPresetOption(token: "VeryLargeRoom", displayName: "Very Large Room"),
		ReverbPresetOption(token: "ConcertHall", displayName: "Concert Hall"),
		ReverbPresetOption(token: "Outside", displayName: "Outside"),
	]

	public static func token(for displayName: String) -> String {
		options.first(where: { $0.displayName == displayName })?.token ?? defaultToken
	}

	public static func displayName(for token: String) -> String {
		options.first(where: { $0.token == token })?.displayName ?? defaultDisplayName
	}
}
