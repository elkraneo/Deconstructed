# Schemas Tab Prototype (AccessibilityComponent)

Last updated: 2026-02-27
Fixture source:
- `/Volumes/Plutonian/_Developer/Deconstructed/source/RCPComponentDiffFixtures/Sources/RCPComponentDiffFixtures/RCPComponentDiffFixtures.rkassets/Accessibility`

## Why add a Schemas tab

`Fixtures` answer "what files exist."  
`Diffs` answer "what changed in this variant."  
`Schemas` should answer "what is the contract shape and how complete is our coverage."

For RCP injection research, this gives a stable contract view that sits above raw USDA diffs.

## Proposed IA in Deconstructed

Per component detail page:

1. `Overview`
2. `Fixtures`
3. `Diffs`
4. `Schemas` (new)

`Schemas` tab sections (top to bottom):

1. `Schema Summary`
   - Component ID, prim name, parent path pattern
   - Coverage status from fixtures (`Observed`, `Partial`, `Unknown`)
   - Breakage risk badge (`Low`, `Medium`, `High`)
2. `Canonical Shape`
   - Field list with type, optionality, default authoring behavior
3. `Observed Authoring Matrix`
   - Fixture variant vs field presence/value authored
4. `Contract Deltas`
   - Add/remove/change events compared with baseline fixture
5. `Cross-links`
   - Jump links to concrete fixture and diff artifacts

## AccessibilityComponent (real fixture-backed draft)

## Schema Summary

- Component: `AccessibilityComponent`
- Prim: `def RealityKitComponent "Accessibility"`
- ID: `RealityKit.Accessibility`
- Coverage: `Observed`
- Baseline fixture: `BASE.usda`
- Variants observed: `Label.usda`, `Value.usda`, `AccessibilityElement.usda`
- Risk: `Low` (flat scalar fields, no nested structs/relations observed)

## Canonical Shape (current evidence)

| Field | Type | Observed in BASE | Observed in variants | Notes |
| --- | --- | --- | --- | --- |
| `isEnabled` | `bool` | yes (`0`) | yes (`1` in `AccessibilityElement`) | omitted in `Label`/`Value` |
| `label` | `string` | yes (`""`) | yes (`"Some Label"`, `"Custom Label"`) | can be authored alone |
| `value` | `string` | yes (`""`) | yes (`"Some Value"`, long custom text) | can be authored alone |

Authoring pattern observed:
- BASE includes explicit defaults for all three fields.
- Field-specific variant files may omit unchanged siblings rather than re-authoring full struct content.

## Observed Authoring Matrix

| Variant | `isEnabled` | `label` | `value` | Practical interpretation |
| --- | --- | --- | --- | --- |
| `BASE.usda` | `0` | `""` | `""` | Full default seed state |
| `Label.usda` | omitted | `"Some Label"` | omitted | Sparse patch for label edit |
| `Value.usda` | omitted | omitted | `"Some Value"` | Sparse patch for value edit |
| `AccessibilityElement.usda` | `1` | `"Custom Label"` | `"This component makes my entity accessible "` | Multi-field authored state |

## Contract Deltas (baseline = BASE.usda)

1. `Label.usda`
   - Changed: `label` (`""` -> `"Some Label"`)
   - Omitted: `isEnabled`, `value`
2. `Value.usda`
   - Changed: `value` (`""` -> `"Some Value"`)
   - Omitted: `isEnabled`, `label`
3. `AccessibilityElement.usda`
   - Changed: `isEnabled` (`0` -> `1`)
   - Changed: `label` (`""` -> `"Custom Label"`)
   - Changed: `value` (`""` -> custom non-empty string)

## Density proposal (iterate target)

Compact mode (default):
- `Schema Summary` + single-line field chips:
  - `isEnabled: bool`
  - `label: string`
  - `value: string`
- One matrix row visible at a time, selectable variant.

Expanded mode:
- Full matrix + per-field default/omission notes.
- Inline USDA snippet anchors for each changed field.

Recommendation for first implementation:
1. Ship compact summary + canonical shape table.
2. Add matrix only for components with >= 3 fixture variants.
3. Keep raw USDA in linked detail view, not inline by default.

## Cross-links

- `BASE.usda`: `/Volumes/Plutonian/_Developer/Deconstructed/source/RCPComponentDiffFixtures/Sources/RCPComponentDiffFixtures/RCPComponentDiffFixtures.rkassets/Accessibility/BASE.usda`
- `Label.usda`: `/Volumes/Plutonian/_Developer/Deconstructed/source/RCPComponentDiffFixtures/Sources/RCPComponentDiffFixtures/RCPComponentDiffFixtures.rkassets/Accessibility/Label.usda`
- `Value.usda`: `/Volumes/Plutonian/_Developer/Deconstructed/source/RCPComponentDiffFixtures/Sources/RCPComponentDiffFixtures/RCPComponentDiffFixtures.rkassets/Accessibility/Value.usda`
- `AccessibilityElement.usda`: `/Volumes/Plutonian/_Developer/Deconstructed/source/RCPComponentDiffFixtures/Sources/RCPComponentDiffFixtures/RCPComponentDiffFixtures.rkassets/Accessibility/AccessibilityElement.usda`
