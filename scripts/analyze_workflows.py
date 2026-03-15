#!/usr/bin/env python3
"""
analyze_workflows.py
Analyzes GitHub Actions workflow files across Ethereum clients to extract
CI/CD patterns, complexity metrics, and commonalities.

Usage:
    python scripts/analyze_workflows.py --clone-dir /tmp/eth-clients
    python scripts/analyze_workflows.py --clone-dir /tmp/eth-clients --client lighthouse
    python scripts/analyze_workflows.py --help

Requires: PyYAML, rich (optional, for pretty output)
    pip install pyyaml rich
"""

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any
from unittest import result

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

try:
    from rich.console import Console
    from rich.table import Table
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False

# ─── Configuration ────────────────────────────────────────────────────────────

CLIENTS = {
    "lighthouse": "sigp/lighthouse",
    "prysm": "prysmaticlabs/prysm",
    "teku": "Consensys/teku",
    "nimbus": "status-im/nimbus-eth2",
    "lodestar": "ChainSafe/lodestar",
    "grandine": "grandinetech/grandine",
    "geth": "ethereum/go-ethereum",
    "nethermind": "NethermindEth/nethermind",
    "besu": "hyperledger/besu",
    "erigon": "erigontech/erigon",
    "reth": "paradigmxyz/reth",
}

# Known action prefixes to categorize
ACTION_CATEGORIES = {
    "actions/checkout": "repo-checkout",
    "actions/setup-": "language-setup",
    "docker/": "docker",
    "actions/cache": "caching",
    "actions/upload-artifact": "artifacts",
    "actions/download-artifact": "artifacts",
    "github/codeql-action": "security",
    "sigstore/": "signing",
    "bazel": "bazel",
    "cross-platform-actions": "cross-compile",
}

# ─── Core analysis functions ──────────────────────────────────────────────────

def load_workflow(path: Path) -> dict | None:
    """Load and parse a YAML workflow file. Returns None on error."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except (yaml.YAMLError, OSError) as e:
        print(f"  Warning: Could not parse {path.name}: {e}", file=sys.stderr)
        return None


def extract_actions_used(workflow: dict) -> list[str]:
    """Extract all 'uses:' action references from a workflow."""
    actions = []

    def recurse(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if k == "uses" and isinstance(v, str):
                    actions.append(v)
                else:
                    recurse(v)
        elif isinstance(obj, list):
            for item in obj:
                recurse(item)

    recurse(workflow)
    return actions


def extract_run_commands(workflow: dict) -> list[str]:
    """Extract all 'run:' shell commands from a workflow."""
    commands = []

    def recurse(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if k == "run" and isinstance(v, str):
                    commands.append(v.strip())
                else:
                    recurse(v)
        elif isinstance(obj, list):
            for item in obj:
                recurse(item)

    recurse(workflow)
    return commands


def extract_triggers(workflow: dict) -> list[str]:
    """Extract workflow trigger events (on: ...)."""
    on = workflow.get("on", {})
    if isinstance(on, dict):
        return list(on.keys())
    elif isinstance(on, list):
        return on
    elif isinstance(on, str):
        return [on]
    return []


def extract_matrix_axes(workflow: dict) -> dict[str, list]:
    """Extract build matrix dimensions from a workflow."""
    matrices = {}

    def recurse(obj, path=""):
        if isinstance(obj, dict):
            if "matrix" in obj and isinstance(obj["matrix"], dict):
                for k, v in obj["matrix"].items():
                    if k != "include" and k != "exclude" and isinstance(v, list):
                        matrices[k] = v
            for k, v in obj.items():
                recurse(v, f"{path}.{k}")
        elif isinstance(obj, list):
            for item in obj:
                recurse(item, path)

    recurse(workflow)
    return matrices


def count_jobs(workflow: dict) -> int:
    """Count the number of jobs in a workflow."""
    jobs = workflow.get("jobs", {})
    return len(jobs) if isinstance(jobs, dict) else 0


def estimate_complexity(workflow: dict, workflow_name: str) -> dict[str, Any]:
    """Estimate a workflow's complexity based on various heuristics."""
    jobs = workflow.get("jobs", {})
    job_count = len(jobs) if isinstance(jobs, dict) else 0

    # Count steps across all jobs
    total_steps = 0
    uses_strategy = False
    uses_needs = False

    if isinstance(jobs, dict):
        for job in jobs.values():
            if isinstance(job, dict):
                steps = job.get("steps", [])
                total_steps += len(steps) if isinstance(steps, list) else 0
                if "strategy" in job:
                    uses_strategy = True
                if "needs" in job:
                    uses_needs = True

    # Complexity score: rough heuristic
    score = job_count * 2 + total_steps + (5 if uses_strategy else 0) + (3 if uses_needs else 0)

    return {
        "workflow": workflow_name,
        "job_count": job_count,
        "total_steps": total_steps,
        "uses_matrix_strategy": uses_strategy,
        "uses_job_dependencies": uses_needs,
        "complexity_score": score,
    }


