import AppKit
import ComposableArchitecture
import Foundation

public struct RecentDocumentsClient: Sendable {
	public var fetch: @Sendable () -> [URL]

	public init(fetch: @escaping @Sendable () -> [URL]) {
		self.fetch = fetch
	}
}

private enum RecentDocumentsClientKey: DependencyKey {
	static let liveValue = RecentDocumentsClient(fetch: {
		NSDocumentController.shared.recentDocumentURLs
	})
}

public struct NewProjectClient: Sendable {
	public var create: @Sendable () async -> Void

	public init(create: @escaping @Sendable () async -> Void) {
		self.create = create
	}
}

private enum NewProjectClientKey: DependencyKey {
	static let liveValue = NewProjectClient(create: {
		await NewProjectCreator.shared.createNewProject()
	})
}

public extension DependencyValues {
	var recentDocuments: RecentDocumentsClient {
		get { self[RecentDocumentsClientKey.self] }
		set { self[RecentDocumentsClientKey.self] = newValue }
	}

	var newProjectClient: NewProjectClient {
		get { self[NewProjectClientKey.self] }
		set { self[NewProjectClientKey.self] = newValue }
	}
}
