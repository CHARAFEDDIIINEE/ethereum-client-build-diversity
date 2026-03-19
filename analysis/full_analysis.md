# Full Analysis: Ethereum Client Build Pipeline Diversity

## Research Methodology

This analysis was conducted in March 2026 through a combination of:
- **Manual inspection** of each client's GitHub repository (README, Dockerfiles, .github/workflows/, build config files)
- **Automated scripting** to count and classify workflow files
- **Cross-referencing** with official documentation, release notes, and developer blog posts
- All findings reflect stable/main branches as of March 2026

---

## 1. CI/CD Platform Analysis

### GitHub Actions Monoculture

Of the 11 clients studied, **10 use GitHub Actions as their primary (and often only) CI/CD platform**. The remaining client (Nimbus) has historically used Jenkins but has also migrated primarily to GitHub Actions.

**Why this matters:**
- A GitHub Actions outage would halt CI for the vast majority of Ethereum clients simultaneously
- Supply chain attacks targeting popular GitHub Actions (e.g., `actions/checkout`, `actions/setup-node`) could affect multiple clients
- In March 2025, a major supply chain attack on `tj-actions/changed-files` demonstrated this risk

**Workflow count ranges:**

| Client | Approx. Workflows | 
|--------|-------------------|
| **Erigon** | 39 |
| **Nethermind** | 34 |
| **Reth** | 28 |
| **Lodestar** | 20 |
| **Besu** | 16 |
| **Teku** | 10 | 
| **Lighthouse** | 8 | 
| **Prysm** | 7 | 
| **Nimbus** | 5 | 
| **Grandine** | 3 | 
| **Geth** | 2 | 

**Outlier: Erigon** — With 39 separate GitHub Actions workflow files, Erigon has the most complex CI infrastructure among all clients. Its CI includes Kurtosis multi-client testnet integration, Assertoor scenario testing, extensive QA workflows, and docker-compose stacks for local development.

**Nethermind** follows closely with 34 workflows, featuring separate pipelines for native library builds (BLS, GMP, MCL, RocksDB, Secp256k1), Hive tests, PPA publishing, DAppNode packages, and Discord announcements.

---

## 2. Build Tool Analysis

### Ecosystem-Aligned Build Tools

Build tools are tightly coupled to programming language choice:

**Rust clients (Lighthouse, Grandine, Reth):**
- All use `cargo` — the Rust package manager and build tool
- `Cargo.lock` is committed in all three (correct practice for binary applications)
- Reth and Lighthouse both use a `Makefile` to wrap common cargo invocations
- Grandine uses a custom `compact` build profile for smaller binaries

