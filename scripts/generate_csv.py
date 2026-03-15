#!/usr/bin/env python3
"""
generate_csv.py
Generates or validates the comparison_matrix.csv from collected metadata.
Can operate in two modes:
  1. Generate from raw JSON files (output of collect_metadata.sh)
  2. Validate existing CSV for consistency

Usage:
    python scripts/generate_csv.py --from-json data/raw/
    python scripts/generate_csv.py --validate data/comparison_matrix.csv
    python scripts/generate_csv.py --help
"""

import argparse
import csv
import json
import sys
from pathlib import Path

# ─── Schema definition ────────────────────────────────────────────────────────

CSV_FIELDS = [
    "client",
    "client_type",       # consensus | execution
    "language",
    "ci_platform",
    "workflow_count",
    "build_tool",
    "package_manager",
    "lockfile",
    "lockfile_committed",   # yes | no | partial
    "docker_support",
    "docker_registry",
    "uses_bazel",
    "arm_support",          # yes | no | partial
    "reproducible_builds",  # yes | no
    "notes",
]

# Manually curated data (ground truth from analysis)
CURATED_DATA = [
    {
        "client": "lighthouse",
        "client_type": "consensus",
        "language": "Rust",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~10-12",
        "build_tool": "cargo, make",
        "package_manager": "cargo",
        "lockfile": "Cargo.lock",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "ghcr.io",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "no",
        "notes": "rust-toolchain.toml pins exact toolchain; cross for ARM",
    },
    {
        "client": "prysm",
        "client_type": "consensus",
        "language": "Go",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~8-10",
        "build_tool": "bazel/bazelisk, go modules, make",
        "package_manager": "go-modules",
        "lockfile": "go.sum, WORKSPACE",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "gcr.io",
        "uses_bazel": "yes",
        "arm_support": "partial",
        "reproducible_builds": "yes",
        "notes": "Only client using Bazel; hermetic builds; distroless containers",
    },
    {
        "client": "teku",
        "client_type": "consensus",
        "language": "Java",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~6-8",
        "build_tool": "gradle",
        "package_manager": "gradle/maven-central",
        "lockfile": "gradle.lockfile",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "docker-hub",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "no",
        "notes": "Consensys; shares Java+Gradle pattern with Besu",
    },
    {
        "client": "nimbus",
        "client_type": "consensus",
        "language": "Nim",
        "ci_platform": "GitHub Actions (primary), Jenkins (historical)",
        "workflow_count": "~8-12",
        "build_tool": "make, nimble",
        "package_manager": "git-submodules",
        "lockfile": "git submodule SHAs (.gitmodules)",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "docker-hub",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "no",
        "notes": "Only Nim client; no package registry; strongest supply chain isolation; best ARM support",
    },
    {
        "client": "lodestar",
        "client_type": "consensus",
        "language": "TypeScript",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~8-10",
        "build_tool": "pnpm, tsc",
        "package_manager": "pnpm",
        "lockfile": "pnpm-lock.yaml",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "docker-hub",
        "uses_bazel": "no",
        "arm_support": "partial",
        "reproducible_builds": "no",
        "notes": "Only TypeScript client; pnpm chosen for supply chain security (blocks postinstall scripts)",
    },
    {
        "client": "grandine",
        "client_type": "consensus",
        "language": "Rust",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~4-6",
        "build_tool": "cargo",
        "package_manager": "cargo",
        "lockfile": "Cargo.lock",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "ghcr.io",
        "uses_bazel": "no",
        "arm_support": "partial",
        "reproducible_builds": "no",
        "notes": "Simplest CI of all consensus clients; fewest workflows",
    },
    {
        "client": "geth",
        "client_type": "execution",
        "language": "Go",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~8-10",
        "build_tool": "go modules, make, build/ci.go",
        "package_manager": "go-modules",
        "lockfile": "go.sum",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "docker-hub",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "no",
        "notes": "Custom Go CI orchestration script (build/ci.go); Azure Blob Storage for artifacts",
    },
    {
        "client": "nethermind",
        "client_type": "execution",
        "language": "C#",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~20+",
        "build_tool": "dotnet/msbuild, cmake",
        "package_manager": "nuget",
        "lockfile": "packages.lock.json (partial)",
        "lockfile_committed": "partial",
        "docker_support": "yes",
        "docker_registry": "docker-hub",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "yes",
        "notes": "Most complex CI; 5 native C/C++ library builds; SOURCE_DATE_EPOCH reproducibility",
    },
    {
        "client": "besu",
        "client_type": "execution",
        "language": "Java",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~10-12",
        "build_tool": "gradle",
        "package_manager": "gradle/maven-central",
        "lockfile": "gradle.lockfile",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "docker-hub",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "no",
        "notes": "Consensys/Hyperledger; DCO validation; Spotless formatter; Repolinter",
    },
    {
        "client": "erigon",
        "client_type": "execution",
        "language": "Go",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~10-14",
        "build_tool": "go modules, make",
        "package_manager": "go-modules",
        "lockfile": "go.sum",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "docker-hub",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "no",
        "notes": "Kurtosis multi-client testnet in CI; Assertoor; docker-compose stack",
    },
    {
        "client": "reth",
        "client_type": "execution",
        "language": "Rust",
        "ci_platform": "GitHub Actions",
        "workflow_count": "~10-14",
        "build_tool": "cargo, cargo-nextest, cross",
        "package_manager": "cargo",
        "lockfile": "Cargo.lock",
        "lockfile_committed": "yes",
        "docker_support": "yes",
        "docker_registry": "ghcr.io",
        "uses_bazel": "no",
        "arm_support": "yes",
        "reproducible_builds": "yes",
        "notes": "cargo-nextest; multiple build profiles; cargo-deny; most modern Rust CI",
    },
]