def analyze_client(clone_dir: Path, client_name: str) -> dict[str, Any]:
    """Run full analysis on a single client."""
    repo_dir = clone_dir / client_name
    wf_dir = repo_dir / ".github" / "workflows"

    result = {
        "client": client_name,
        "repo": CLIENTS.get(client_name, "unknown"),
        "workflows": [],
        "workflow_count": 0,
        "total_jobs": 0,
        "all_actions": [],
        "action_categories": Counter(),
        "triggers": Counter(),
        "matrix_axes": defaultdict(set),
        "build_commands_detected": [],
        "total_complexity_score": 0,
        "errors": [],
    }

    if not wf_dir.exists():
        result["errors"].append(f"No .github/workflows directory found at {wf_dir}")
        return result

    workflow_files = list(wf_dir.glob("*.yml")) + list(wf_dir.glob("*.yaml"))
    result["workflow_count"] = len(workflow_files)

    for wf_path in sorted(workflow_files):
        wf = load_workflow(wf_path)
        if wf is None:
            result["errors"].append(f"Failed to parse: {wf_path.name}")
            continue

        actions = extract_actions_used(wf)
        commands = extract_run_commands(wf)
        triggers = extract_triggers(wf)
        matrices = extract_matrix_axes(wf)
        complexity = estimate_complexity(wf, wf_path.name)

        result["workflows"].append({
            "file": wf_path.name,
            "triggers": triggers,
            "complexity": complexity,
            "actions_count": len(actions),
        })

        result["total_jobs"] += complexity["job_count"]
        result["total_complexity_score"] += complexity["complexity_score"]
        result["all_actions"].extend(actions)

        # Initialize matrix_axes as defaultdict(list) instead of defaultdict(set)
        result["matrix_axes"] = defaultdict(list)

        # ... later when processing matrices ...

        for axis, values in matrices.items():
            if isinstance(values, list):
                for v in values:
                    if v not in result["matrix_axes"][axis]:  # avoid duplicates
                         result["matrix_axes"][axis].append(v)
            else:
            # Handle non-list values (shouldn't happen, but just in case)
                if values not in result["matrix_axes"][axis]:
                    result["matrix_axes"][axis].append(values)

       # for trigger in triggers:
       #     result["triggers"][trigger] += 1

        #for axis, values in matrices.items():
         #   result["matrix_axes"][axis].update(values)

        # Detect build-related commands
        for cmd in commands:
            first_line = cmd.split("\n")[0].strip()
            for keyword in ["cargo build", "go build", "./gradlew", "dotnet build",
                           "make ", "pnpm run", "npm run", "bazelisk build",
                           "cross build", "docker build", "docker buildx"]:
                if keyword in first_line and first_line not in result["build_commands_detected"]:
                    result["build_commands_detected"].append(first_line)

    # Categorize actions
    for action in result["all_actions"]:
        categorized = False
        for prefix, category in ACTION_CATEGORIES.items():
            if action.startswith(prefix):
                result["action_categories"][category] += 1
                categorized = True
                break
        if not categorized:
            # Track unique/uncategorized actions
            action_name = action.split("@")[0]
            result["action_categories"][f"other:{action_name}"] += 1

    # Convert defaultdict/Counter to regular dict for JSON serialization
    result["action_categories"] = dict(result["action_categories"])
    result["triggers"] = dict(result["triggers"])
    result["matrix_axes"] = {k: sorted(v) for k, v in result["matrix_axes"].items()}
    # Deduplicate actions list
    result["unique_actions"] = sorted(set(result["all_actions"]))
    del result["all_actions"]  # Too verbose for output

    return result


def generate_comparison_table(results: list[dict]) -> str:
    """Generate a Markdown comparison table from analysis results."""
    lines = [
        "# Workflow Complexity Comparison",
        "",
        "| Client | Workflows | Total Jobs | Complexity Score | Matrix Axes | Top Trigger |",
        "|--------|-----------|------------|-----------------|-------------|-------------|",
    ]

    for r in sorted(results, key=lambda x: x["total_complexity_score"], reverse=True):
        top_trigger = max(r["triggers"], key=r["triggers"].get) if r["triggers"] else "—"
        matrix_axes = ", ".join(r["matrix_axes"].keys()) if r["matrix_axes"] else "none"
        lines.append(
            f"| {r['client']} | {r['workflow_count']} | {r['total_jobs']} | "
            f"{r['total_complexity_score']} | {matrix_axes} | {top_trigger} |"
        )

    return "\n".join(lines)


