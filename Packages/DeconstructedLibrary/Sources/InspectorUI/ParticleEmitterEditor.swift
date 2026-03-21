import SwiftUI
import InspectorModels

// MARK: - Particle Emitter Editor

public struct ParticleEmitterEditor: View {
    @Binding var currentStateValues: [String: InspectorComponentParameterValue]
    @Binding var mainEmitterValues: [String: InspectorComponentParameterValue]
    @Binding var spawnedEmitterValues: [String: InspectorComponentParameterValue]
    let onCurrentStateChanged: (String, InspectorComponentParameterValue) -> Void
    let onMainEmitterChanged: (String, InspectorComponentParameterValue) -> Void
    let onSpawnedEmitterChanged: (String, InspectorComponentParameterValue) -> Void
    
    @State private var selectedTab: ParticleEmitterTab = .emitter
    @State private var selectedEmitter: EmitterSelection = .main
    @State private var timingExpanded = true
    @State private var shapeExpanded = true
    @State private var spawningExpanded = true
    @State private var mainExpanded = true
    @State private var propertiesExpanded = true
    @State private var colorExpanded = true
    @State private var texturesExpanded = true
    @State private var animationExpanded = false
    @State private var motionExpanded = true
    @State private var renderingExpanded = true
    @State private var forceFieldsExpanded = true
    
