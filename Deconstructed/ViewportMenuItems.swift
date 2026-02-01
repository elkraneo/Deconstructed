import DeconstructedFeatures
import DeconstructedUI
import DeconstructedUSDInterop
import SwiftUI

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

struct InsertMenuItems: View {
	@FocusedValue(\.viewportMenuContext) private var context

	var body: some View {
		Menu("Primitive Shape") {
			ForEach(USDPrimitiveType.allCases, id: \.self) { primitive in
				Button {
					context?.insertPrimitive(primitive)
				} label: {
					Label(primitive.displayName, systemImage: primitive.iconName)
				}
			}
		}
		.disabled(!(context?.canInsert ?? false))

		Divider()

		ForEach(USDStructuralType.allCases, id: \.self) { structural in
			Button {
				context?.insertStructural(structural)
			} label: {
				Label(structural.displayName, systemImage: structural.iconName)
			}
			.disabled(!(context?.canInsert ?? false))
		}
	}
}
