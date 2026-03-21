#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parent.parent
DEFAULT_FIXTURE_DIR = (
    REPO_ROOT.parent
    / "RCPComponentDiffFixtures"
    / "Sources"
    / "RCPComponentDiffFixtures"
    / "RCPComponentDiffFixtures.rkassets"
    / "Particle Emitter"
)
DEFAULT_OUTPUT = REPO_ROOT / "Docs" / "Generated" / "ParticleEmitterFixtures.csv"

ASSIGNMENT_PATTERN = re.compile(
    r"^\s*(?P<type>[A-Za-z0-9_:]+)\s+(?P<name>[A-Za-z0-9_:]+)\s*=\s*(?P<value>.+?)\s*$"
)
DEF_PATTERN = re.compile(r'^\s*def\s+[A-Za-z0-9_]+\s+"([^"]+)"')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export Particle Emitter USDA fixtures to a flat CSV."
    )
    parser.add_argument(
        "--fixture-dir",
        type=Path,
        default=DEFAULT_FIXTURE_DIR,
        help=f"Particle fixture directory (default: {DEFAULT_FIXTURE_DIR})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"CSV output path (default: {DEFAULT_OUTPUT})",
    )
    return parser.parse_args()


def normalize_label(raw_label: str) -> str:
    label = raw_label.removesuffix(".usda")
    label = label.replace("_", " ").strip()
    return " ".join(label.split())


def split_ui_path(relative_path: Path) -> tuple[str, str, str]:
    parts = list(relative_path.parts)
    if not parts:
        return "", "", ""

    if len(parts) == 1:
        return "", "", normalize_label(parts[0])

    ui_section = parts[0]
    ui_subsection = " / ".join(parts[1:-1])
    ui_label = normalize_label(parts[-1])
    return ui_section, ui_subsection, ui_label


def infer_conditions(relative_path: Path, field_name: str, struct_scope: str) -> str:
    path_text = str(relative_path)
    conditions: list[str] = []

    if struct_scope == "spawnedEmitter":
        conditions.append("Requires currentState.isSpawningEnabled")
    if "Animation" in path_text:
        conditions.append("Animation-related fixture")
    if "Emmiter Shape" in path_text and field_name in {"radialAmount", "torusInnerRadius"}:
        conditions.append("Shape-specific field")
    if field_name.endswith("Variation"):
        conditions.append("Variation field")

    return "; ".join(conditions)


def parse_fixture(fixture_path: Path, fixture_root: Path) -> list[dict[str, str]]:
    relative_path = fixture_path.relative_to(fixture_root)
    ui_section, ui_subsection, ui_label = split_ui_path(relative_path)

    rows: list[dict[str, str]] = []
    component_stack: list[str] = []
    inside_emitter = False

    for raw_line in fixture_path.read_text(encoding="utf-8").splitlines():
        def_match = DEF_PATTERN.match(raw_line)
        if def_match:
            name = def_match.group(1)
            component_stack.append(name)
            if len(component_stack) >= 1 and component_stack[-1] == "VFXEmitter":
                inside_emitter = True
            continue

        stripped = raw_line.strip()
        if stripped == "}":
            if component_stack:
                popped = component_stack.pop()
                if popped == "VFXEmitter":
                    inside_emitter = False
            continue

        if not inside_emitter:
            continue

        match = ASSIGNMENT_PATTERN.match(raw_line)
        if not match:
            continue

        field_type = match.group("type")
        field_name = match.group("name")
        field_value = match.group("value")

        if "currentState" not in component_stack:
            continue

        if "spawnedEmitter" in component_stack:
            struct_scope = "spawnedEmitter"
        elif "mainEmitter" in component_stack:
            struct_scope = "mainEmitter"
        else:
            struct_scope = "currentState"

        component_path = ".".join(["VFXEmitter"] + component_stack[1:] + [field_name])

        rows.append(
            {
                "fixture_path": str(relative_path),
                "fixture_name": normalize_label(relative_path.name),
                "ui_section": ui_section,
                "ui_subsection": ui_subsection,
                "ui_label": ui_label,
                "struct_scope": struct_scope,
                "field_name": field_name,
                "usd_type": field_type,
                "authored_value": field_value,
                "component_path": component_path,
                "conditions": infer_conditions(relative_path, field_name, struct_scope),
            }
        )

    return rows


def export_csv(fixture_dir: Path, output_path: Path) -> tuple[int, int]:
    fixture_paths = sorted(fixture_dir.rglob("*.usda"))
    rows: list[dict[str, str]] = []
    for fixture_path in fixture_paths:
        rows.extend(parse_fixture(fixture_path, fixture_dir))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(
            output_file,
            fieldnames=[
                "fixture_path",
                "fixture_name",
                "ui_section",
                "ui_subsection",
                "ui_label",
                "struct_scope",
                "field_name",
                "usd_type",
                "authored_value",
                "component_path",
                "conditions",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    return len(fixture_paths), len(rows)


def main() -> int:
    args = parse_args()
    fixture_dir = args.fixture_dir.resolve()
    output_path = args.output.resolve()

    if not fixture_dir.exists():
        raise SystemExit(f"Fixture directory does not exist: {fixture_dir}")

    fixture_count, row_count = export_csv(fixture_dir, output_path)
    print(f"Exported {row_count} rows from {fixture_count} fixtures to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