    public init(
        currentStateValues: Binding<[String: InspectorComponentParameterValue]>,
        mainEmitterValues: Binding<[String: InspectorComponentParameterValue]>,
        spawnedEmitterValues: Binding<[String: InspectorComponentParameterValue]>,
        onCurrentStateChanged: @escaping (String, InspectorComponentParameterValue) -> Void,
        onMainEmitterChanged: @escaping (String, InspectorComponentParameterValue) -> Void,
        onSpawnedEmitterChanged: @escaping (String, InspectorComponentParameterValue) -> Void
    ) {
        self._currentStateValues = currentStateValues
        self._mainEmitterValues = mainEmitterValues
        self._spawnedEmitterValues = spawnedEmitterValues
        self.onCurrentStateChanged = onCurrentStateChanged
        self.onMainEmitterChanged = onMainEmitterChanged
        self.onSpawnedEmitterChanged = onSpawnedEmitterChanged
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tab Switcher
            Picker("Tab", selection: $selectedTab) {
                Text("Emitter").tag(ParticleEmitterTab.emitter)
                Text("Particles").tag(ParticleEmitterTab.particles)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)
            
            // Emitter Dropdown (for Particles tab)
            if selectedTab == .particles {
                emitterDropdown
            }
            
            Divider()
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == .emitter {
                        emitterTabContent
                    } else {
                        particlesTabContent
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Emitter Dropdown
    
    private var emitterDropdown: some View {
        HStack {
            Text("Emitter")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $selectedEmitter) {
                Text("Main").tag(EmitterSelection.main)
                Text("Secondary").tag(EmitterSelection.spawned)
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            .disabled(!isSecondaryEmitterEnabled)
        }
        .padding(.horizontal, 4)
    }
    
    private var isSecondaryEmitterEnabled: Bool {
        if case .bool(let value) = currentStateValues["isSpawningEnabled"] {
            return value
        }
        return false
    }
    
    // MARK: - Emitter Tab
    
    private var emitterTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timing Section
            DisclosureGroup("Timing", isExpanded: $timingExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Loop", isOn: currentStateBoolBinding(for: "loops", fallback: true))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                    
                    PEInspectorRow(label: "Emission Duration") {
                        HStack(spacing: 4) {
                            TextField("", value: currentStateDoubleBinding(for: "emissionDuration", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Idle Duration") {
                        HStack(spacing: 4) {
                            TextField("", value: currentStateDoubleBinding(for: "idleDuration", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Warmup Duration") {
                        HStack(spacing: 4) {
                            TextField("", value: currentStateDoubleBinding(for: "warmupDuration", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Speed") {
                        HStack(spacing: 4) {
                            TextField("", value: currentStateDoubleBinding(for: "simulationSpeed", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("×")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Shape Section
            DisclosureGroup("Shape", isExpanded: $shapeExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    PEInspectorRow(label: "Emitter Shape") {
                        Picker("", selection: currentStateStringBinding(for: "emitterShape", fallback: "Plane")) {
                            Text("Box").tag("Box")
                            Text("Sphere").tag("Sphere")
                            Text("Cone").tag("Cone")
                            Text("Cylinder").tag("Cylinder")
                            Text("Plane").tag("Plane")
                            Text("Point").tag("Point")
                            Text("Torus").tag("Torus")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    // Shape-specific fields
                    if let shape = currentStateValues["emitterShape"], case .string(let shapeName) = shape {
                        if shapeName == "Torus" {
                            PEInspectorRow(label: "Inner Radius") {
                                TextField("", value: currentStateDoubleBinding(for: "torusInnerRadius", fallback: 0.5), format: .number.precision(.fractionLength(0...2)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        
                        if ["Sphere", "Cone", "Cylinder", "Torus"].contains(shapeName) {
                            PEInspectorRow(label: "Radial Amount") {
                                TextField("", value: currentStateDoubleBinding(for: "radialAmount", fallback: Double.pi), format: .number.precision(.fractionLength(0...2)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                    }
                    
                    PEInspectorRow(label: "Birth Location") {
                        Picker("", selection: currentStateStringBinding(for: "birthLocation", fallback: "Surface")) {
                            Text("Surface").tag("Surface")
                            Text("Volume").tag("Volume")
                            Text("Vertices").tag("Vertices")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    PEInspectorRow(label: "Birth Direction") {
                        Picker("", selection: currentStateStringBinding(for: "birthDirection", fallback: "Normal")) {
                            Text("Normal").tag("Normal")
                            Text("World").tag("World")
                            Text("Local").tag("Local")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    PEInspectorRow(label: "Shape Size") {
                        HStack(spacing: 4) {
                            TextField("X", text: vectorComponentBinding(for: "shapeSize", index: 0, fallback: 0.1))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Y", text: vectorComponentBinding(for: "shapeSize", index: 1, fallback: 0.1))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Z", text: vectorComponentBinding(for: "shapeSize", index: 2, fallback: 0.1))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                    }
                    
                    Toggle("Particles in Local Space", isOn: currentStateBoolBinding(for: "isLocal", fallback: false))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                    
                    Toggle("Fields in Local Space", isOn: currentStateBoolBinding(for: "simulationInLocalSpace", fallback: false))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Spawning Section
            DisclosureGroup("Spawning", isExpanded: $spawningExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    PEInspectorRow(label: "Spawn Occasion") {
                        Picker("", selection: currentStateStringBinding(for: "spawnOccasion", fallback: "OnDeath")) {
                            Text("On Birth").tag("OnBirth")
                            Text("On Death").tag("OnDeath")
                            Text("On Update").tag("OnUpdate")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    PEInspectorRow(label: "Velocity Factor") {
                        TextField("", value: currentStateDoubleBinding(for: "spawnVelocityFactor", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Spread Factor") {
                        TextField("", value: currentStateDoubleBinding(for: "spawnSpreadFactor", fallback: 0.0), format: .number.precision(.fractionLength(0...4)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Spread Variation") {
                        TextField("", value: currentStateDoubleBinding(for: "spawnSpreadFactorVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...4)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    Toggle("Inherit Color", isOn: currentStateBoolBinding(for: "spawnInheritParentColor", fallback: false))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
        }
    }
    
    // MARK: - Particles Tab
    
    private var particlesTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Secondary Emitter Toggle (only in Particles tab)
            if selectedEmitter == .main {
                Toggle("Secondary Emitter Enabled", isOn: currentStateBoolBinding(for: "isSpawningEnabled", fallback: false))
                    .font(.system(size: 11, weight: .semibold))
                    .toggleStyle(.checkbox)
                    .padding(.bottom, 8)
            }
            
            // Main Section
            DisclosureGroup("Main", isExpanded: $mainExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    PEInspectorRow(label: "Birth Rate") {
                        TextField("", value: emitterDoubleBinding(for: "birthRate", fallback: 100.0), format: .number.precision(.fractionLength(0...0)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Birth Rate Variation") {
                        TextField("", value: emitterDoubleBinding(for: "birthRateVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...0)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Burst Count") {
                        TextField("", text: emitterIntStringBinding(for: "burstCount", fallback: 100))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Burst Count Variation") {
                        TextField("", text: emitterIntStringBinding(for: "burstCountVariation", fallback: 0))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Properties Section
            DisclosureGroup("Properties", isExpanded: $propertiesExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    PEInspectorRow(label: "Life Span") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleLifeSpan", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Life Span Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleLifeSpanVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Size") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleSize", fallback: 0.02), format: .number.precision(.fractionLength(0...3)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("cm")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Size Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleSizeVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...3)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("cm")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Size Over Life") {
                        TextField("", value: emitterDoubleBinding(for: "sizeOverLife", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Size Over Life Power") {
                        TextField("", value: emitterDoubleBinding(for: "sizeOverLifePower", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Mass") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleMass", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("g")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Mass Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleMassVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("g")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Orientation Mode") {
                        Picker("", selection: emitterStringBinding(for: "billboardMode", fallback: "Billboard")) {
                            Text("Billboard").tag("Billboard")
                            Text("Billboard Y Aligned").tag("BillboardYAligned")
                            Text("Free").tag("Free")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    PEInspectorRow(label: "Angle") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleAngle", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("°")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Angle Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleAngleVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("°")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Stretch Factor") {
                        TextField("", value: emitterDoubleBinding(for: "stretchFactor", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Color Section
            DisclosureGroup("Color", isExpanded: $colorExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    // Start Color
                    HStack {
                        Text("Start Color")
                            .font(.system(size: 11))
                        Spacer()
                        Toggle("Range", isOn: emitterBoolBinding(for: "useStartColorRange", fallback: false))
                            .font(.system(size: 10))
                            .toggleStyle(.checkbox)
                    }
                    
                    // Color text field for startColorA
                    PEInspectorRow(label: "") {
                        TextField("RGBA", text: emitterColorStringBinding(for: "startColorA", fallback: "(1, 1, 1, 1)"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                    }
                    
                    if let useRange = emitterValues["useStartColorRange"], case .bool(let isRange) = useRange, isRange {
                        PEInspectorRow(label: "") {
                            TextField("RGBA", text: emitterColorStringBinding(for: "startColorB", fallback: "(1, 1, 1, 1)"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                        }
                    }
                    
                    Divider()
                    
                    // End Color
                    HStack {
                        Text("End Color")
                            .font(.system(size: 11))
                        Spacer()
                        Toggle("Enable", isOn: emitterBoolBinding(for: "useEndColor", fallback: false))
                            .font(.system(size: 10))
                            .toggleStyle(.checkbox)
                    }
                    
                    if let useEnd = emitterValues["useEndColor"], case .bool(let isEnabled) = useEnd, isEnabled {
                        Toggle("Range", isOn: emitterBoolBinding(for: "useEndColorRange", fallback: false))
                            .font(.system(size: 10))
                            .toggleStyle(.checkbox)
                        
                        PEInspectorRow(label: "") {
                            TextField("RGBA", text: emitterColorStringBinding(for: "endColorA", fallback: "(1, 1, 1, 1)"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                        }
                        
                        if let useRange = emitterValues["useEndColorRange"], case .bool(let isRange) = useRange, isRange {
                            PEInspectorRow(label: "") {
                                TextField("RGBA", text: emitterColorStringBinding(for: "endColorB", fallback: "(1, 1, 1, 1)"))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                            }
                        }
                    }
                    
                    Divider()
                    
                    PEInspectorRow(label: "Color Evolution Power") {
                        TextField("", value: emitterDoubleBinding(for: "colorEvolutionPower", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Opacity Over Life") {
                        Picker("", selection: emitterStringBinding(for: "opacityOverLife", fallback: "QuickFadeInOut")) {
                            Text("Constant").tag("Constant")
                            Text("Ease Fade In").tag("EaseFadeIn")
                            Text("Ease Fade Out").tag("EaseFadeOut")
                            Text("Gradual Fade In Out").tag("GradualFadeInOut")
                            Text("Linear Fade In").tag("LinearFadeIn")
                            Text("Linear Fade Out").tag("LinearFadeOut")
                            Text("Quick Fade In Out").tag("QuickFadeInOut")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Textures Section
            DisclosureGroup("Textures", isExpanded: $texturesExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    PEInspectorRow(label: "Particle Image") {
                        Button("Choose...") {
                            // TODO: Open file picker
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    PEInspectorRow(label: "Blend Mode") {
                        Picker("", selection: emitterStringBinding(for: "blendMode", fallback: "Alpha")) {
                            Text("Alpha").tag("Alpha")
                            Text("Additive").tag("Additive")
                            Text("Opaque").tag("Opaque")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Animation Section (conditional)
            DisclosureGroup("Animation", isExpanded: $animationExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Is Animated", isOn: emitterBoolBinding(for: "isAnimated", fallback: false))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                    
                    if let isAnim = emitterValues["isAnimated"], case .bool(let animated) = isAnim, animated {
                        PEInspectorRow(label: "Frame Rate") {
                            TextField("", value: emitterDoubleBinding(for: "frameRate", fallback: 12.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        PEInspectorRow(label: "Frame Rate Variation") {
                            TextField("", value: emitterDoubleBinding(for: "frameRateVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        PEInspectorRow(label: "Initial Frame") {
                            TextField("", text: emitterIntStringBinding(for: "initialFrame", fallback: 0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        PEInspectorRow(label: "Initial Frame Variation") {
                            TextField("", text: emitterIntStringBinding(for: "initialFrameVariation", fallback: 0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        PEInspectorRow(label: "Row Count") {
                            TextField("", text: emitterIntStringBinding(for: "rowCount", fallback: 1))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        PEInspectorRow(label: "Column Count") {
                            TextField("", text: emitterIntStringBinding(for: "columnCount", fallback: 1))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        PEInspectorRow(label: "Animation Mode") {
                            Picker("", selection: emitterStringBinding(for: "animationRepeatMode", fallback: "Looping")) {
                                Text("Looping").tag("Looping")
                                Text("Auto Reverse").tag("AutoReverse")
                                Text("Play Once").tag("PlayOnce")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Motion Section
            DisclosureGroup("Motion", isExpanded: $motionExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    PEInspectorRow(label: "Acceleration") {
                        HStack(spacing: 4) {
                            TextField("X", text: emitterVectorComponentBinding(for: "acceleration", index: 0, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Y", text: emitterVectorComponentBinding(for: "acceleration", index: 1, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Z", text: emitterVectorComponentBinding(for: "acceleration", index: 2, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                    }
                    
                    PEInspectorRow(label: "Drag") {
                        TextField("", value: emitterDoubleBinding(for: "dampingFactor", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Spreading Angle") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "spreadingAngle", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("°")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Angular Velocity") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleAngularVelocity", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("rad/s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    PEInspectorRow(label: "Angular Velocity Var") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleAngularVelocityVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("rad/s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Rendering Section
            DisclosureGroup("Rendering", isExpanded: $renderingExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Lighting Enabled", isOn: emitterBoolBinding(for: "isLightingEnabled", fallback: false))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                    
                    PEInspectorRow(label: "Sort Order") {
                        Picker("", selection: emitterStringBinding(for: "sortOrder", fallback: "Unsorted")) {
                            Text("Unsorted").tag("Unsorted")
                            Text("Increasing ID").tag("IncreasingID")
                            Text("Decreasing ID").tag("DecreasingID")
                            Text("Increasing Age").tag("IncreasingAge")
                            Text("Decreasing Age").tag("DecreasingAge")
                            Text("Increasing Depth").tag("IncreasingDepth")
                            Text("Decreasing Depth").tag("DecreasingDepth")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
            
            // Force Fields Section
            DisclosureGroup("Force Fields", isExpanded: $forceFieldsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    PEInspectorRow(label: "Attraction Center") {
                        HStack(spacing: 4) {
                            TextField("X", text: emitterVectorComponentBinding(for: "radialGravityCenter", index: 0, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Y", text: emitterVectorComponentBinding(for: "radialGravityCenter", index: 1, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Z", text: emitterVectorComponentBinding(for: "radialGravityCenter", index: 2, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                    }
                    
                    PEInspectorRow(label: "Attraction Strength") {
                        TextField("", value: emitterDoubleBinding(for: "radialGravityStrength", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Vortex Direction") {
                        HStack(spacing: 4) {
                            TextField("X", text: emitterVectorComponentBinding(for: "vortexDirection", index: 0, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Y", text: emitterVectorComponentBinding(for: "vortexDirection", index: 1, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            TextField("Z", text: emitterVectorComponentBinding(for: "vortexDirection", index: 2, fallback: 0.0))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                    }
                    
                    PEInspectorRow(label: "Vortex Strength") {
                        TextField("", value: emitterDoubleBinding(for: "vortexStrength", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Noise Strength") {
                        TextField("", value: emitterDoubleBinding(for: "noiseStrength", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Noise Scale") {
                        TextField("", value: emitterDoubleBinding(for: "noiseScale", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    PEInspectorRow(label: "Noise Speed") {
                        TextField("", value: emitterDoubleBinding(for: "noiseAnimationSpeed", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                .padding(.vertical, 4)
            }
            .font(.system(size: 11, weight: .semibold))
        }
    }
    
    // MARK: - Helper Properties
    
    private var emitterValues: [String: InspectorComponentParameterValue] {
        selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
    }
    
    // MARK: - Binding Helpers
    
    private func currentStateBoolBinding(for key: String, fallback: Bool) -> Binding<Bool> {
        Binding(
            get: {
                if case .bool(let value) = currentStateValues[key] { return value }
                return fallback
            },
            set: { newValue in
                currentStateValues[key] = .bool(newValue)
                onCurrentStateChanged(key, .bool(newValue))
            }
        )
    }
    
    private func currentStateDoubleBinding(for key: String, fallback: Double) -> Binding<Double> {
        Binding(
            get: {
                if case .double(let value) = currentStateValues[key] { return value }
                return fallback
            },
            set: { newValue in
                currentStateValues[key] = .double(newValue)
                onCurrentStateChanged(key, .double(newValue))
            }
        )
    }
    
    private func currentStateStringBinding(for key: String, fallback: String) -> Binding<String> {
        Binding(
            get: {
                if case .string(let value) = currentStateValues[key] { return value }
                return fallback
            },
            set: { newValue in
                currentStateValues[key] = .string(newValue)
                onCurrentStateChanged(key, .string(newValue))
            }
        )
    }
    
    private func vectorComponentBinding(for key: String, index: Int, fallback: Double) -> Binding<String> {
        Binding(
            get: {
                if case .string(let str) = currentStateValues[key] {
                    let components = parseVector3(str)
                    let values = [components.x, components.y, components.z]
                    if index < values.count {
                        return String(format: "%.3f", values[index])
                    }
                }
                return String(format: "%.3f", fallback)
            },
            set: { newValue in
                guard let doubleValue = Double(newValue) else { return }
                var currentComponents = (x: fallback, y: fallback, z: fallback)
                if case .string(let str) = currentStateValues[key] {
                    currentComponents = parseVector3(str)
                }
                let newComponents: (x: Double, y: Double, z: Double)
                switch index {
                case 0: newComponents = (doubleValue, currentComponents.y, currentComponents.z)
                case 1: newComponents = (currentComponents.x, doubleValue, currentComponents.z)
                case 2: newComponents = (currentComponents.x, currentComponents.y, doubleValue)
                default: newComponents = currentComponents
                }
                let vectorString = String(format: "(%.3f, %.3f, %.3f)", newComponents.x, newComponents.y, newComponents.z)
                currentStateValues[key] = .string(vectorString)
                onCurrentStateChanged(key, .string(vectorString))
            }
        )
    }
    
    private func emitterBoolBinding(for key: String, fallback: Bool) -> Binding<Bool> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .bool(let value) = values[key] { return value }
                return fallback
            },
            set: { newValue in
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .bool(newValue)
                    onMainEmitterChanged(key, .bool(newValue))
                } else {
                    spawnedEmitterValues[key] = .bool(newValue)
                    onSpawnedEmitterChanged(key, .bool(newValue))
                }
            }
        )
    }
    
    private func emitterDoubleBinding(for key: String, fallback: Double) -> Binding<Double> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .double(let value) = values[key] { return value }
                return fallback
            },
            set: { newValue in
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .double(newValue)
                    onMainEmitterChanged(key, .double(newValue))
                } else {
                    spawnedEmitterValues[key] = .double(newValue)
                    onSpawnedEmitterChanged(key, .double(newValue))
                }
            }
        )
    }
    
    private func emitterIntStringBinding(for key: String, fallback: Int) -> Binding<String> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .double(let value) = values[key] {
                    return String(Int(value))
                }
                return String(fallback)
            },
            set: { newValue in
                guard let intValue = Int(newValue) else { return }
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .double(Double(intValue))
                    onMainEmitterChanged(key, .double(Double(intValue)))
                } else {
                    spawnedEmitterValues[key] = .double(Double(intValue))
                    onSpawnedEmitterChanged(key, .double(Double(intValue)))
                }
            }
        )
    }
    
    private func emitterStringBinding(for key: String, fallback: String) -> Binding<String> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .string(let value) = values[key] { return value }
                return fallback
            },
            set: { newValue in
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .string(newValue)
                    onMainEmitterChanged(key, .string(newValue))
                } else {
                    spawnedEmitterValues[key] = .string(newValue)
                    onSpawnedEmitterChanged(key, .string(newValue))
                }
            }
        )
    }
    
    private func emitterVectorComponentBinding(for key: String, index: Int, fallback: Double) -> Binding<String> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .string(let str) = values[key] {
                    let components = parseVector3(str)
                    let values = [components.x, components.y, components.z]
                    if index < values.count {
                        return String(format: "%.3f", values[index])
                    }
                }
                return String(format: "%.3f", fallback)
            },
            set: { newValue in
                guard let doubleValue = Double(newValue) else { return }
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                var currentComponents = (x: fallback, y: fallback, z: fallback)
                if case .string(let str) = values[key] {
                    currentComponents = parseVector3(str)
                }
                let newComponents: (x: Double, y: Double, z: Double)
                switch index {
                case 0: newComponents = (doubleValue, currentComponents.y, currentComponents.z)
                case 1: newComponents = (currentComponents.x, doubleValue, currentComponents.z)
                case 2: newComponents = (currentComponents.x, currentComponents.y, doubleValue)
                default: newComponents = currentComponents
                }
                let vectorString = String(format: "(%.3f, %.3f, %.3f)", newComponents.x, newComponents.y, newComponents.z)
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .string(vectorString)
                    onMainEmitterChanged(key, .string(vectorString))
                } else {
                    spawnedEmitterValues[key] = .string(vectorString)
                    onSpawnedEmitterChanged(key, .string(vectorString))
                }
            }
        )
    }
    
    private func emitterColorStringBinding(for key: String, fallback: String) -> Binding<String> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .string(let value) = values[key] { return value }
                return fallback
            },
            set: { newValue in
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .string(newValue)
                    onMainEmitterChanged(key, .string(newValue))
                } else {
                    spawnedEmitterValues[key] = .string(newValue)
                    onSpawnedEmitterChanged(key, .string(newValue))
                }
            }
        )
    }
}

// MARK: - Supporting Types

enum ParticleEmitterTab {
    case emitter
    case particles
}

enum EmitterSelection {
    case main
    case spawned
}

// MARK: - Helper Functions

private func parseVector3(_ str: String) -> (x: Double, y: Double, z: Double) {
    // Parse format: "(x, y, z)" or "(x,y,z)"
    let trimmed = str.trimmingCharacters(in: .whitespaces)
    let withoutParens = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
    let components = withoutParens.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    
    guard components.count == 3 else {
        return (0, 0, 0)
    }
    
    return (
        Double(components[0]) ?? 0,
        Double(components[1]) ?? 0,
        Double(components[2]) ?? 0
    )
}

// MARK: - Inspector Row Helper (prefixed to avoid conflict)

struct PEInspectorRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
            Spacer()
            content()
        }
    }
}
