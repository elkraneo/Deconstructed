import Foundation

public enum ViewMode: String, Sendable, Equatable {
	case icons
	case list
}

public enum BrowserSortOrder: String, Sendable, Equatable {
	case name
	case dateModified
	case type
}