**Go clients (Prysm, Geth, Erigon):**
- All use `go modules` and `go.sum` for dependency management
- `make` via Makefiles is the human-facing build interface for Geth and Erigon
- **Geth is unique**: it uses a custom `build/ci.go` Go script as the CI orchestration layer rather than relying on shell scripts or Makefile recipes alone. This script handles cross-compilation, Docker image building, Azure upload, and binary signing — all in Go code.
- **Prysm is unique**: it uses **Bazel** (Google's build system) as a first-class build path alongside standard `go build`. Bazel enables hermetic, reproducible builds and is likely a legacy from the team's Google engineering background. No other Ethereum client uses Bazel.

**Java clients (Teku, Besu):**
- Both use **Gradle** with a `build.gradle` file at the root
- Both use `./gradlew build` as the primary build command
- Both include Gradle Wrapper validation in CI
- Both require **Java 21** at build time
- Gradle Gradle Wrapper (`.gradle/wrapper/gradle-wrapper.properties`) pins the Gradle version — an important reproducibility mechanism

**TypeScript (Lodestar):**
- Recently migrated from `yarn` to **pnpm** as of 2025
- The migration was security-motivated: pnpm's architecture blocks postinstall scripts by default, eliminating a major NPM supply chain attack vector
- Uses a monorepo structure with multiple packages under `/packages/`
- `yarn.lock` has been replaced by `pnpm-lock.yaml`

**C#/.NET (Nethermind):**
- Uses `dotnet` CLI with `.slnx` (new .NET solution format) and NuGet
- Provides reproducible build documentation via `SOURCE_DATE_EPOCH` and `COMMIT_HASH` build args
- Requires .NET SDK 10 (latest at time of research)

**Nim (Nimbus):**
- Uses a **custom build system** (`nimbus-build-system`) based on GNU Make and Nimble
- Dependencies are managed via **git submodules** rather than a package registry — a fundamentally different approach than all other clients
- `make -j4 nimbus_beacon_node` is the primary build command
- The absence of a package registry lockfile means supply chain trust is managed at the git layer

---

## 3. Lockfile Analysis

### Lockfile Presence and Types

| Client | Lockfile | Notes |
|--------|----------|-------|
| Lighthouse | `Cargo.lock` ✅ | Committed; pins all transitive dependencies |
| Grandine | `Cargo.lock` ✅ | Committed; pins all transitive dependencies |
| Reth | `Cargo.lock` ✅ | Committed; pins all transitive dependencies |
| Prysm | `go.sum` ✅ | Committed; cryptographic hashes of all dependencies |
| Geth | `go.sum` ✅ | Committed; cryptographic hashes of all dependencies |
| Erigon | `go.sum` ✅ | Committed; cryptographic hashes of all dependencies |
| Teku | `gradle.lockfile` ✅ | Per-configuration locking |
| Besu | `gradle.lockfile` ✅ | Per-configuration locking |
| Lodestar | `pnpm-lock.yaml` ✅ | Committed; includes SHA-512 integrity hashes |
| Nethermind | `packages.lock.json` ⚠️ | Per-project NuGet locks; coverage varies |
| Nimbus | N/A ❌ | Git submodules; no package registry lockfile |

**Security note on Nimbus:** While not having a registry lockfile might seem like a gap, git submodules pin to specific commit SHAs, which is cryptographically strong. However, it makes dependency updates more manual and harder to audit via automated tools.

**Note on `go.sum`:** Go's `go.sum` is stronger than traditional lockfiles in some ways — it stores SHA-256 hashes of module zip files and `go.mod` files, providing tamper detection. The Go checksum database (sum.golang.org) provides additional transparency.

**Note on `Cargo.lock`:** Rust's Cargo.lock stores all transitive dependency versions and checksums. For binary crates (which all these clients are), committing Cargo.lock is explicitly recommended by the Rust team.

---

## 4. Docker Support Analysis

All 11 clients provide Docker support, but the implementation varies significantly:

### Approaches to Dockerization

**Multi-stage builds (best practice):**
- Geth, Nethermind, Reth, Lighthouse all use multi-stage Dockerfiles
- Builder stage compiles the binary; runtime stage is a minimal Alpine/Debian image
- Reduces final image size and attack surface

**Architecture-specific Dockerfiles (Nimbus):**
- Nimbus maintains separate Dockerfiles per architecture: `Dockerfile.bn.amd64`, `Dockerfile.bn.arm64`, `Dockerfile.bn.arm`
- This pre-BUILDPLATFORM approach is less common today but gives fine-grained control

**Gradle-integrated Docker builds (Teku, Besu):**
- Both use `./gradlew docker` to build Docker images, invoking the Docker CLI from within Gradle tasks
- The Docker build parameters (BUILD_DATE, VERSION, VCS_REF) are injected via build args

**docker-compose for local testing:**
- Erigon provides the richest `docker-compose.yml`, starting Erigon + RPCDaemon + Prometheus + Grafana as a full stack
- Nimbus and several others provide docker-compose for development environments

**Registries used:**
| Client | Registry |
|--------|----------|
| Lighthouse | ghcr.io (GitHub Container Registry) |
| Prysm | gcr.io (Google Container Registry) |
| Teku | Docker Hub (consensys/teku) |
| Nimbus | Docker Hub (statusim/nimbus-eth2) |
| Lodestar | Docker Hub (chainsafe/lodestar) |
| Grandine | ghcr.io |
| Geth | Docker Hub (ethereum/client-go) |
| Nethermind | Docker Hub (nethermind/nethermind) |
| Besu | Docker Hub (hyperledger/besu) |
| Erigon | Docker Hub (erigontech/erigon) |
| Reth | ghcr.io (paradigmxyz/reth) |

**Observation:** There is no standardization on Docker registry — clients use Docker Hub, GCR, and GHCR. This is actually good from a diversity standpoint, as a single registry outage won't affect all clients.

---

## 5. Individual Client Deep-Dives

### Lighthouse (Consensus, Rust)
- **CI complexity**: High. Lighthouse has one of the more complex CI setups among Rust clients.
- **Key workflows**: test-suite, local-testnet, release (with PGP signing), lint, nightly builds against multiple Rust versions
- **Standout features**: 
  - Cross-compilation for multiple targets (Linux x86_64/ARM, macOS x86_64/ARM, Windows x86_64)
  - Local testnet simulation runs in CI
  - PGP-signed release binaries
  - Sigstore/Signum code signing via Sigma Prime's key
- **Build command**: `cargo build --release`
- **Notable**: The Ethereum Foundation funded Sigma Prime specifically to build a Rust client for diversity reasons — diversity was literally the goal from day one

### Prysm (Consensus, Go)
- **CI complexity**: Very High. Most complex CI among Go clients.
- **Key workflows**: Multiple test suites (unit, integration, E2E), Bazel build CI, CodeQL, release pipeline
- **Standout features**: 
  - Bazel build system — enables fully hermetic, reproducible builds
  - `go.sum` + Bazel's hermetic dependency management provides dual-layer supply chain security
  - Custom `.bazelrc` and `WORKSPACE` files
  - `go_repository` rules for Go dependencies in Bazel
- **Build commands**: `bazel build //beacon-chain:beacon-chain` or `go build ./cmd/beacon-chain`
- **Notable**: Only client using Bazel — significantly different build reproducibility properties

### Teku (Consensus, Java)
- **CI complexity**: High.
- **Key workflows**: CI (main build), CodeQL, CLA Assistant, Validate Gradle Wrapper, Check Spec References
- **Standout features**: 
  - `Check Spec References` workflow unique to Teku — validates that code references match Ethereum consensus spec
  - Gradle Wrapper validation prevents compromise of the build wrapper
  - JDK variant matrix builds in Docker (multiple JDK versions tested)
- **Build commands**: `./gradlew build`
- **Notable**: ConsenSys team maintains both Teku and Besu, resulting in similar Gradle-based pipelines — a consolidation risk if ConsenSys has organizational issues

### Nimbus (Consensus, Nim)
- **CI complexity**: High, but fewer workflow files than most.
- **Key workflows**: CI (single comprehensive workflow), release
- **Standout features**: 
  - Git submodule-based dependency management (no package registry)
  - Custom nimbus-build-system maintained by Status.im
  - ARM builds supported (Raspberry Pi focus)
  - Historical use of Jenkins before GitHub Actions migration
- **Build commands**: `make -j4 nimbus_beacon_node`
- **Notable**: Most different dependency management approach — git submodules vs. package registries

### Lodestar (Consensus, TypeScript)
- **CI complexity**: Medium.
- **Key workflows**: CI, release, Docker publish, security/lint
- **Standout features**: 
  - pnpm adoption for supply chain security (postinstall script blocking)
  - Monorepo with ~15+ packages under /packages/
  - Vitest for testing (modern, faster alternative to Jest)
  - Explicit consideration of NPM supply chain attacks in architecture decisions
- **Build commands**: `pnpm install && pnpm run build`
- **Notable**: Only JavaScript/TypeScript consensus client; unique supply chain risk profile; transitioning to Zig for performance

### Grandine (Consensus, Rust)
- **CI complexity**: Medium-Low.
- **Key workflows**: CI, release, Docker
- **Standout features**: 
  - Custom `compact` build profile (size-optimized vs. `release`)
  - GPL-3.0 license (vs. Apache-2.0 for Lighthouse and Reth)
  - Git submodules for `eth2_libp2p` and `dedicated_executor` (borrows from Lighthouse/Reth ecosystems)
  - Smallest team/fewest workflows of all clients
- **Build commands**: `cargo build --profile compact --features default-networks --workspace`
- **Notable**: Most recently open-sourced (2024); smallest organizational footprint

### Geth (Execution, Go)
- **CI complexity**: High.
- **Key workflows**: CI, Docker publish, CodeQL, coverage
- **Standout features**: 
  - `build/ci.go` — custom Go-based CI orchestration script (unique to Geth)
  - Azure Blobstore for release binary storage
  - Signify signing (not just PGP)
  - Cross-compilation to many targets handled entirely within the Go CI script
- **Build commands**: `make geth` or `go run build/ci.go install ./cmd/geth`
- **Notable**: Most established client (since 2015); ci.go has accumulated considerable complexity over years; uses Azure for artifact storage while most others use GitHub Releases

### Nethermind (Execution, C#/.NET)
- **CI complexity**: Very High (most complex of all clients).
- **Key workflows**: 20+ distinct workflows including: Build Solution, Standard Build, TEST-RELEASE, Homebrew Update, BLS/GMP/MCL/RocksDB/Secp256k1 native library builds, Docker publish, Hive tests, Nethtest images, CodeQL, Consensus Legacy Tests, Hive Tests, Nethermind/Ethereum Tests, POSDAO Tests, Truffle Smoke Tests, Vault Integration Tests, PPA publication, DAppNode updates, GitBook Docs, POA Bootnodes, Discord announcements
- **Standout features**: 
  - Reproducible build documentation (SOURCE_DATE_EPOCH, COMMIT_HASH)
  - Most extensive integration test suite (Hive, Truffle, POSDAO, Vault)
  - Multiple native library build workflows (C/C++ bindings built separately)
  - Chiseled Docker images (Ubuntu chiseled — minimal attack surface)
- **Build commands**: `dotnet run -c release -- -c mainnet`
- **Notable**: C#/.NET is unique execution client language; most workflow diversity; NuGet dependency management

### Besu (Execution, Java)
- **CI complexity**: High.
- **Key workflows**: build, checks, CI, CodeQL, docker, spotless, dco, Repolinter, Validate Gradle Wrapper
- **Standout features**: 
  - Spotless enforces code formatting as a required CI check
  - DCO (Developer Certificate of Origin) validation workflow
  - Repolinter for repository health checking
  - Hyperledger Foundation governance requirements shape the CI pipeline
- **Build commands**: `./gradlew build`
- **Notable**: Governed by Hyperledger Foundation (Linux Foundation project) rather than a private company; most governance-heavy CI pipeline

### Erigon (Execution, Go)
- **CI complexity**: High.
- **Key workflows**: All tests, Integration tests, QA workflows (sync from scratch, sync with external CL, RPC performance, clean exit), Kurtosis Assertoor, docker CI/CD
- **Standout features**: 
  - QA-specific workflows: full node sync tests run in CI (rare — most clients only unit test)
  - Kurtosis Assertoor integration for network-level testing
  - goreleaser for release artifact management
  - docker-compose.yml provides multi-service local stack (Erigon + RPCDaemon + Prometheus + Grafana)
- **Build commands**: `make erigon`
- **Notable**: Most extensive QA testing in CI of any Go client; docker-compose for local development; silkworm integration for x86_64 builds

### Reth (Execution, Rust)
- **CI complexity**: High.
- **Key workflows**: CI, release, Docker (multi-arch), lint, docs, benchmarks
- **Standout features**: 
  - `cargo-nextest` for parallel testing (faster than `cargo test`)
  - Multiple build profiles documented: `release`, `maxperf`, `reproducible`
  - `cross` for cross-compilation to ARM targets
  - Makefile wraps complex cargo invocations with sensible defaults
  - jemalloc and asm-keccak feature flags for performance
  - Reproducible builds documented and achievable
- **Build commands**: `cargo build --release` or `make maxperf`
- **Notable**: Newest client (GA: June 2024) with most modern CI practices; best documentation of performance-oriented build profiles

---

## 6. Cross-Cutting Similarities

### What All 11 Share
1. **GitHub-hosted (or GitHub-adjacent) CI**: All use GitHub Actions or have recently migrated to it
2. **Docker support**: All provide official Docker images
3. **Lockfile presence**: All have some form of dependency pinning (though quality varies)
4. **Multi-platform builds**: All target at least Linux x86_64 and ARM64
5. **Release automation**: All have automated release workflows with binary artifact generation
6. **Security scanning**: 9/11 use GitHub's CodeQL or equivalent security scanning

### Cluster 1: Rust Clients (Lighthouse, Grandine, Reth)
- Cargo + Cargo.lock
- GitHub Actions
- GHCR for Docker
- Multi-stage Dockerfiles
- Cross-compilation via cargo/cross

### Cluster 2: Go Clients (Prysm, Geth, Erigon)
- go modules + go.sum
- GitHub Actions
- make/Makefile interface
- Docker Hub for images
- Goreleaser or custom scripts for releases

### Cluster 3: Java/Gradle Clients (Teku, Besu)
- Gradle build system
- gradle.lockfile
- Java 21 required
- Docker via `./gradlew docker`
- ConsenSys / Consensys ecosystem

### Unique clients
- **Lodestar**: Only TypeScript; pnpm; monorepo
- **Nimbus**: Only Nim; git submodules; most different dependency model
- **Nethermind**: Only C#/.NET; most complex CI (20+ workflows)

---

## 7. Diversity Score Assessment

To quantify build pipeline diversity, we scored each client on 5 dimensions (0=homogeneous, 1=diverse):

| Dimension | Score | Notes |
|-----------|-------|-------|
| CI Platform | 0.1/1.0 | Nearly all use GitHub Actions |
| Programming Language | 0.9/1.0 | 6 different languages — excellent |
| Build Tool | 0.8/1.0 | Language-linked but diverse overall |
| Package Management | 0.8/1.0 | Diverse registries and approaches |
| Docker Registry | 0.7/1.0 | Mix of Docker Hub, GHCR, GCR |
| **Overall** | **0.66/1.0** | Good language/tool diversity; poor CI platform diversity |

---

## 8. Risk Assessment Summary

### HIGH RISK: GitHub Actions Concentration
- 10/11 clients use GitHub Actions exclusively
- A GitHub platform compromise or outage directly impacts almost all clients' ability to build and release
- Recommendation: Investigate adding GitLab CI or self-hosted runners as fallback

### MEDIUM RISK: Shared Rust Toolchain
- Lighthouse, Grandine, and Reth share the Rust toolchain and cargo ecosystem
- A compromise of `rustup.rs` or `crates.io` could affect all three simultaneously
- Mitigated by: Cargo.lock, crates.io's integrity verification, Rust Foundation governance

### MEDIUM RISK: Consensys Concentration
- Teku (consensus) and Besu (execution) both have Consensys heritage
- Near-identical Gradle pipelines and shared organizational risk
- If Consensys has organizational issues, two clients could be affected

### LOW RISK: Go Ecosystem Dependency
- Prysm, Geth, Erigon all use Go modules
- go.sum provides strong cryptographic verification
- Go module proxy (proxy.golang.org) provides availability guarantees
- Multiple independent teams using the same ecosystem

### DISTINCTIVE PRACTICE (Low risk, high value):
- **Nimbus git submodules**: Most resilient to package registry attacks; most different supply chain model
- **Lodestar pnpm migration**: Proactive supply chain hardening; industry-leading for JS ecosystem
- **Geth's ci.go**: Tight build system ownership; harder for external compromises
- **Prysm's Bazel**: Strongest build reproducibility guarantees

---

## 9. Conclusions

The Ethereum ecosystem demonstrates **strong programming language and build tool diversity** but **weak CI platform diversity**. The concentration on GitHub Actions is a meaningful systemic risk that the community should discuss.

The most resilient combination from a build pipeline perspective is arguably **Nimbus** (unique language, unique build system, git submodules) + **Geth** (custom CI.go, Azure storage) + **Lodestar** (pnpm, GHCR) — three clients that would be least likely to share a common failure mode.

For a deeper view into how client diversity affects consensus security, see [clientdiversity.org](https://clientdiversity.org).
