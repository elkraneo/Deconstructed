import DeconstructedFeatures
import DeconstructedUI
import DeconstructedUSDInterop
import SwiftUI
import ViewportModels
import ViewportUI

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

		Divider()

		Menu("Environment") {
			EnvironmentMenuItems()
		}
		.disabled(context == nil)
	}
}

struct EnvironmentMenuItems: View {
	@FocusedValue(\.viewportMenuContext) private var context

	var body: some View {
		if let context {
			let envNames = [
				"Arquicklook Ibl",
				"Beach Sunset",
				"Downtown Night",
				"Neighborhood Overcast",
				"Rooftop Sunny",
				"Warehouse Diffuse",
				"Arql Legacy",
			]

			Button("None (Default Lighting)") {
				context.setEnvironmentPath(nil)
			}

			Divider()

			ForEach(envNames, id: \.self) { name in
				Button(name) {
					// Find matching environment path
					let environments = ViewportUI.EnvironmentMaps.availableEnvironments()
					if let path = environments.first(where: {
						ViewportUI.EnvironmentMaps.displayName(for: $0) == name
					}) {
						context.setEnvironmentPath(path)
					}
				}
			}

			Divider()

			Toggle("Show Background", isOn: Binding(
				get: { context.environmentConfiguration.showBackground },
				set: { context.setEnvironmentShowBackground($0) }
			))
		}
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
