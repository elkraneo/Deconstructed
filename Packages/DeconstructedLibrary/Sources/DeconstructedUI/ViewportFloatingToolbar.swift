import SwiftUI
import ViewportModels
import ViewportUI

/// Floating toolbar at the bottom of the viewport, matching RCP's style.
public struct ViewportFloatingToolbar: View {
	let context: ViewportMenuContext?
	@State private var showEnvironmentPanel = false

	public init(context: ViewportMenuContext? = nil) {
		self.context = context
	}

	public var body: some View {
		HStack(spacing: 2) {
			// Selection tool (placeholder)
			toolbarButton(icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", help: "Select")

			// Focus tool (placeholder)
			toolbarButton(icon: "scope", help: "Focus")

			// Move tool (placeholder)
			toolbarButton(icon: "arrow.up.and.down.and.arrow.left.and.right", help: "Move")

			// Rotate tool (placeholder)
			toolbarButton(icon: "arrow.triangle.2.circlepath", help: "Rotate")

			// Scale tool (placeholder)
			toolbarButton(icon: "arrow.up.left.and.arrow.down.right", help: "Scale")

			Divider()
				.frame(height: 20)
				.padding(.horizontal, 4)

			// Environment/Lighting
			Button {
				showEnvironmentPanel.toggle()
			} label: {
				Image(systemName: "sun.horizon")
					.frame(width: 24, height: 24)
					.contentShape(Rectangle())
			}
			.buttonStyle(.borderless)
			.help("Environment")
			.popover(isPresented: $showEnvironmentPanel, arrowEdge: .top) {
				if let context {
					EnvironmentPanel(
						configuration: environmentBinding(for: context),
						showGrid: gridBinding(for: context)
					)
				} else {
					Text("No viewport context")
						.padding()
				}
			}

			// Camera menu (placeholder)
			toolbarButton(icon: "video", help: "Camera")
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 6)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(Color.primary.opacity(0.1), lineWidth: 1)
		)
		.contentShape(RoundedRectangle(cornerRadius: 8))
		.allowsHitTesting(true)
	}

	private func toolbarButton(icon: String, help: String) -> some View {
		Button {
			// Placeholder action
		} label: {
			Image(systemName: icon)
				.frame(width: 24, height: 24)
		}
		.buttonStyle(.plain)
		.help(help)
		.disabled(true)
		.opacity(0.5)
	}

	private func environmentBinding(for context: ViewportMenuContext) -> Binding<EnvironmentConfiguration> {
		Binding(
			get: { context.environmentConfiguration },
			set: { newConfig in
				if newConfig.environmentPath != context.environmentConfiguration.environmentPath {
					context.setEnvironmentPath(newConfig.environmentPath)
				}
				if newConfig.showBackground != context.environmentConfiguration.showBackground {
					context.setEnvironmentShowBackground(newConfig.showBackground)
				}
				if newConfig.rotation != context.environmentConfiguration.rotation {
					context.setEnvironmentRotation(newConfig.rotation)
				}
				if newConfig.exposure != context.environmentConfiguration.exposure {
					context.setEnvironmentExposure(newConfig.exposure)
				}
			}
		)
	}

	private func gridBinding(for context: ViewportMenuContext) -> Binding<Bool> {
		Binding(
			get: { context.isGridVisible },
			set: { _ in context.toggleGrid() }
		)
	}
}
