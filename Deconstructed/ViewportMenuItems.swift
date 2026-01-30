import SwiftUI
import DeconstructedUI
import DeconstructedFeatures

struct ViewportMenuItems: View {
	@FocusedValue(\.viewportMenuContext) private var context

	var body: some View {
		Button("Frame Selected") {
			context?.frameSelected()
		}
		.keyboardShortcut("f", modifiers: [.command])
		.disabled(!(context?.canFrameSelected ?? false))

		Button("Frame Scene") {
			context?.frameScene()
		}
		.keyboardShortcut("f", modifiers: [.command, .shift])
		.disabled(!(context?.canFrameScene ?? false))

		Divider()

		Toggle(
			"Grid",
			isOn: Binding(
				get: { context?.isGridVisible ?? false },
				set: { _ in context?.toggleGrid() }
			)
		)
		.disabled(context == nil)

		Divider()

		Menu("Camera History") {
			if let context, !context.cameraHistory.isEmpty {
				ForEach(context.cameraHistory) { item in
					Button(item.displayName) {
						context.selectCameraHistory(item.id)
					}
				}
			} else {
				Text("No History")
					.disabled(true)
			}
		}
		.disabled(context == nil)
	}
}
