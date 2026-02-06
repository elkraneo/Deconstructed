import AppKit
import ComposableArchitecture
import Foundation

@DependencyClient
public struct ProjectBrowserDialogClient: Sendable {
	public var selectImportContentURLs: @Sendable () async -> [URL]
	public var selectMoveDestination: @Sendable (_ rootURL: URL) async -> URL?
}

extension ProjectBrowserDialogClient: DependencyKey {
	public static var liveValue: Self {
		Self(
			selectImportContentURLs: {
				await MainActor.run {
					let panel = NSOpenPanel()
					panel.canChooseFiles = true
					panel.canChooseDirectories = true
					panel.allowsMultipleSelection = true
					panel.title = "Import Content"
					panel.prompt = "Import"
					return panel.runModal() == .OK ? panel.urls : []
				}
			},
			selectMoveDestination: { rootURL in
				await MainActor.run {
					let panel = NSOpenPanel()
					panel.canChooseFiles = false
					panel.canChooseDirectories = true
					panel.allowsMultipleSelection = false
					panel.directoryURL = rootURL
					panel.title = "Move To Folder"
					panel.prompt = "Move"
					return panel.runModal() == .OK ? panel.url : nil
				}
			}
		)
	}
}
