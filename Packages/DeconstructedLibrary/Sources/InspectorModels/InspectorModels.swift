import Foundation

public struct SceneLayerData: Equatable, Sendable {
    public var defaultPrim: String?
    public var metersPerUnit: Double
    public var upAxis: UpAxis
    public var availablePrims: [String]
    
    public init(
        defaultPrim: String? = nil,
        metersPerUnit: Double = 1.0,
        upAxis: UpAxis = .y,
        availablePrims: [String] = []
    ) {
        self.defaultPrim = defaultPrim
        self.metersPerUnit = metersPerUnit
        self.upAxis = upAxis
        self.availablePrims = availablePrims
    }
}

public struct ScenePlaybackData: Equatable, Sendable {
    public var startTimeCode: Double
    public var endTimeCode: Double
    public var timeCodesPerSecond: Double
    public var autoPlay: Bool?
    public var playbackMode: String?
    public var animationTracks: [String]

    public init(
        startTimeCode: Double = 0,
        endTimeCode: Double = 0,
        timeCodesPerSecond: Double = 24,
        autoPlay: Bool? = nil,
        playbackMode: String? = nil,
        animationTracks: [String] = []
    ) {
        self.startTimeCode = startTimeCode
        self.endTimeCode = endTimeCode
        self.timeCodesPerSecond = timeCodesPerSecond
        self.autoPlay = autoPlay
        self.playbackMode = playbackMode
        self.animationTracks = animationTracks
    }

    public var hasTimeline: Bool {
        endTimeCode > startTimeCode || !animationTracks.isEmpty
    }
}

public enum UpAxis: String, CaseIterable, Sendable {
    case y = "Y"
    case z = "Z"
    
    public var displayName: String {
        rawValue
    }
}

public enum InspectorTarget: Equatable, Sendable {
    case sceneLayer
    case prim(path: String)
}

public struct InspectorContent: Equatable, Sendable {
    public var target: InspectorTarget
    public var layerData: SceneLayerData?
    public var isLoading: Bool
    public var errorMessage: String?
    
    public init(
        target: InspectorTarget = .sceneLayer,
        layerData: SceneLayerData? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.target = target
        self.layerData = layerData
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
}
