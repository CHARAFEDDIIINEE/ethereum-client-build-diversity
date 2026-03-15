# Ethereum Client Build Pipeline Diversity Analysis

> **A comprehensive study of CI/CD pipelines, build tooling, and dependency management across 11 Ethereum clients**

[![Research Date](https://img.shields.io/badge/Research%20Date-March%202026-blue)](.)
[![Clients Analyzed](https://img.shields.io/badge/Clients%20Analyzed-11-green)](.)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## Overview

This repository contains a systematic analysis of the build pipeline diversity across **6 consensus clients** and **5 execution clients** in the Ethereum ecosystem. The study examines CI/CD infrastructure, build tooling, dependency management, Docker support, and workflow complexity to understand how much diversity (or similarity) exists in how these critical software systems are built and tested.

Client diversity at the _runtime_ level is well-documented ([clientdiversity.org](https://clientdiversity.org)), but **build pipeline diversity** is less often discussed. A shared vulnerability in a common build dependency or CI platform could affect multiple clients simultaneously — making this analysis relevant to Ethereum's resilience.

---

## Repository Structure

```
eth-client-build-diversity/
├── README.md                        # This file
├── data/
│   ├── comparison_matrix.csv        # Complete comparison matrix (all clients × all dimensions)
│   └── raw_findings.json            # Raw structured data per client
├── analysis/
│   ├── full_analysis.md             # Deep narrative analysis with findings
│   ├── key_insights.md              # Executive summary of key insights
│   └── risk_assessment.md           # Security & resilience risk analysis
├── scripts/
│   ├── collect_metadata.sh          # Bash script to collect repo metadata via GitHub API
│   ├── analyze_workflows.py         # Python script to parse and analyze workflow YAML files
│   ├── generate_csv.py              # Generate the comparison matrix CSV
│   └── methodology.md               # Detailed methodology documentation
└── docs/
    ├── client_profiles/             # Individual client deep-dives
    │   ├── lighthouse.md
    │   ├── prysm.md
    │   ├── teku.md
    │   ├── nimbus.md
    │   ├── lodestar.md
    │   ├── grandine.md
    │   ├── geth.md
    │   ├── nethermind.md
    │   ├── besu.md
    │   ├── erigon.md
    │   └── reth.md
    └── glossary.md
```

---

## Clients Analyzed

### Consensus Clients (CL)
| Client | Language | Organization | GitHub |
|--------|----------|--------------|--------|
| **Lighthouse** | Rust | Sigma Prime | [sigp/lighthouse](https://github.com/sigp/lighthouse) |
| **Prysm** | Go | Offchain Labs (Prysmatic Labs) | [prysmaticlabs/prysm](https://github.com/prysmaticlabs/prysm) |
| **Teku** | Java | Consensys | [Consensys/teku](https://github.com/Consensys/teku) |
| **Nimbus** | Nim | Status.im | [status-im/nimbus-eth2](https://github.com/status-im/nimbus-eth2) |
| **Lodestar** | TypeScript | ChainSafe Systems | [ChainSafe/lodestar](https://github.com/ChainSafe/lodestar) |
| **Grandine** | Rust | Grandine Core Team | [grandinetech/grandine](https://github.com/grandinetech/grandine) |

### Execution Clients (EL)
| Client | Language | Organization | GitHub |
|--------|----------|--------------|--------|
| **Geth** | Go | Ethereum Foundation | [ethereum/go-ethereum](https://github.com/ethereum/go-ethereum) |
| **Nethermind** | C# / .NET | Nethermind | [NethermindEth/nethermind](https://github.com/NethermindEth/nethermind) |
| **Besu** | Java | Hyperledger / Consensys | [hyperledger/besu](https://github.com/hyperledger/besu) |
| **Erigon** | Go | Erigon Tech | [erigontech/erigon](https://github.com/erigontech/erigon) |
| **Reth** | Rust | Paradigm | [paradigmxyz/reth](https://github.com/paradigmxyz/reth) |

---

## Quick Summary of Findings

### Programming Language Distribution
- **Rust**: Lighthouse, Grandine, Reth (3 clients — all different orgs)
- **Go**: Prysm, Geth, Erigon (3 clients)
- **Java**: Teku, Besu (2 clients — both Consensys-related)
- **TypeScript**: Lodestar (1 client)
- **Nim**: Nimbus (1 client)
- **C#/.NET**: Nethermind (1 client)

### CI/CD Platform
- **GitHub Actions only**: 9 of 11 clients
- **GitHub Actions + CircleCI**: Geth (historical)
- **Jenkins (historical)**: Nimbus used Jenkins alongside GitHub Actions before migrating

### Build Tools by Language Ecosystem
| Ecosystem | Tool | Clients |
|-----------|------|---------|
| Rust | `cargo` | Lighthouse, Grandine, Reth |
| Go | `make` + `go build` | Prysm, Geth, Erigon |
| Java | `Gradle` | Teku, Besu |
| TypeScript | `pnpm` (migrated from `yarn`) | Lodestar |
| C# | `dotnet` | Nethermind |
| Nim | Custom `make` + Nimble | Nimbus |

### Lockfiles
| Client | Lockfile | Type |
|--------|----------|------|
| Lighthouse | ✅ `Cargo.lock` | Rust |
| Grandine | ✅ `Cargo.lock` | Rust |
| Reth | ✅ `Cargo.lock` | Rust |
| Prysm | ✅ `go.sum` | Go |
| Geth | ✅ `go.sum` | Go |
| Erigon | ✅ `go.sum` | Go |
| Teku | ✅ `gradle.lockfile` | Gradle |
| Besu | ✅ `gradle.lockfile` | Gradle |
| Lodestar | ✅ `pnpm-lock.yaml` | pnpm |
| Nethermind | ⚠️ NuGet packages.lock.json | .NET |
| Nimbus | ❌ No pinned lockfile (git submodules) | Custom |

### Docker Support: All 11 Clients ✅

---

## Key Insights

1. **GitHub Actions monoculture**: 9/11 clients rely exclusively on GitHub Actions. A GitHub outage or supply chain compromise of a shared GitHub-hosted action would affect the majority of Ethereum client builds simultaneously.

2. **Java/Gradle duopoly in consensus+enterprise**: Both Teku and Besu share nearly identical build pipelines (Gradle, GitHub Actions, Java 21), creating homogeneity in two critical clients.

3. **Rust ecosystem convergence**: Lighthouse, Grandine, and Reth all use `cargo` with `Cargo.lock`. While this is good practice, it also means they share the Rust toolchain attack surface.

4. **Lodestar's unique supply chain approach**: Lodestar's migration from `yarn` to `pnpm` for security reasons (postinstall script blocking) shows active consideration of supply chain risks uncommon in other clients.

5. **Nimbus uniquely avoids lockfiles**: Nimbus uses git submodules rather than a package registry, giving it supply chain properties quite different from the other clients.

6. **Geth's custom CI orchestration**: Geth uses a custom `build/ci.go` script rather than raw Makefile or Gradle tasks, a unique approach that provides tight control over the build but increases maintenance burden.

7. **Prysm's Bazel dependency**: Prysm uses Bazel (Google's build system) in addition to standard Go tooling — unique among all 11 clients and reflecting its heritage at Prysmatic Labs/Google engineers.

---

## Methodology

See [`scripts/methodology.md`](scripts/methodology.md) for the complete methodology. In brief:

1. **Manual inspection** of each GitHub repository: README files, Dockerfiles, `.github/workflows/`, package management files.
2. **Automated scripting** using shell and Python to enumerate workflow files and extract build commands.
3. **Cross-referencing** with official documentation and release notes.
4. **Research date**: March 2026. Repository states reflect stable/main branches as of this period.

---

## How to Reproduce

```bash
# Clone the repo
git clone https://github.com/your-handle/eth-client-build-diversity
cd eth-client-build-diversity

# Install Python dependencies
pip install requests pyyaml

# Run the metadata collection script (requires GitHub token for higher rate limits)
export GITHUB_TOKEN=your_token_here
bash scripts/collect_metadata.sh

# Analyze workflows
python scripts/analyze_workflows.py

# Regenerate the CSV
python scripts/generate_csv.py
```

---