def find_common_actions(results: list[dict]) -> dict[str, list[str]]:
    """Find GitHub Actions used by multiple clients."""
    action_clients = defaultdict(list)

    for r in results:
        for action in r.get("unique_actions", []):
            action_name = action.split("@")[0]
            if r["client"] not in action_clients[action_name]:
                action_clients[action_name].append(r["client"])

    # Return only actions used by 3+ clients
    return {
        action: clients
        for action, clients in sorted(action_clients.items())
        if len(clients) >= 3
    }

# ─── Output formatters ────────────────────────────────────────────────────────

def print_rich_summary(results: list[dict]) -> None:
    """Print a rich formatted summary table."""
    console = Console()
    table = Table(title="Ethereum Client Workflow Analysis", show_lines=True)

    table.add_column("Client", style="cyan")
    table.add_column("Workflows", justify="right")
    table.add_column("Jobs", justify="right")
    table.add_column("Complexity", justify="right")
    table.add_column("Triggers")
    table.add_column("Notable")

    for r in sorted(results, key=lambda x: x["total_complexity_score"], reverse=True):
        triggers = ", ".join(sorted(r["triggers"].keys())[:3])
        notable = []
        if any("bazel" in a for a in r.get("unique_actions", [])):
            notable.append("bazel")
        if r["matrix_axes"]:
            notable.append(f"matrix:{','.join(list(r['matrix_axes'].keys())[:2])}")

        table.add_row(
            r["client"],
            str(r["workflow_count"]),
            str(r["total_jobs"]),
            str(r["total_complexity_score"]),
            triggers,
            " | ".join(notable) or "—",
        )

    console.print(table)


def print_plain_summary(results: list[dict]) -> None:
    """Print a plain text summary."""
    print(f"\n{'='*70}")
    print("ETHEREUM CLIENT WORKFLOW ANALYSIS SUMMARY")
    print(f"{'='*70}\n")

    for r in sorted(results, key=lambda x: x["total_complexity_score"], reverse=True):
        print(f"  {r['client']:<15} | workflows: {r['workflow_count']:>3} | "
              f"jobs: {r['total_jobs']:>4} | complexity: {r['total_complexity_score']:>5}")

    print()

# ─── Entry point ──────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Analyze GitHub Actions workflows across Ethereum clients"
    )
    parser.add_argument(
        "--clone-dir",
        type=Path,
        default=Path("/tmp/eth-clients"),
        help="Directory containing cloned client repositories",
    )
    parser.add_argument(
        "--client",
        choices=list(CLIENTS.keys()),
        help="Analyze only this client (default: all)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Write JSON output to this file",
    )
    parser.add_argument(
        "--format",
        choices=["summary", "json", "markdown"],
        default="summary",
        help="Output format",
    )
    args = parser.parse_args()

    # Determine clients to analyze
    clients_to_analyze = [args.client] if args.client else list(CLIENTS.keys())

    results = []
    for client in clients_to_analyze:
        client_dir = args.clone_dir / client
        if not client_dir.exists():
            print(f"Warning: {client_dir} not found — skipping {client}", file=sys.stderr)
            print(f"  Run: git clone --depth=1 {CLIENTS[client]} {client_dir}", file=sys.stderr)
            continue
        print(f"Analyzing {client}...", file=sys.stderr)
        result = analyze_client(args.clone_dir, client)
        results.append(result)

    if not results:
        print("No results — check that repositories are cloned to --clone-dir", file=sys.stderr)
        sys.exit(1)

    # Output
    if args.format == "json":
        output = json.dumps(results, indent=2, default=str)
        if args.output:
            args.output.write_text(output)
            print(f"JSON written to: {args.output}", file=sys.stderr)
        else:
            print(output)

    elif args.format == "markdown":
        md = generate_comparison_table(results)
        md += "\n\n## Common Actions (used by 3+ clients)\n\n"
        common = find_common_actions(results)
        for action, clients in sorted(common.items(), key=lambda x: -len(x[1])):
            md += f"- `{action}` — used by: {', '.join(sorted(clients))}\n"

        if args.output:
            args.output.write_text(md)
            print(f"Markdown written to: {args.output}", file=sys.stderr)
        else:
            print(md)

    else:  # summary
        if RICH_AVAILABLE:
            print_rich_summary(results)
        else:
            print_plain_summary(results)

        common = find_common_actions(results)
        print(f"\nTop shared GitHub Actions (3+ clients):")
        for action, clients in sorted(common.items(), key=lambda x: -len(x[1]))[:10]:
            print(f"  {len(clients):>2}x  {action}")
            print(f"        → {', '.join(sorted(clients))}")

        if args.output:
            args.output.write_text(json.dumps(results, indent=2, default=str))
            print(f"\nFull JSON saved to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
