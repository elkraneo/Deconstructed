import AppKit
import ComposableArchitecture
import DeconstructedModels
import SwiftUI
import UniformTypeIdentifiers
import RCPDocument

public struct LaunchExperience: View {
	@Bindable public var store: StoreOf<AppFeature>
	public var onNewProject: () -> Void
	public var onOpenProject: (URL) -> Void

	public init(
		store: StoreOf<AppFeature>,
		onNewProject: @escaping () -> Void,
		onOpenProject: @escaping (URL) -> Void
	) {
		self.store = store
		self.onNewProject = onNewProject
		self.onOpenProject = onOpenProject
	}

	public var body: some View {
		HStack(spacing: 0) {
			// Left panel - branding and actions
			VStack(spacing: 24) {
				Spacer()

				// App icon and title
				VStack(spacing: 16) {
					Image(nsImage: NSApp.applicationIconImage)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 128, height: 128)
						.shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)

					VStack(spacing: 4) {
						Text("Deconstructed")
							.font(.system(size: 32, weight: .bold))

						Text("Version 1.0")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}

				Spacer()

				// Action buttons
				VStack(spacing: 12) {
					LaunchButton(title: "Create New Project...", systemImage: DeconstructedConstants.SFSymbol.plusCircleFill) {
						store.send(.newProjectButtonTapped)
						onNewProject()
					}

					LaunchButton(title: "Open Existing Project...", systemImage: DeconstructedConstants.SFSymbol.folderFill) {
						openWithPanel()
					}
				}
				.padding(.horizontal, 40)

				Spacer()
			}
			.frame(width: 400)
			.background {
				ZStack {
					Color(nsColor: .windowBackgroundColor)

					Circle()
						.fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
						.frame(width: 400, height: 400)
						.blur(radius: 100)
						.opacity(0.15)
						.offset(x: -100, y: -100)
				}
			}

			Divider()

			// Right panel - recent documents
			RecentDocumentsList(store: store, onSelect: onOpenProject)
				.frame(minWidth: 280, maxWidth: 320)
		}
		.frame(minWidth: 700, minHeight: 450)
		.task {
			store.send(.onAppear)
		}
	}

	private func openWithPanel() {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.realityComposerPro]
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = true  // .realitycomposerpro is a package
		panel.canChooseFiles = true
		panel.treatsFilePackagesAsDirectories = false
		panel.message = "Choose a Reality Composer Pro project"
		panel.prompt = "Open"

		if panel.runModal() == .OK, let url = panel.url {
			onOpenProject(url)
		}
	}
}

struct LaunchButton: View {
	let title: String
	let systemImage: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack {
				Image(systemName: systemImage)
					.font(.title3)
					.foregroundStyle(.blue)
					.frame(width: 24)

				Text(title)
					.font(.body)

				Spacer()
			}
			.padding(.vertical, 10)
			.padding(.horizontal, 16)
			.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
		}
		.buttonStyle(.plain)
	}
}

struct RecentDocumentsList: View {
	@Bindable var store: StoreOf<AppFeature>
	var onSelect: (URL) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text("Recent Projects")
				.font(.headline)
				.padding()

			Divider()

			if store.recentProjects.isEmpty {
				ContentUnavailableView(
					"No Recent Projects",
					systemImage: DeconstructedConstants.SFSymbol.clock,
					description: Text("Projects you open will appear here.")
				)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				List(store.recentProjects, id: \.self) { url in
					RecentDocumentRow(url: url, onSelect: onSelect)
				}
				.listStyle(.plain)
			}
		}
		.background(Color(nsColor: .controlBackgroundColor))
	}
}

struct RecentDocumentRow: View {
	let url: URL
	var onSelect: (URL) -> Void

	var body: some View {
		Button {
			onSelect(url)
		} label: {
			HStack(spacing: 12) {
				Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 32, height: 32)

				VStack(alignment: .leading, spacing: 2) {
					Text(url.deletingPathExtension().lastPathComponent)
						.font(.body)
						.lineLimit(1)

					Text(url.deletingLastPathComponent().path)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}

				Spacer()
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}
}
