import SwiftUI
import UniformTypeIdentifiers

struct LaunchExperience: View {
	var onNewProject: () -> Void
	var onOpenProject: (URL) -> Void

	var body: some View {
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
							.font(.system(size: 32, weight: .bold, design: .rounded))

						Text("Version 1.0")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}

				Spacer()

				// Action buttons
				VStack(spacing: 12) {
					LaunchButton(title: "Create New Project...", systemImage: "plus.circle.fill") {
						onNewProject()
					}

					LaunchButton(title: "Open Existing Project...", systemImage: "folder.fill") {
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
						.fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
						.frame(width: 400, height: 400)
						.blur(radius: 100)
						.opacity(0.15)
						.offset(x: -100, y: -100)
				}
			}

			Divider()

			// Right panel - recent documents
			RecentDocumentsList(onSelect: onOpenProject)
				.frame(minWidth: 280, maxWidth: 320)
		}
		.frame(minWidth: 700, minHeight: 450)
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
					.foregroundStyle(.orange)
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
	var onSelect: (URL) -> Void
	@State private var recentURLs: [URL] = []

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text("Recent Projects")
				.font(.headline)
				.padding()

			Divider()

			if recentURLs.isEmpty {
				ContentUnavailableView("No Recent Projects", systemImage: "clock", description: Text("Projects you open will appear here."))
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				List(recentURLs, id: \.self) { url in
					RecentDocumentRow(url: url, onSelect: onSelect)
				}
				.listStyle(.plain)
			}
		}
		.background(Color(nsColor: .controlBackgroundColor))
		.onAppear {
			loadRecentDocuments()
		}
	}

	private func loadRecentDocuments() {
		recentURLs = NSDocumentController.shared.recentDocumentURLs
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
