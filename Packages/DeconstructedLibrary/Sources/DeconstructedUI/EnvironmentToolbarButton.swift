import SwiftUI
import ViewportModels
import ViewportUI

/// Toolbar button that shows the environment panel as a popover.
public struct EnvironmentToolbarButton: View {
	@FocusedValue(\.viewportMenuContext) private var context
	@State private var showPanel = false

	public init() {}

	public var body: some View {
		Button {
			showPanel.toggle()
		} label: {
			Image(systemName: "sun.horizon")
		}
		.help("Environment")
		.popover(isPresented: $showPanel, arrowEdge: .bottom) {
			if let context {
				EnvironmentPanel(
					configuration: environmentBinding(for: context),
					showGrid: gridBinding(for: context)
				)
			}
		}
		.disabled(context == nil)
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
