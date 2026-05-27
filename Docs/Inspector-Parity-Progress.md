# Inspector Parity Progress (SwiftUsdShell Migration)

Goal: close all remaining feature gaps between the orphan `InspectorUI` (pre-`SwiftUsdShell`) and the shell `InspectorShellUI`, so the branch `feature/swift-usd-shell-migration` reaches a clean checkpoint before the next phase (ShaderGraph).

Source-of-truth orphan file: `Packages/DeconstructedLibrary/Sources/InspectorUI/InspectorView.swift` (4063 lines).
Target shell file (root): `Packages/DeconstructedLibrary/Sources/InspectorShellUI/InspectorView.swift`.

Cross-cutting RPC spine for new actions (each new RPC requires edits in all four files):
1. `InspectorShellFeature/InspectorFeature.swift` — declare action + handle in reducer
2. `InspectorShellFeature/SceneInspectorClient.swift` — extend client interface
3. `DeconstructedShellRuntime/SceneInspectorClient+Live.swift` — install live binding
4. `DeconstructedShellRuntime/DeconstructedShellRuntime.swift` — implement via `DeconstructedUSDInterop`
5. `DeconstructedUSDInterop/DeconstructedUSDInterop.swift` — author the USD edit (open-source USDA text walker)

Build verification — always from repo root (per `AGENTS.md`):
```
swift build --target InspectorUI
```
Never `cd Packages/DeconstructedLibrary/ && swift build`.

---

## Phase 1 — Read-only audit (parallelisable)

- [x] **P1-A** Texture viewer drift: **PARITY** — `TextureValueView` is a near-line-for-line port (shell L2239–2270, orphan L812–851). `MaterialPropertyRow` covers the same value cases. No action needed.
- [x] **P1-B** Layer data audit findings (action items deferred under Phase 2.5):
	- Section title drift: shell says "Stage", orphan says "Layer Data" — rename header.
	- Missing "Convert Variants to Configurations" button (orphan L4024–4034, ships disabled).
	- Up Axis picker uses raw `"Y"`/`"Z"` instead of iterating `UpAxis.allCases` with `displayName`.
	- Default Prim picker has no explicit `None` tag — users can't clear an already-set default prim.

## Phase 2 — UI-only ports

- [x] **P2-A** Audio Mix Groups inline expose. **LANDED.** Added inline + per-group "Choose…" (NSOpenPanel UTType.audio). Today `addAudioMixGroupRequested` / `assignAudioMixGroupResourceRequested` are reachable only via the side-panel `AudioMixerPanel`. Expose them inline on `InlineAudioMixGroupsEditor` (Choose…/Add Mix Group buttons) — both actions already exist in `InspectorShellFeature`. Edits limited to `InspectorShellUI/InspectorView.swift` + the call site at `ComponentEditorRow.descendantEditor` / `InspectorView.body`.
- [x] **P2-B** Mesh Sorting Group section. **LANDED.** New `meshSortingGroupMembers` client endpoint + runtime walker; UI gated on `typeName == "RealityKitMeshSortingGroup"`. Depth Pass writes via existing `setComponentParameterRequested`. Adds `MeshSortingGroupSection` (Depth Pass picker: None / prePass / postPass + members list) when `selectedNode.typeName == "RealityKitMeshSortingGroup"`. Requires:
	- shell state field `meshSortingGroupMembers: [String]` (already exists in orphan store as `store.meshSortingGroupMembers`)
	- new action `setMeshSortingGroupDepthPassRequested(String)` — write `depthPass` token attribute via existing `setComponentParameter` flow on the selected prim.
	- Members are USD `class` relationship targets — query through new `SceneInspectorClient` endpoint OR derive from `primSummary` if attribute is already exposed. Investigate first.

## Phase 2.5 — Layer data fixes (UI-only)

- [x] **P2.5-A** Rename "Stage" header to "Layer Data". **LANDED.**
- [x] **P2.5-B** Drive Up Axis from `SceneUpAxis.allCases` with `displayName`. **LANDED.**
- [ ] **P2.5-C** Explicit "None" tag to Default Prim picker. **Deferred** — requires runtime support for clearing default prim (today `setDefaultPrim` does not accept empty string).
- [x] **P2.5-D** Disabled "Convert Variants to Configurations" placeholder button. **LANDED.**

## Phase 3 — RPC adds (sequential, cross-cutting)

These touch the same shell-feature + runtime + interop files; do them in one sweep to minimise merge churn.

- [x] **P3-A** Animation Library + Audio Mix Group RPCs. **LANDED.** New `DeconstructedShellRuntime/AssetAuthoring.swift` hosts file-copy + sanitize + unique-path helpers and the four statics (`addAudioMixGroup`, `assignAudioMixGroupResource`, `addAnimationLibraryResource`, `removeAnimationLibraryResource`). Audio mix group actions that were previously stubbed (`Inspector editing requires the SwiftUsdShell runtime adapter`) now go through the live runtime. `AnimationLibraryEditor` plus/minus buttons hit real add/remove RPCs instead of placeholder attribute writes.
- [x] **P3-B** Behaviors RPCs. **LANDED.** New `addBehavior(url, containerPath, triggerType)` + `removeBehavior(url, containerPath, behaviorPath)` on `SceneInspectorClient`, runtime delegates to existing `DeconstructedUSDInterop.addBehaviorToContainer` / `removeBehaviorFromContainer`. UI: Add Behavior menu now creates a real subprim; per-row `minus.circle` deletes.
- [x] **P3-C** UI callbacks landed alongside P3-A and P3-B.

## Phase 4 — Scene Playback section

- [x] **P4-A** Port `ScenePlaybackSection` from orphan (`InspectorUI/InspectorView.swift:3872`) into shell. Needs:
	- Shell state: `playbackData: ScenePlaybackData?`, `playbackCurrentTime: Double`, `isPlaying: Bool`, `playbackSpeed: Double` (model already exists in `InspectorModels.ScenePlaybackData`).
	- New actions: `playbackPlayPauseRequested`, `playbackStopRequested`, `playbackScrubRequested(time:isEditing:)`.
	- Stage metadata RPC must surface `startTimeCode` / `endTimeCode` / `timeCodesPerSecond` / `autoPlay` — likely already in `SwiftUsdShell.USDStageMetadata`. Verify and wire.
	- Timer-driven advance: replicate orphan's `Effect.run` clock loop in shell reducer.
	- Viewport coordination: if play state must drive viewport, expose `isPlaying` via a derived value the document editor reads.

## Phase 5 — Explicitly deferred

These need design work and runtime side-effects beyond the scope of this branch's checkpoint.

- Particle texture asset binding (nested descendant + USD reference, not flat attribute).
- Particle / Custom Docking preview video playback (runtime side-effect).
- Any "currentState/Idle|Playing|Paused" transport on the particle editor (RCP authoring exposes only the authoring attributes, not transport state).

---

## Progress log

- 2026-05-27 — Plan drafted. Committed Medium + Large tier parity push as `622202a` (see commit message for the full inventory).

## Resume-from-interruption notes

If interrupted, re-read this file first. The branch is `feature/swift-usd-shell-migration`. Look at:
- `git log --oneline feature/swift-usd-shell-migration | head -20` for what's already landed.
- The most recent commit message lists known RPC gaps and which editors got which affordances.
- TaskList may have entries #41-#46 (completed Large tier wiring). New tasks for these phases should be created under IDs #47+.
