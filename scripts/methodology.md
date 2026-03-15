# Methodology: How This Analysis Was Conducted

## Overview

This analysis combines **manual inspection** of each client's repository with **automated scripts** designed to systematically collect and verify the same information at scale. The goal is both accuracy (via manual review) and reproducibility (via automation).

---

## Phase 1: Repository Identification

Each client's primary source repository was identified:

| Client | Repository |
|--------|-----------|
| Lighthouse | `https://github.com/sigp/lighthouse` |
| Prysm | `https://github.com/prysmaticlabs/prysm` |
| Teku | `https://github.com/Consensys/teku` |
| Nimbus | `https://github.com/status-im/nimbus-eth2` |
| Lodestar | `https://github.com/ChainSafe/lodestar` |
| Grandine | `https://github.com/grandinetech/grandine` |
| Geth | `https://github.com/ethereum/go-ethereum` |
| Nethermind | `https://github.com/NethermindEth/nethermind` |
| Besu | `https://github.com/hyperledger/besu` |
| Erigon | `https://github.com/erigontech/erigon` |
| Reth | `https://github.com/paradigmxyz/reth` |

---

## Phase 2: CI/CD Platform Detection

### Manual Method
For each repository, the following were inspected:
- Presence of `.github/workflows/` directory → GitHub Actions
- Presence of `Jenkinsfile` or `jenkins/` directory → Jenkins
- Presence of `.travis.yml` → Travis CI
- Presence of `.circleci/config.yml` → CircleCI
- Presence of `.gitlab-ci.yml` → GitLab CI
- Presence of `azure-pipelines.yml` → Azure Pipelines

### Automated Method
`scripts/collect_metadata.sh` automates this via filesystem checks on cloned repos.

### Findings Basis
GitHub Actions presence was confirmed for 10/11 clients by finding `.github/workflows/` directories with `.yml` files. Nimbus's Jenkins history was identified via community documentation and historical `.github` references.

---

## Phase 3: Build Tool and Language Detection

### Manual Method
For each repository, the following files were checked:
- `Cargo.toml` / `Cargo.lock` → Rust + Cargo
- `go.mod` / `go.sum` → Go + Go Modules
- `build.gradle` / `gradle/wrapper/` → Java + Gradle
- `package.json` / `pnpm-lock.yaml` / `yarn.lock` → TypeScript/JS + npm ecosystem
- `*.nimble` / `Makefile` + Nim indicators → Nim
- `*.csproj` / `*.sln` / `global.json` → C# + .NET
- `WORKSPACE` / `WORKSPACE.bazel` → Bazel

### Automated Method
`scripts/collect_metadata.sh` implements `detect_language()`, `detect_build_tool()`, and `detect_package_manager()` functions that check for these indicator files.

---

## Phase 4: Lockfile Assessment

### Manual Method
For each repository:
1. **Presence check**: Does the lockfile exist in the root or expected location?
2. **Commit check**: Is it tracked by git (not in `.gitignore`)?
3. **Completeness check**: Does it cover all dependencies (workspace-wide vs. per-project)?

### Lockfile Type Reference

| Language | Standard Lockfile | Verification Mechanism |
|----------|------------------|----------------------|
| Rust | `Cargo.lock` | SHA-256 hashes per crate |
| Go | `go.sum` | SHA-256 hashes per module version |
| Java/Gradle | `gradle.lockfile` | Exact resolved versions + checksums |
| TypeScript | `pnpm-lock.yaml` | Integrity hashes per package |
| C# | `packages.lock.json` | Resolved versions + SHA-512 hashes |
| Nim | N/A (git submodule SHAs) | Git commit hash pinning |

### Automated Method
`scripts/collect_metadata.sh` implements `detect_lockfile()` which checks for the presence of each known lockfile type.

---

## Phase 5: Workflow Complexity Analysis

### Manual Method
For each client:
1. Listed all `.yml`/`.yaml` files in `.github/workflows/`
2. Read each workflow to understand: triggers, jobs, strategy matrices, dependencies between jobs
3. Noted unique patterns (e.g., Kurtosis in Erigon, native lib builds in Nethermind)

### Automated Method
`scripts/analyze_workflows.py` implements:
- `count_jobs()` — counts jobs per workflow
- `extract_triggers()` — identifies event triggers
- `extract_matrix_axes()` — finds build matrix dimensions
- `estimate_complexity()` — scores complexity via heuristic formula
- `extract_actions_used()` — lists all third-party actions referenced
- `extract_run_commands()` — extracts shell commands run during CI

