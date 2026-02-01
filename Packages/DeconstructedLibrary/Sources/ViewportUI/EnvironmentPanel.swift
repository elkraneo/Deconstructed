import AppKit
import SwiftUI
import ViewportModels

/// RCP-style environment panel for viewport lighting configuration.
public struct EnvironmentPanel: View {
	@Binding var configuration: EnvironmentConfiguration
	@Binding var showGrid: Bool
	@State private var availableEnvironments: [String] = []

	public init(
		configuration: Binding<EnvironmentConfiguration>,
		showGrid: Binding<Bool>
	) {
		self._configuration = configuration
		self._showGrid = showGrid
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			environmentGrid

			Divider()

			Toggle("Show Grid", isOn: $showGrid)

			HStack {
				Text("Background")
					.foregroundColor(.secondary)
				Spacer()
				ColorPicker(
					"",
					selection: backgroundColorBinding,
					supportsOpacity: false
				)
				.labelsHidden()
			}

			sliderRow(label: "Rotate", value: $configuration.rotation, range: 0...360, format: "%.0f")
			sliderRow(label: "Exposure", value: $configuration.exposure, range: -3...3, format: "%.1f")
		}
		.padding()
		.frame(width: 280)
		.task {
			availableEnvironments = EnvironmentMaps.availableEnvironments()
		}
	}

	private var environmentGrid: some View {
		let columns = [
			GridItem(.fixed(80)),
			GridItem(.fixed(80)),
			GridItem(.fixed(80)),
		]
		return LazyVGrid(columns: columns, spacing: 8) {
			ForEach(availableEnvironments, id: \.self) { env in
				environmentThumbnail(for: env)
			}
		}
	}

	private func environmentThumbnail(for path: String) -> some View {
		let isSelected = configuration.environmentPath == path
		let name = EnvironmentMaps.displayName(for: path)

		return Button {
			if configuration.environmentPath == path {
				configuration.environmentPath = nil
			} else {
				configuration.environmentPath = path
			}
		} label: {
			VStack(spacing: 4) {
				ZStack {
					thumbnailGradient(for: path)
						.frame(width: 70, height: 50)
						.clipShape(RoundedRectangle(cornerRadius: 6))

					Image(systemName: iconName(for: path))
						.font(.system(size: 16))
						.foregroundColor(.white.opacity(0.9))
						.shadow(radius: 2)
				}
				.overlay(
					RoundedRectangle(cornerRadius: 6)
						.stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
				)

				Text(name)
					.font(.caption2)
					.lineLimit(1)
					.truncationMode(.tail)
			}
		}
		.buttonStyle(.plain)
	}

	private func sliderRow(
		label: String,
		value: Binding<Float>,
		range: ClosedRange<Float>,
		format: String
	) -> some View {
		HStack {
			Text(label)
				.foregroundColor(.secondary)
				.frame(width: 60, alignment: .leading)
			Slider(value: value, in: range)
			Text(String(format: format, value.wrappedValue))
				.font(.caption.monospacedDigit())
				.frame(width: 35, alignment: .trailing)
		}
	}

	private var backgroundColorBinding: Binding<Color> {
		Binding(
			get: {
				let c = configuration.backgroundColor
				return Color(red: Double(c.x), green: Double(c.y), blue: Double(c.z))
			},
			set: { color in
				let nsColor = NSColor(color)
				if let rgbColor = nsColor.usingColorSpace(.sRGB) {
					configuration.backgroundColor = SIMD4<Float>(
						Float(rgbColor.redComponent),
						Float(rgbColor.greenComponent),
						Float(rgbColor.blueComponent),
						1.0
					)
				}
			}
		)
	}

	private func thumbnailGradient(for path: String) -> LinearGradient {
		let name = EnvironmentMaps.displayName(for: path).lowercased()
		if name.contains("beach") || name.contains("sunset") {
			return LinearGradient(
				colors: [.blue, .orange, .red],
				startPoint: .top,
				endPoint: .bottom
			)
		} else if name.contains("night") || name.contains("downtown") {
			return LinearGradient(
				colors: [.black, .indigo],
				startPoint: .top,
				endPoint: .bottom
			)
		} else if name.contains("sunny") || name.contains("rooftop") {
			return LinearGradient(
				colors: [.blue, .yellow],
				startPoint: .top,
				endPoint: .bottom
			)
		} else if name.contains("overcast") || name.contains("neighborhood") {
			return LinearGradient(
				colors: [.gray, .blue.opacity(0.3)],
				startPoint: .top,
				endPoint: .bottom
			)
		} else if name.contains("warehouse") {
			return LinearGradient(
				colors: [.gray, .brown],
				startPoint: .top,
				endPoint: .bottom
			)
		} else if name.contains("arquicklook") || name.contains("arql") {
			return LinearGradient(
				colors: [.gray.opacity(0.8), .black],
				startPoint: .top,
				endPoint: .bottom
			)
		}
		return LinearGradient(
			colors: [.blue, .cyan],
			startPoint: .top,
			endPoint: .bottom
		)
	}

	private func iconName(for path: String) -> String {
		let name = EnvironmentMaps.displayName(for: path).lowercased()
		if name.contains("beach") || name.contains("sunset") { return "sun.horizon.fill" }
		if name.contains("night") || name.contains("downtown") { return "building.2.fill" }
		if name.contains("sunny") || name.contains("rooftop") { return "sun.max.fill" }
		if name.contains("overcast") || name.contains("neighborhood") { return "cloud.fill" }
		if name.contains("warehouse") { return "shippingbox.fill" }
		if name.contains("arquicklook") || name.contains("arql") { return "arkit" }
		return "circle.hexagongrid"
	}
}
