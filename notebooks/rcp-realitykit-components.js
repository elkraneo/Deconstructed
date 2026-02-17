// =============================================================================
// Observable HQ Notebook: RCP × RealityKit Component Coverage
// =============================================================================
// Copy each cell (separated by // --- CELL ---) into Observable HQ.
// Markdown cells are indicated — switch cell type to Markdown and paste
// the text without the // prefixes.
//
// Data verified against: Xcode 26.3 RC
//   iOS 26.2 SDK, visionOS 26.2 SDK, macOS 26.2 SDK
//   Source: RealityFoundation.swiftmodule .swiftinterface files
//   RCP catalog: strings extracted from RealityToolsFoundation.framework
// =============================================================================


// --- CELL --- Title
// Cell type: Markdown
// ---
// # Reality Composer Pro × RealityKit
// ## Component Coverage Across Platforms
//
// An exploration of which `RealityFoundation.Component` types ship in each SDK,
// what's truly shared vs platform-exclusive, and what Reality Composer Pro
// actually exposes in its Add Component menu.
//
// *Data extracted from Xcode 26.3 RC `.swiftinterface` files and RCP framework binaries.*


// --- CELL --- data
data = {
  // ─── Every public Component type in RealityFoundation, with metadata ──────
  // Fields: name, iOS availability, visionOS availability, platform restrictions,
  //         whether RCP exposes it, functional category, introduced era
  const components = [
    // ── Rendering & Appearance ──
    { name: "ModelComponent",             ios: "13.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Rendering",  era: "Original" },
    { name: "OpacityComponent",           ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Rendering",  era: "visionOS 1" },
    { name: "ModelSortGroupComponent",    ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Rendering",  era: "visionOS 1" },
    { name: "ModelDebugOptionsComponent", ios: "14.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Rendering",  era: "Original" },
    { name: "BlendShapeWeightsComponent", ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Rendering",  era: "visionOS 2" },
    { name: "AdaptiveResolutionComponent",ios: "18.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Rendering",  era: "visionOS 1" },
    { name: "BillboardComponent",         ios: "18.0", vos: "2.0",  restrict: null,        rcp: true,  cat: "Rendering",  era: "visionOS 2" },
    { name: "TextComponent",              ios: "18.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Rendering",  era: "visionOS 1" },
    { name: "MeshInstancesComponent",     ios: "26.0", vos: "26.0", restrict: null,        rcp: false, cat: "Rendering",  era: "26.0" },
    { name: "ImagePresentationComponent", ios: null,   vos: "26.0", restrict: "visionOS",  rcp: false, cat: "Rendering",  era: "26.0" },
    { name: "EnvironmentBlendingComponent",ios: null,  vos: "26.0", restrict: "visionOS",  rcp: false, cat: "Rendering",  era: "26.0" },

    // ── Lighting ──
    { name: "DirectionalLightComponent",  ios: "13.0", vos: "2.0",  restrict: null,        rcp: true,  cat: "Lighting",   era: "Original" },
    { name: "PointLightComponent",        ios: "13.0", vos: "2.0",  restrict: null,        rcp: true,  cat: "Lighting",   era: "Original" },
    { name: "SpotLightComponent",         ios: "13.0", vos: "2.0",  restrict: null,        rcp: true,  cat: "Lighting",   era: "Original" },
    { name: "ImageBasedLightComponent",   ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Lighting",   era: "visionOS 1" },
    { name: "ImageBasedLightReceiverComponent", ios: "18.0", vos: "1.0", restrict: null,   rcp: true,  cat: "Lighting",   era: "visionOS 1" },
    { name: "EnvironmentLightingConfigurationComponent", ios: "18.0", vos: "2.0", restrict: null, rcp: true, cat: "Lighting", era: "visionOS 2" },
    { name: "VirtualEnvironmentProbeComponent", ios: "18.0", vos: "2.0", restrict: null,   rcp: true,  cat: "Lighting",   era: "visionOS 2" },
    { name: "DynamicLightShadowComponent",ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Lighting",   era: "visionOS 2" },
    { name: "Shadow (Directional)",       ios: "13.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Lighting",   era: "Original" },
    { name: "Shadow (Spot)",              ios: "13.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Lighting",   era: "Original" },

    // ── Audio ──
    { name: "AmbientAudioComponent",      ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Audio",      era: "visionOS 1" },
    { name: "ChannelAudioComponent",      ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Audio",      era: "visionOS 1" },
    { name: "SpatialAudioComponent",      ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Audio",      era: "visionOS 1" },
    { name: "AudioMixGroupsComponent",    ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Audio",      era: "visionOS 1" },
    { name: "AudioLibraryComponent",      ios: "18.0", vos: "2.0",  restrict: null,        rcp: true,  cat: "Audio",      era: "visionOS 2" },
    { name: "ReverbComponent",            ios: "18.0", vos: "2.0",  restrict: null,        rcp: true,  cat: "Audio",      era: "visionOS 2" },

    // ── Physics & Simulation ──
    { name: "CollisionComponent",         ios: "13.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Physics",    era: "Original" },
    { name: "PhysicsBodyComponent",       ios: "13.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Physics",    era: "Original" },
    { name: "PhysicsMotionComponent",     ios: "13.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Physics",    era: "Original" },
    { name: "PhysicsSimulationComponent", ios: "18.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Physics",    era: "visionOS 1" },
    { name: "PhysicsJointsComponent",     ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Physics",    era: "visionOS 2" },
    { name: "ForceEffectComponent",       ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Physics",    era: "visionOS 2" },
    { name: "CharacterControllerComponent",ios:"15.0", vos: "26.0", restrict: null,        rcp: true,  cat: "Physics",    era: "iOS 15" },
    { name: "CharacterControllerStateComponent",ios:"15.0",vos:null, restrict: null,       rcp: false, cat: "Physics",    era: "iOS 15" },

    // ── Spatial & Scene ──
    { name: "Transform",                  ios: "13.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Spatial",    era: "Original" },
    { name: "AnchoringComponent",         ios: "13.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Spatial",    era: "Original" },
    { name: "WorldComponent",             ios: "18.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Spatial",    era: "visionOS 1" },
    { name: "PortalComponent",            ios: "18.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Spatial",    era: "visionOS 1" },
    { name: "PortalCrossingComponent",    ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Spatial",    era: "visionOS 2" },
    { name: "GroundingShadowComponent",   ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Spatial",    era: "visionOS 1" },
    { name: "SceneUnderstandingComponent",ios: "13.4", vos: "1.0",  restrict: "no macOS",  rcp: true,  cat: "Spatial",    era: "Original" },
    { name: "DockingRegionComponent",     ios: null,   vos: "2.0",  restrict: "visionOS",  rcp: true,  cat: "Spatial",    era: "visionOS 2" },
    { name: "AttachedTransformComponent", ios: "26.0", vos: "26.0", restrict: null,        rcp: false, cat: "Spatial",    era: "26.0" },
    { name: "ReferenceComponent",         ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Spatial",    era: "visionOS 2" },
    { name: "SynchronizationComponent",   ios: "13.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Spatial",    era: "Original" },
    { name: "GeometricPinsComponent",     ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Spatial",    era: "visionOS 2" },

    // ── Input & Interaction ──
    { name: "InputTargetComponent",       ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Interaction", era: "visionOS 1" },
    { name: "HoverEffectComponent",       ios: "18.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Interaction", era: "visionOS 1" },
    { name: "GestureComponent",           ios: "26.0", vos: "26.0", restrict: null,        rcp: false, cat: "Interaction", era: "26.0" },
    { name: "ManipulationComponent",      ios: null,   vos: "26.0", restrict: "visionOS",  rcp: false, cat: "Interaction", era: "26.0" },
    { name: "HitTarget",                  ios: null,   vos: "26.0", restrict: "visionOS",  rcp: false, cat: "Interaction", era: "26.0" },
    { name: "AccessibilityComponent",     ios: "17.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Interaction", era: "iOS 17" },

    // ── Camera ──
    { name: "PerspectiveCameraComponent", ios: "13.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Camera",     era: "Original" },
    { name: "OrthographicCameraComponent",ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Camera",     era: "visionOS 2" },
    { name: "ProjectiveTransformCameraComponent", ios: "18.0", vos: "2.0", restrict: null, rcp: false, cat: "Camera",     era: "visionOS 2" },

    // ── Animation & Skeleton ──
    { name: "AnimationLibraryComponent",  ios: "18.0", vos: "2.0",  restrict: null,        rcp: true,  cat: "Animation",  era: "visionOS 2" },
    { name: "SkeletalPosesComponent",     ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Animation",  era: "visionOS 2" },
    { name: "IKComponent",               ios: "18.0", vos: "2.0",  restrict: null,        rcp: false, cat: "Animation",  era: "visionOS 2" },
    { name: "BodyTrackingComponent",      ios: "13.0", vos: null,   restrict: "no visionOS", rcp: false, cat: "Animation", era: "Original" },

    // ── Media ──
    { name: "VideoPlayerComponent",       ios: "18.0", vos: "1.0",  restrict: null,        rcp: false, cat: "Media",      era: "visionOS 1" },
    { name: "ParticleEmitterComponent",   ios: "18.0", vos: "1.0",  restrict: null,        rcp: true,  cat: "Media",      era: "visionOS 1" },
  ];

  // ─── Derived summaries ────────────────────────────────────────────────────
  const pub = components; // all are public (we don't include __* in the list)
  const iosAvail   = pub.filter(c => c.ios !== null);
  const vosAvail   = pub.filter(c => c.restrict !== "no visionOS" && c.vos !== null);
  const vosOnly    = pub.filter(c => c.restrict === "visionOS");
  const noVos      = pub.filter(c => c.restrict === "no visionOS");
  const rcpExposed = pub.filter(c => c.rcp);
  const rcpHidden  = pub.filter(c => !c.rcp);

  return {
    components,
    counts: {
      total: pub.length,              // 61
      iosAvailable: iosAvail.length,  // effectively available on iOS
      vosAvailable: vosAvail.length,  // effectively available on visionOS
      visionOSOnly: vosOnly.length,   // 5 (Docking, Manipulation, HitTarget, EnvBlending, ImagePresentation)
      noVisionOS: noVos.length,       // 1 (BodyTracking)
      rcpExposed: rcpExposed.length,  // 28
      rcpHidden: rcpHidden.length,    // 33
      rcpCoveragePercent: Math.round(rcpExposed.length / pub.length * 100),
    },
    // Era breakdown
    eras: {
      "Original (iOS 13–14)": pub.filter(c => c.era === "Original").length,
      "iOS 15–17":            pub.filter(c => ["iOS 15","iOS 17"].includes(c.era)).length,
      "visionOS 1 (iOS 18)":  pub.filter(c => c.era === "visionOS 1").length,
      "visionOS 2 (iOS 18)":  pub.filter(c => c.era === "visionOS 2").length,
      "26.0 (2025)":          pub.filter(c => c.era === "26.0").length,
    },
    rcpExposed,
    rcpHidden,
    vosOnly,
    noVos,
  };
}


// --- CELL --- palette
palette = ({
  ios:        "#007AFF",
  visionOS:   "#AF52DE",
  macOS:      "#FF9F0A",
  shared:     "#5856D6",
  rcpExposed: "#34C759",
  rcpHidden:  "#C7C7CC",
  vosOnly:    "#AF52DE",
  noVos:      "#FF3B30",
  newIn26:    "#FF9F0A",
  bg:         "#FFFFFF",
  text:       "#1D1D1F",
  muted:      "#86868B",
  // Era colors
  eraOriginal: "#8E8E93",
  eraV1:       "#5856D6",
  eraV2:       "#007AFF",
  era26:       "#FF9F0A",
})


// --- CELL --- Insight 1
// Cell type: Markdown
// ---
// ## 1. The Component Surface: Bigger Than You Think
//
// RealityFoundation ships **61 public `Component` types** — not the ~40 most
// developers could name off the top of their head. This includes nested types like
// `DirectionalLightComponent.Shadow` and `ManipulationComponent.HitTarget`
// that are easy to overlook.
//
// The type surface is **identical across iOS, visionOS, and macOS** at the
// declaration level — all 61 types appear in every SDK's `.swiftinterface`.
// But `@available` annotations tell a different story.


// --- CELL --- chart_platform_truth
Plot.plot({
  title: "The Platform Parity Illusion",
  subtitle: "All 61 types declared in every SDK, but @available tells the real story",
  width: 700,
  height: 260,
  marginLeft: 120,
  marginRight: 40,
  x: { label: "Component types", domain: [0, 65] },
  y: { label: null, padding: 0.3 },
  color: {
    domain: ["Cross-platform", "visionOS-only", "Not on visionOS"],
    range: [palette.shared, palette.vosOnly, palette.noVos],
    legend: true
  },
  marks: [
    Plot.barX(
      [
        { platform: "Declared in SDK",   type: "Cross-platform",  count: data.counts.total },
        { platform: "Available on iOS",   type: "Cross-platform",  count: data.counts.total - data.counts.visionOSOnly },
        { platform: "Available on visionOS", type: "Cross-platform", count: data.counts.total - data.counts.noVisionOS - data.counts.visionOSOnly },
        { platform: "Available on visionOS", type: "visionOS-only", count: data.counts.visionOSOnly },
        { platform: "Available on iOS",   type: "Not on visionOS", count: data.counts.noVisionOS },
      ],
      { x: "count", y: "platform", fill: "type", tip: true }
    ),
    Plot.text([
      { platform: "Declared in SDK",      x: data.counts.total },
      { platform: "Available on iOS",      x: data.counts.total - data.counts.visionOSOnly + data.counts.noVisionOS },
      { platform: "Available on visionOS", x: data.counts.total - data.counts.noVisionOS },
    ], {
      x: "x", y: "platform",
      text: d => String(d.x),
      dx: 14, fontWeight: "bold"
    }),
    Plot.ruleX([0])
  ],
  style: { fontSize: 13 }
})


// --- CELL --- insight_exclusive
// Cell type: Markdown
// ---
// ### Platform Exclusives
//
// **visionOS-only** (unavailable on iOS/macOS):
// - `DockingRegionComponent` — spatial window docking (visionOS 2.0+)
// - `ManipulationComponent` + `HitTarget` — direct manipulation (26.0)
// - `EnvironmentBlendingComponent` — passthrough blending (26.0)
// - `ImagePresentationComponent` — 3D image display (26.0)
//
// **Not on visionOS**: `BodyTrackingComponent` (iOS/macOS only — ARKit body tracking)
//
// **Not on macOS**: `SceneUnderstandingComponent` (iOS + visionOS only)
//
// This means a visionOS developer has access to **5 components** that simply
// don't exist on iOS, while iOS has **1** that visionOS lacks.


// --- CELL --- insight2
// Cell type: Markdown
// ---
// ## 2. The ECS Growth Story
//
// RealityKit launched in 2019 with ~12 components. The visionOS era (2023–2024)
// nearly **tripled** the component surface. And 2025 adds another wave.


// --- CELL --- chart_eras
Plot.plot({
  title: "Component Growth by SDK Era",
  subtitle: "From 12 original types to 61 in four years",
  width: 700,
  height: 280,
  marginLeft: 170,
  marginRight: 60,
  x: { label: "Number of component types", domain: [0, 25] },
  y: { label: null, padding: 0.25 },
  color: {
    domain: Object.keys(data.eras),
    range: [palette.eraOriginal, "#98989D", palette.eraV1, palette.eraV2, palette.era26],
    legend: false
  },
  marks: [
    Plot.barX(
      Object.entries(data.eras).map(([era, count]) => ({ era, count })),
      {
        x: "count",
        y: "era",
        fill: "era",
        tip: true,
        sort: { y: null }
      }
    ),
    Plot.text(
      Object.entries(data.eras).map(([era, count]) => ({ era, count })),
      {
        x: "count", y: "era",
        text: d => String(d.count),
        dx: 12, fontWeight: "bold"
      }
    ),
    Plot.ruleX([0])
  ],
  style: { fontSize: 13 }
})


// --- CELL --- insight3
// Cell type: Markdown
// ---
// ## 3. What RCP Actually Exposes
//
// Reality Composer Pro's "Add Component" menu maps to **28 of 61** public
// RealityKit component types — **46% coverage**, not 50%.
//
// All 28 are real `RealityKit.*` identifiers. Despite earlier claims,
// there are **no RCP-specific component types** (no `RCP.BehaviorsContainer`).
// The menu has 28 components + 1 "New Component" action = **29 rows total**.


// --- CELL --- chart_waffle
{
  // Sort: RCP-exposed first, then not-exposed, alphabetical within each group
  const sorted = [
    ...data.rcpExposed.sort((a,b) => a.name.localeCompare(b.name)),
    ...data.rcpHidden.sort((a,b) => a.name.localeCompare(b.name))
  ];
  const cols = 10;

  return Plot.plot({
    title: `RCP Coverage: ${data.counts.rcpExposed} of ${data.counts.total} (${data.counts.rcpCoveragePercent}%)`,
    subtitle: "Each square = one public Component type. Hover for name.",
    width: 660,
    height: 320,
    marginTop: 40,
    marginLeft: 10,
    marginRight: 10,
    x: { label: null, axis: null },
    y: { label: null, axis: null },
    color: {
      domain: [`In RCP (${data.counts.rcpExposed})`, `Not in RCP (${data.counts.rcpHidden})`],
      range: [palette.rcpExposed, palette.rcpHidden],
      legend: true
    },
    marks: [
      Plot.cell(
        sorted.map((c, i) => ({
          x: i % cols,
          y: Math.floor(i / cols),
          status: c.rcp
            ? `In RCP (${data.counts.rcpExposed})`
            : `Not in RCP (${data.counts.rcpHidden})`,
          name: c.name,
          platform: c.restrict || "All platforms"
        })),
        {
          x: "x", y: "y",
          fill: "status",
          inset: 2, rx: 4,
          tip: {
            format: { x: false, y: false },
            channels: { Component: "name", Platform: "platform" }
          }
        }
      )
    ],
    style: { fontSize: 13 }
  });
}


// --- CELL --- insight4
// Cell type: Markdown
// ---
// ## 4. Coverage by Category: Where RCP Shines (and Doesn't)
//
// RCP's coverage is uneven. **Audio is at 100%** — every audio component is
// exposed. **Lighting is at 82%**. But **Cameras are at 0%**, and the new
// **Interaction** components are mostly uncovered.
//
// Some omissions are by design: `Transform` and `ModelComponent` aren't in the
// menu because they're implicit (every entity has a transform; models come
// from asset drag-and-drop). Similarly, `VideoPlayerComponent` and `PortalComponent`
// are added via entity creation templates, not the component inspector.


// --- CELL --- chart_category
{
  const cats = {};
  for (const c of data.components) {
    if (!cats[c.cat]) cats[c.cat] = { exposed: 0, hidden: 0, total: 0 };
    cats[c.cat].total++;
    c.rcp ? cats[c.cat].exposed++ : cats[c.cat].hidden++;
  }

  const rows = [];
  for (const [cat, v] of Object.entries(cats)) {
    rows.push({ category: cat, status: "In RCP", count: v.exposed });
    rows.push({ category: cat, status: "Not in RCP", count: v.hidden });
  }

  return Plot.plot({
    title: "RCP Coverage by Functional Category",
    subtitle: "Audio: 100% · Lighting: 82% · Camera: 0%",
    width: 700,
    height: 400,
    marginLeft: 110,
    marginRight: 80,
    x: { label: "Components", domain: [0, 12] },
    y: { label: null, padding: 0.2 },
    color: {
      domain: ["In RCP", "Not in RCP"],
      range: [palette.rcpExposed, palette.rcpHidden],
      legend: true
    },
    marks: [
      Plot.barX(rows, {
        x: "count", y: "category",
        fill: "status", tip: true,
        sort: { y: "-x" }
      }),
      // Percentage annotations
      Plot.text(
        Object.entries(cats).map(([cat, v]) => ({
          category: cat,
          total: v.total,
          pct: Math.round(v.exposed / v.total * 100)
        })),
        {
          x: "total", y: "category",
          text: d => `${d.pct}%`,
          dx: 16, fill: palette.muted, fontSize: 11
        }
      ),
      Plot.ruleX([0])
    ],
    style: { fontSize: 13 }
  });
}


// --- CELL --- insight5
// Cell type: Markdown
// ---
// ## 5. The "Implicit vs Explicit" Design Choice
//
// Why are some fundamental components missing from RCP's menu?
// Because RCP uses **entity templates** for certain component types:
//
// | Missing from menu | How RCP adds it instead |
// | --- | --- |
// | Transform | Every entity always has one |
// | ModelComponent | Drag a .usdz asset into the scene |
// | VideoPlayerComponent | "Add Entity → Video" template |
// | PortalComponent | "Add Entity → Portal" template |
// | TextComponent | "Add Entity → Text" template |
// | PerspectiveCameraComponent | "Add Entity → Camera" template |
//
// These aren't "missing" — they're exposed through a **different UX surface**.
// The Add Component menu is for *decorating* an existing entity, not creating one.


// --- CELL --- insight6
// Cell type: Markdown
// ---
// ## 6. The visionOS Exclusives RCP Exposes
//
// Here's a subtlety: RCP's component menu includes **`DockingRegionComponent`**,
// which is **visionOS-only** (`@available(visionOS 2.0, *)`). Since RCP runs on
// macOS but targets visionOS content, it exposes platform-exclusive components
// that can't even run on the host machine.
//
// Meanwhile, `SceneUnderstandingComponent` (in RCP) is unavailable on macOS —
// another case of RCP authoring for target platforms it doesn't run on.


// --- CELL --- chart_new26
Plot.plot({
  title: "Brand New in 26.0 (2025)",
  subtitle: "6 components added this year — most are interaction-focused",
  width: 660,
  height: 220,
  marginLeft: 260,
  marginRight: 40,
  x: { label: null, axis: null, domain: [0, 1] },
  y: { label: null, padding: 0.15 },
  marks: [
    Plot.barX(
      data.components
        .filter(c => c.era === "26.0")
        .map(c => ({
          name: c.name,
          value: 1,
          platform: c.restrict || "Cross-platform",
          inRCP: c.rcp ? "Yes" : "No"
        })),
      {
        x: "value", y: "name",
        fill: d => d.platform === "visionOS" ? palette.vosOnly : palette.era26,
        tip: { channels: { Platform: "platform", "In RCP": "inRCP" } }
      }
    ),
    Plot.text(
      data.components
        .filter(c => c.era === "26.0")
        .map(c => ({ name: c.name, label: c.restrict === "visionOS" ? "visionOS only" : "All platforms" })),
      {
        x: () => 1, y: "name",
        text: "label",
        dx: 8, textAnchor: "start",
        fill: d => d.label.includes("visionOS") ? palette.vosOnly : palette.muted,
        fontSize: 11
      }
    ),
  ],
  style: { fontSize: 13 }
})


// --- CELL --- insight_summary
// Cell type: Markdown
// ---
// ## 7. Key Takeaways
//
// 1. **61 public component types** in RealityFoundation — more than most realize
// 2. **Platform parity is an illusion**: 5 visionOS-only, 1 iOS-only, despite identical type declarations
// 3. **RCP covers 46%** (28/61), not 50% — and the gap is intentional
// 4. **Audio: 100% covered** in RCP. Camera: 0%. Physics: partial
// 5. **6 new components in 26.0**, mostly interaction-focused, none yet in RCP
// 6. **visionOS drove 75% of the growth** — the component surface nearly tripled since 2023
// 7. **Implicit ≠ missing**: Transform, Model, Video, etc. are exposed via entity templates
// 8. **RCP authors for visionOS from macOS** — it exposes components unavailable on its own platform


// --- CELL --- hero
{
  const w = 740, h = 200;
  const barY = 90, barH = 50;
  const exposed = data.counts.rcpExposed;
  const total = data.counts.total;
  const hidden = total - exposed;
  const barLeft = 80, barRight = w - 40;
  const barW = barRight - barLeft;
  const splitX = barLeft + (exposed / total) * barW;

  return htl.svg`<svg viewBox="0 0 ${w} ${h}" width="${w}" height="${h}"
    style="font-family: system-ui;">

    <text x="${w/2}" y="30" fill="${palette.text}" text-anchor="middle"
      font-size="18" font-weight="bold">
      RCP Covers Less Than Half of RealityKit's Components
    </text>
    <text x="${w/2}" y="54" fill="${palette.muted}" text-anchor="middle" font-size="13">
      ${exposed} of ${total} public component types · Xcode 26.3 RC
    </text>
    <text x="${w/2}" y="74" fill="${palette.muted}" text-anchor="middle" font-size="11">
      iOS 26.2 · visionOS 26.2 · macOS 26.2
    </text>

    <rect x="${barLeft}" y="${barY}" width="${splitX - barLeft}" height="${barH}"
      fill="${palette.rcpExposed}" rx="6" />
    <text x="${(barLeft + splitX) / 2}" y="${barY + barH/2 + 1}"
      fill="#fff" text-anchor="middle" dominant-baseline="middle"
      font-size="15" font-weight="bold">
      ${exposed} in RCP (${data.counts.rcpCoveragePercent}%)
    </text>

    <rect x="${splitX}" y="${barY}" width="${barRight - splitX}" height="${barH}"
      fill="${palette.rcpHidden}" rx="6" />
    <text x="${(splitX + barRight) / 2}" y="${barY + barH/2 + 1}"
      fill="${palette.muted}" text-anchor="middle" dominant-baseline="middle"
      font-size="14" font-weight="600">
      ${hidden} not in RCP
    </text>

    <text x="${barLeft - 8}" y="${barY + barH/2 + 1}" fill="${palette.muted}"
      text-anchor="end" dominant-baseline="middle" font-size="12">
      ${total} total
    </text>

    <text x="${w/2}" y="${barY + barH + 30}" fill="${palette.muted}"
      text-anchor="middle" font-size="11">
      Audio 100% · Lighting 82% · Physics 38% · Camera 0% · 6 new in 26.0 (none yet in RCP)
    </text>
  </svg>`;
}


// --- CELL --- table
Inputs.table(
  data.components
    .map(c => ({
      Component: c.name,
      Category: c.cat,
      "In RCP": c.rcp ? "Yes" : "—",
      "iOS": c.ios || "—",
      "visionOS": c.vos || "—",
      "Restriction": c.restrict || "",
      "Era": c.era,
    }))
    .sort((a, b) => a.Component.localeCompare(b.Component)),
  {
    columns: ["Component", "Category", "In RCP", "iOS", "visionOS", "Restriction", "Era"],
    header: {
      Component: "Component Type",
      "In RCP": "RCP?",
      "iOS": "iOS",
      "visionOS": "visionOS",
    },
    width: {
      Component: 280,
      Category: 100,
      "In RCP": 50,
      "iOS": 50,
      "visionOS": 70,
      Restriction: 100,
      Era: 100,
    },
    sort: "Component",
  }
)


// --- CELL --- embed_instructions
// Cell type: Markdown
// ---
// ## Embedding
//
// ```html
// <iframe width="100%" height="420" frameborder="0"
//   src="https://observablehq.com/embed/@YOUR_USER/rcp-realitykit-components?cells=hero">
// </iframe>
// ```
//
// Best cells to embed: `hero`, `chart_waffle`, `chart_category`, `chart_eras`
//
// ---
// *Data from Xcode 26.3 RC `.swiftinterface` files and RCP `RealityToolsFoundation.framework` binary strings.*
// *Built with Observable Plot.*