**Complexity scoring heuristic:**
```
score = (job_count × 2) + total_steps + (5 if uses_matrix) + (3 if uses_needs)
```

This is a relative measure for comparison, not an absolute metric.

---

## Phase 6: Docker Analysis

### Manual Method
For each repository:
1. Searched for `Dockerfile*` files (single or multi-stage)
2. Reviewed workflow files for `docker push` or `docker/build-push-action` usage
3. Identified registry by inspecting image tags in CI configs or README

### Automated Method
`scripts/collect_metadata.sh` implements `detect_docker()` and `detect_docker_registry()` using filesystem and grep-based checks.

---

## Phase 7: Cross-Client Analysis

After collecting per-client data, the following cross-cutting analyses were performed:

1. **Cluster analysis** — Grouping clients by language, build tool, CI platform
2. **Risk identification** — Finding shared dependencies and organizational overlaps
3. **Diversity scoring** — Shannon entropy-based scoring per dimension
4. **Outlier identification** — Finding clients that differ significantly from the norm

### Diversity Score Methodology

For a given dimension (e.g., CI platform), Shannon entropy is computed:

```
H = -Σ p(x) × log₂(p(x))
```

Where `p(x)` is the fraction of clients using option `x`. This is then normalized to [0, 1] by dividing by `log₂(N)` where N is the number of clients.

**Example — CI Platform:**
- GitHub Actions: 10/11 clients (p = 0.909)
- Jenkins/Other: 1/11 clients (p = 0.091)
- H = -(0.909 × log₂(0.909) + 0.091 × log₂(0.091)) ≈ 0.44
- Normalized: 0.44 / log₂(11) ≈ 0.13 (very low diversity)

**Example — Programming Language:**
- Rust: 3/11, Go: 3/11, Java: 2/11, TypeScript: 1/11, Nim: 1/11, C#: 1/11
- H ≈ 2.47
- Normalized: 2.47 / log₂(11) ≈ 0.71 (good diversity)

---

## Limitations and Caveats

1. **Snapshot in time**: CI configurations change frequently. This analysis reflects a point-in-time snapshot. The automated scripts can re-run analysis on current repository state.

2. **Shallow clones**: The `collect_metadata.sh` script uses `git clone --depth=1` for speed. This means historical CI configurations are not analyzed.

3. **Workflow interpretation**: Some workflow files have complex templating or use reusable workflows. The automated parser may miss nested complexity.

4. **Private CI**: Some clients may have internal CI pipelines not visible in public repositories. Jenkins at Status/Nimbus is known; others may exist.

5. **Self-hosted runners**: Workflow files don't always reveal whether jobs run on GitHub-hosted or self-hosted runners. Self-hosted runners would reduce GitHub dependence.

6. **Workflow count as complexity proxy**: More workflows ≠ more complex. A single complex workflow could indicate more complexity than 20 simple ones. The `analyze_workflows.py` script attempts a per-workflow complexity score as a better proxy.

7. **Manual vs. automated discrepancy**: Where manual inspection and automated detection disagree, manual inspection is considered authoritative (automated detection may miss context).

---

## Reproducing This Analysis

```bash
# 1. Clone this repository
git clone https://github.com/YOUR_USERNAME/eth-client-build-diversity.git
cd eth-client-build-diversity

# 2. Install dependencies
pip install pyyaml rich   # Python deps for analyze_workflows.py
# Ensure: git, jq, curl are installed

# 3. Collect metadata (clones all 11 repos, ~500MB)
bash scripts/collect_metadata.sh

# 4. Analyze workflows
python scripts/analyze_workflows.py \
  --clone-dir /tmp/eth-clients \
  --format markdown \
  --output analysis/workflow_analysis_generated.md

# 5. Regenerate CSV
python scripts/generate_csv.py --from-curated --output data/comparison_matrix_regenerated.csv

# 6. Validate CSV
python scripts/generate_csv.py --validate data/comparison_matrix.csv
```

---

## Data Currency

| Item | Last Verified |
|------|--------------|
| Repository URLs | 2025 |
| CI platform detection | 2025 |
| Workflow counts | Approximate (±2-3); use scripts for exact current counts |
| Lockfile presence | 2025 |
| Docker registry | 2025 |

To get current data, run `scripts/collect_metadata.sh` against the live repositories.
