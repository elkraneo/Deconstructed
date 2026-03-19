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
                    
                    InspectorRow(label: "Emission Duration") {
                        HStack(spacing: 4) {
                            TextField("", value: currentStateDoubleBinding(for: "emissionDuration", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Idle Duration") {
                        HStack(spacing: 4) {
                            TextField("", value: currentStateDoubleBinding(for: "idleDuration", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Warmup Duration") {
                        HStack(spacing: 4) {
                            TextField("", value: currentStateDoubleBinding(for: "warmupDuration", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Speed") {
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
                    InspectorRow(label: "Emitter Shape") {
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
                            InspectorRow(label: "Inner Radius") {
                                TextField("", value: currentStateFloatBinding(for: "torusInnerRadius", fallback: 0.5), format: .number.precision(.fractionLength(0...2)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        
                        if ["Sphere", "Cone", "Cylinder", "Torus"].contains(shapeName) {
                            InspectorRow(label: "Radial Amount") {
                                TextField("", value: currentStateFloatBinding(for: "radialAmount", fallback: Float.pi), format: .number.precision(.fractionLength(0...2)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                    }
                    
                    InspectorRow(label: "Birth Location") {
                        Picker("", selection: currentStateStringBinding(for: "birthLocation", fallback: "Surface")) {
                            Text("Surface").tag("Surface")
                            Text("Volume").tag("Volume")
                            Text("Vertices").tag("Vertices")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    InspectorRow(label: "Birth Direction") {
                        Picker("", selection: currentStateStringBinding(for: "birthDirection", fallback: "Normal")) {
                            Text("Normal").tag("Normal")
                            Text("World").tag("World")
                            Text("Local").tag("Local")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    InspectorRow(label: "Shape Size") {
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
                    InspectorRow(label: "Spawn Occasion") {
                        Picker("", selection: currentStateStringBinding(for: "spawnOccasion", fallback: "OnDeath")) {
                            Text("On Birth").tag("OnBirth")
                            Text("On Death").tag("OnDeath")
                            Text("On Update").tag("OnUpdate")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    InspectorRow(label: "Velocity Factor") {
                        TextField("", value: currentStateFloatBinding(for: "spawnVelocityFactor", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Spread Factor") {
                        TextField("", value: currentStateFloatBinding(for: "spawnSpreadFactor", fallback: 0.0), format: .number.precision(.fractionLength(0...4)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Spread Variation") {
                        TextField("", value: currentStateFloatBinding(for: "spawnSpreadFactorVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...4)))
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
                    InspectorRow(label: "Birth Rate") {
                        TextField("", value: emitterFloatBinding(for: "birthRate", fallback: 100.0), format: .number.precision(.fractionLength(0...0)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Birth Rate Variation") {
                        TextField("", value: emitterFloatBinding(for: "birthRateVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...0)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Burst Count") {
                        TextField("", value: emitterIntBinding(for: "burstCount", fallback: 100), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Burst Count Variation") {
                        TextField("", value: emitterIntBinding(for: "burstCountVariation", fallback: 0), format: .number)
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
                    InspectorRow(label: "Life Span") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleLifeSpan", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Life Span Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterDoubleBinding(for: "particleLifeSpanVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Size") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleSize", fallback: 0.02), format: .number.precision(.fractionLength(0...3)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("cm")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Size Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleSizeVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...3)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("cm")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Size Over Life") {
                        TextField("", value: emitterFloatBinding(for: "sizeOverLife", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Size Over Life Power") {
                        TextField("", value: emitterFloatBinding(for: "sizeOverLifePower", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Mass") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleMass", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("g")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Mass Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleMassVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("g")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Orientation Mode") {
                        Picker("", selection: emitterStringBinding(for: "billboardMode", fallback: "Billboard")) {
                            Text("Billboard").tag("Billboard")
                            Text("Billboard Y Aligned").tag("BillboardYAligned")
                            Text("Free").tag("Free")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    InspectorRow(label: "Angle") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleAngle", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("°")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Angle Variation") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleAngleVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("°")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Stretch Factor") {
                        TextField("", value: emitterFloatBinding(for: "stretchFactor", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
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
                    
                    // Color picker for startColorA
                    ColorPicker("", selection: colorBinding(for: "startColorA"))
                        .labelsHidden()
                    
                    if let useRange = emitterValues["useStartColorRange"], case .bool(let isRange) = useRange, isRange {
                        ColorPicker("", selection: colorBinding(for: "startColorB"))
                            .labelsHidden()
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
                        
                        ColorPicker("", selection: colorBinding(for: "endColorA"))
                            .labelsHidden()
                        
                        if let useRange = emitterValues["useEndColorRange"], case .bool(let isRange) = useRange, isRange {
                            ColorPicker("", selection: colorBinding(for: "endColorB"))
                                .labelsHidden()
                        }
                    }
                    
                    Divider()
                    
                    InspectorRow(label: "Color Evolution Power") {
                        TextField("", value: emitterFloatBinding(for: "colorEvolutionPower", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Opacity Over Life") {
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
                    // TODO: Asset picker for particleImage
                    InspectorRow(label: "Particle Image") {
                        Button("Choose...") {
                            // TODO: Open file picker
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    InspectorRow(label: "Blend Mode") {
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
                        InspectorRow(label: "Frame Rate") {
                            TextField("", value: emitterFloatBinding(for: "frameRate", fallback: 12.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        InspectorRow(label: "Frame Rate Variation") {
                            TextField("", value: emitterFloatBinding(for: "frameRateVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        InspectorRow(label: "Initial Frame") {
                            TextField("", value: emitterIntBinding(for: "initialFrame", fallback: 0), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        InspectorRow(label: "Initial Frame Variation") {
                            TextField("", value: emitterIntBinding(for: "initialFrameVariation", fallback: 0), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        InspectorRow(label: "Row Count") {
                            TextField("", value: emitterIntBinding(for: "rowCount", fallback: 1), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        InspectorRow(label: "Column Count") {
                            TextField("", value: emitterIntBinding(for: "columnCount", fallback: 1), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        InspectorRow(label: "Animation Mode") {
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
                    InspectorRow(label: "Acceleration") {
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
                    
                    InspectorRow(label: "Drag") {
                        TextField("", value: emitterFloatBinding(for: "dampingFactor", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Spreading Angle") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "spreadingAngle", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("°")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Angular Velocity") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleAngularVelocity", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("rad/s")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    InspectorRow(label: "Angular Velocity Var") {
                        HStack(spacing: 4) {
                            TextField("", value: emitterFloatBinding(for: "particleAngularVelocityVariation", fallback: 0.0), format: .number.precision(.fractionLength(0...1)))
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
                    
                    InspectorRow(label: "Sort Order") {
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
                    InspectorRow(label: "Attraction Center") {
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
                    
                    InspectorRow(label: "Attraction Strength") {
                        TextField("", value: emitterFloatBinding(for: "radialGravityStrength", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Vortex Direction") {
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
                    
                    InspectorRow(label: "Vortex Strength") {
                        TextField("", value: emitterFloatBinding(for: "vortexStrength", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Noise Strength") {
                        TextField("", value: emitterFloatBinding(for: "noiseStrength", fallback: 0.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Noise Scale") {
                        TextField("", value: emitterFloatBinding(for: "noiseScale", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    InspectorRow(label: "Noise Speed") {
                        TextField("", value: emitterFloatBinding(for: "noiseAnimationSpeed", fallback: 1.0), format: .number.precision(.fractionLength(0...2)))
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
                if case .float(let value) = currentStateValues[key] { return Double(value) }
                return fallback
            },
            set: { newValue in
                currentStateValues[key] = .double(newValue)
                onCurrentStateChanged(key, .double(newValue))
            }
        )
    }
    
    private func currentStateFloatBinding(for key: String, fallback: Float) -> Binding<Float> {
        Binding(
            get: {
                if case .float(let value) = currentStateValues[key] { return value }
                if case .double(let value) = currentStateValues[key] { return Float(value) }
                return fallback
            },
            set: { newValue in
                currentStateValues[key] = .float(newValue)
                onCurrentStateChanged(key, .float(newValue))
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
    
    private func vectorComponentBinding(for key: String, index: Int, fallback: Float) -> Binding<String> {
        Binding(
            get: {
                if case .vector3(let vec) = currentStateValues[key] {
                    let components = [vec.x, vec.y, vec.z]
                    if index < components.count {
                        return String(format: "%.3f", components[index])
                    }
                }
                return String(format: "%.3f", fallback)
            },
            set: { newValue in
                guard let floatValue = Float(newValue) else { return }
                var currentVec: (x: Float, y: Float, z: Float) = (fallback, fallback, fallback)
                if case .vector3(let vec) = currentStateValues[key] {
                    currentVec = vec
                }
                let newVec: (x: Float, y: Float, z: Float)
                switch index {
                case 0: newVec = (floatValue, currentVec.y, currentVec.z)
                case 1: newVec = (currentVec.x, floatValue, currentVec.z)
                case 2: newVec = (currentVec.x, currentVec.y, floatValue)
                default: newVec = currentVec
                }
                currentStateValues[key] = .vector3(newVec)
                onCurrentStateChanged(key, .vector3(newVec))
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
                if case .float(let value) = values[key] { return Double(value) }
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
    
    private func emitterFloatBinding(for key: String, fallback: Float) -> Binding<Float> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .float(let value) = values[key] { return value }
                if case .double(let value) = values[key] { return Float(value) }
                return fallback
            },
            set: { newValue in
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .float(newValue)
                    onMainEmitterChanged(key, .float(newValue))
                } else {
                    spawnedEmitterValues[key] = .float(newValue)
                    onSpawnedEmitterChanged(key, .float(newValue))
                }
            }
        )
    }
    
    private func emitterIntBinding(for key: String, fallback: Int) -> Binding<Int> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .int(let value) = values[key] { return value }
                return fallback
            },
            set: { newValue in
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .int(newValue)
                    onMainEmitterChanged(key, .int(newValue))
                } else {
                    spawnedEmitterValues[key] = .int(newValue)
                    onSpawnedEmitterChanged(key, .int(newValue))
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
    
    private func emitterVectorComponentBinding(for key: String, index: Int, fallback: Float) -> Binding<String> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .vector3(let vec) = values[key] {
                    let components = [vec.x, vec.y, vec.z]
                    if index < components.count {
                        return String(format: "%.3f", components[index])
                    }
                }
                return String(format: "%.3f", fallback)
            },
            set: { newValue in
                guard let floatValue = Float(newValue) else { return }
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                var currentVec: (x: Float, y: Float, z: Float) = (fallback, fallback, fallback)
                if case .vector3(let vec) = values[key] {
                    currentVec = vec
                }
                let newVec: (x: Float, y: Float, z: Float)
                switch index {
                case 0: newVec = (floatValue, currentVec.y, currentVec.z)
                case 1: newVec = (currentVec.x, floatValue, currentVec.z)
                case 2: newVec = (currentVec.x, currentVec.y, floatValue)
                default: newVec = currentVec
                }
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .vector3(newVec)
                    onMainEmitterChanged(key, .vector3(newVec))
                } else {
                    spawnedEmitterValues[key] = .vector3(newVec)
                    onSpawnedEmitterChanged(key, .vector3(newVec))
                }
            }
        )
    }
    
    private func colorBinding(for key: String) -> Binding<Color> {
        Binding(
            get: {
                let values = selectedEmitter == .main ? mainEmitterValues : spawnedEmitterValues
                if case .vector4(let vec) = values[key] {
                    return Color(red: Double(vec.x), green: Double(vec.y), blue: Double(vec.z), opacity: Double(vec.w))
                }
                if case .vector3(let vec) = values[key] {
                    return Color(red: Double(vec.x), green: Double(vec.y), blue: Double(vec.z))
                }
                return Color.white
            },
            set: { newValue in
                // Convert Color to vector4 - requires platform-specific implementation
                // For now, this is a placeholder
                let components = newValue.cgColor?.components ?? [1, 1, 1, 1]
                let vec = (x: Float(components[0]), y: Float(components[1]), z: Float(components[2]), w: Float(components[3]))
                if selectedEmitter == .main {
                    mainEmitterValues[key] = .vector4(vec)
                    onMainEmitterChanged(key, .vector4(vec))
                } else {
                    spawnedEmitterValues[key] = .vector4(vec)
                    onSpawnedEmitterChanged(key, .vector4(vec))
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

// MARK: - Inspector Row Helper

struct InspectorRow<Content: View>: View {
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