# ─── Validation ───────────────────────────────────────────────────────────────

VALID_CLIENT_TYPES = {"consensus", "execution"}
VALID_YES_NO = {"yes", "no", "partial"}
VALID_LANGUAGES = {"Rust", "Go", "Java", "TypeScript", "Nim", "C#"}

def validate_row(row: dict, line_num: int) -> list[str]:
    """Validate a CSV row. Returns list of error messages."""
    errors = []

    # Required fields
    for field in ["client", "client_type", "language", "ci_platform"]:
        if not row.get(field):
            errors.append(f"Line {line_num}: Missing required field '{field}'")

    # Enum validation
    if row.get("client_type") and row["client_type"] not in VALID_CLIENT_TYPES:
        errors.append(f"Line {line_num}: Invalid client_type '{row['client_type']}'")

    for field in ["lockfile_committed", "docker_support", "uses_bazel",
                  "arm_support", "reproducible_builds"]:
        val = row.get(field, "").lower()
        if val and val not in VALID_YES_NO:
            errors.append(f"Line {line_num}: Field '{field}' has invalid value '{val}'")

    return errors


def validate_csv(csv_path: Path) -> tuple[int, int]:
    """Validate an existing CSV file. Returns (valid_rows, error_count)."""
    valid_rows = 0
    total_errors = 0

    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        # Check all expected fields are present
        missing_fields = set(CSV_FIELDS) - set(reader.fieldnames or [])
        if missing_fields:
            print(f"WARNING: CSV missing fields: {sorted(missing_fields)}")

        for i, row in enumerate(reader, start=2):
            errors = validate_row(row, i)
            if errors:
                for error in errors:
                    print(f"  ERROR: {error}")
                total_errors += len(errors)
            else:
                valid_rows += 1

    return valid_rows, total_errors


# ─── Generation ───────────────────────────────────────────────────────────────

def generate_from_curated(output_path: Path) -> None:
    """Generate CSV from curated data."""
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in CURATED_DATA:
            writer.writerow(row)
    print(f"Generated: {output_path} ({len(CURATED_DATA)} rows)")


def generate_from_json(json_dir: Path, output_path: Path) -> None:
    """Generate CSV by merging raw JSON files with curated data."""
    json_files = list(json_dir.glob("*.json"))
    if not json_files:
        print(f"No JSON files found in {json_dir}", file=sys.stderr)
        sys.exit(1)

    # Index curated data by client name
    curated_by_client = {r["client"]: r for r in CURATED_DATA}

    # Merge JSON data into curated (JSON overrides curated for overlapping fields)
    merged = []
    for json_path in sorted(json_files):
        client_name = json_path.stem
        try:
            raw = json.loads(json_path.read_text())
        except (json.JSONDecodeError, OSError) as e:
            print(f"Warning: Could not read {json_path}: {e}", file=sys.stderr)
            continue

        base = curated_by_client.get(client_name, {"client": client_name})
        # Merge: prefer raw JSON values for overlapping keys
        merged_row = {**base}
        for field in ["language", "ci_platform", "workflow_count", "build_tool",
                       "package_manager", "lockfile", "docker_support", "docker_registry",
                       "uses_bazel"]:
            if field in raw and raw[field] not in (None, "unknown"):
                merged_row[field] = raw[field]

        # Ensure all CSV fields present
        for f in CSV_FIELDS:
            if f not in merged_row:
                merged_row[f] = ""

        merged.append(merged_row)

    # Add curated-only clients not found in JSON
    json_names = {p.stem for p in json_files}
    for client, row in curated_by_client.items():
        if client not in json_names:
            merged.append(row)

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        for row in sorted(merged, key=lambda x: (
            0 if x.get("client_type") == "consensus" else 1,
            x.get("client", "")
        )):
            writer.writerow(row)

    print(f"Generated: {output_path} ({len(merged)} rows, merged from {len(json_files)} JSON files)")


# ─── Entry point ──────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate or validate comparison_matrix.csv")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--from-curated",
        action="store_true",
        help="Generate CSV from curated/hardcoded data",
    )
    group.add_argument(
        "--from-json",
        type=Path,
        metavar="DIR",
        help="Generate CSV by merging raw JSON files from collect_metadata.sh",
    )
    group.add_argument(
        "--validate",
        type=Path,
        metavar="CSV",
        help="Validate an existing CSV file",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/comparison_matrix.csv"),
        help="Output CSV path (default: data/comparison_matrix.csv)",
    )
    args = parser.parse_args()

    if args.validate:
        if not args.validate.exists():
            print(f"ERROR: File not found: {args.validate}", file=sys.stderr)
            sys.exit(1)
        print(f"Validating: {args.validate}")
        valid, errors = validate_csv(args.validate)
        print(f"\nResult: {valid} valid rows, {errors} errors")
        sys.exit(0 if errors == 0 else 1)

    elif args.from_curated:
        generate_from_curated(args.output)

    elif args.from_json:
        if not args.from_json.exists():
            print(f"ERROR: Directory not found: {args.from_json}", file=sys.stderr)
            sys.exit(1)
        generate_from_json(args.from_json, args.output)


if __name__ == "__main__":
    main()
