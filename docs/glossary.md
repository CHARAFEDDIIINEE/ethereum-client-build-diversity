# Glossary

Terms and concepts used throughout this analysis.

---

## Build & CI/CD Terms

**Bazel**  
A build system from Google that provides hermetic, reproducible builds. "Hermetic" means the build is fully isolated from the local environment — all tools and dependencies are declared and pinned. Prysm is the only Ethereum client using Bazel.

**cargo**  
The Rust package manager and build tool. Handles dependency fetching, compilation, testing, and publishing of Rust crates (libraries/binaries).

**cargo-deny**  
A Cargo plugin that checks all dependencies against security advisories, prohibited licenses, and banned crates. Used by Reth.

**cargo-nextest**  
A faster, more feature-rich test runner for Rust projects. Drop-in replacement for `cargo test` with better parallelism and output. Used by Reth.

**CI/CD (Continuous Integration / Continuous Deployment)**  
Automated processes that build, test, and potentially deploy software on every code change. CI ensures code changes don't break existing functionality; CD automates the release of verified changes.

**cross**  
A Rust tool for cross-compiling binaries for different target architectures (e.g., building ARM64 binaries on an x86_64 machine). Used by Lighthouse and Reth.

**Docker Registry**  
A service that stores and distributes Docker container images. Common registries: Docker Hub (hub.docker.com), GitHub Container Registry (ghcr.io), Google Container Registry (gcr.io).

**dotnet / MSBuild**  
The build toolchain for C# and .NET projects. `dotnet` is the CLI; MSBuild is the underlying build engine.

**Dockerfile**  
A script defining how to build a Docker container image. Multi-stage Dockerfiles have separate build and runtime stages to minimize final image size.

**Gazelle**  
A Bazel BUILD file generator for Go projects. Automatically creates and maintains Bazel BUILD files from Go import graphs.

**GitHub Actions**  
A CI/CD platform integrated into GitHub. Workflows are defined as YAML files in `.github/workflows/`. The dominant CI platform across all 11 clients (10/11 use it).

**Gradle**  
A build tool for JVM languages (primarily Java/Kotlin). Used by Teku and Besu. Gradle Wrapper (`./gradlew`) bundles a specific Gradle version with the project.

**go modules / go.mod**  
Go's built-in dependency management system. `go.mod` declares dependencies; `go.sum` provides cryptographic verification of all downloaded modules.

**Hermetic build**  
A build that is fully isolated from the build environment — same inputs always produce same outputs, regardless of the machine or environment. Bazel provides hermetic builds. Most other build systems do not.

**Jenkins**  
An open-source CI/CD automation server. Older and more self-hosted-oriented than GitHub Actions. Nimbus historically used Jenkins (Status's internal instance).

**Kurtosis**  
A tool for spinning up ephemeral, reproducible distributed system environments (like Ethereum testnets) for testing. Erigon uses Kurtosis in CI to test against live multi-client networks.

**lockfile**  
A file that records the exact versions (and often cryptographic hashes) of all dependencies used in a build. Ensures reproducible builds and prevents supply chain attacks. Examples: `Cargo.lock`, `go.sum`, `pnpm-lock.yaml`, `gradle.lockfile`.

**make / Makefile**  
A classic Unix build tool. Most clients use `make` as a convenience wrapper around their primary build tool (e.g., `make build` runs `cargo build --release`).

**Multi-stage Dockerfile**  
A Dockerfile with multiple `FROM` instructions. The first stage ("builder") compiles the code; the second stage ("runtime") copies only the compiled binary into a minimal base image, keeping the final container small.

**NuGet**  
The package manager for .NET/C# projects. Used by Nethermind.

**nimble**  
The package manager for the Nim language. Nimbus uses Nim but relies on git submodules rather than nimble for dependency management.

**pnpm**  
A fast, disk-efficient Node.js package manager. Compared to npm/yarn, pnpm blocks `postinstall` scripts by default, reducing supply chain attack risk. Used by Lodestar.

**Reproducible build**  
A build process that produces bit-for-bit identical output regardless of when or where it's run, given the same source inputs. Enables verification that a distributed binary matches its source code. Nethermind and Reth explicitly implement this.

**Repolinter**  
A tool that validates repository structure against a set of rules (e.g., presence of a LICENSE file, README format). Used by Besu as part of Hyperledger governance.

**self-hosted runner**  
A CI runner machine operated by the project team rather than by the CI provider. Reduces dependence on the provider's infrastructure and can be more powerful/faster for intensive builds.

**SOURCE_DATE_EPOCH**  
An environment variable used to make builds reproducible by setting a fixed timestamp for all embedded date/time values. Used by Nethermind.

**Spotless**  
A Gradle plugin that enforces code formatting. Used by Besu to ensure all code meets style requirements before merging.

**supply chain attack**  
An attack that targets the build process or dependencies of software rather than the software itself. Examples: compromising a package registry (npm, crates.io), injecting malicious code into a widely-used dependency, or compromising a CI system.

---

## Ethereum Ecosystem Terms

**Assertoor**  
A Kurtosis plugin for running scenario-based tests on Ethereum testnets. Used by Erigon to assert that specific behaviors occur correctly on a live test network.

**Consensus client**  
An Ethereum client responsible for the proof-of-stake consensus layer (Beacon Chain). Manages validators, attestations, and block finalization. Analyzed: Lighthouse, Prysm, Teku, Nimbus, Lodestar, Grandine.

**DCO (Developer Certificate of Origin)**  
A lightweight contributor agreement requiring developers to sign off that they have the right to contribute their code. Required by Hyperledger projects (Besu). Enforced via `Signed-off-by:` Git commit trailers.

**Execution client**  
An Ethereum client responsible for the execution layer — processing transactions, maintaining state, and running EVM computations. Analyzed: Geth, Nethermind, Besu, Erigon, Reth.

**EF (Ethereum Foundation) consensus spec tests**  
Official test vectors published by the Ethereum Foundation that test consensus rule implementations. Clients like Lighthouse and Prysm run these in CI to verify spec compliance.

**Hyperledger**  
A Linux Foundation project umbrella for enterprise blockchain tools. Besu is a Hyperledger project, imposing governance requirements (DCO, Repolinter) not present in other clients.

**MDBX**  
A high-performance key-value database forked from LMDB. Used by Erigon as its primary storage engine, replacing LevelDB/RocksDB used by Geth.

**Merge (The Merge)**  
Ethereum's transition from proof-of-work to proof-of-stake (September 2022). After The Merge, every Ethereum node requires both a consensus client and an execution client working together.

**RocksDB**  
A high-performance embedded key-value store from Facebook/Meta. Used by Nethermind (and previously Geth) for chain state storage. Nethermind compiles RocksDB from source in its CI.

---

## Security Terms

**BLS (Boneh–Lynn–Shacham)**  
A cryptographic signature scheme used for Ethereum validator signatures. Clients require a BLS library; Nethermind compiles one from C source (bls-eth-dotnet/herumi).

**GMP (GNU Multiple Precision Arithmetic Library)**  
A C library for arbitrary-precision arithmetic. Used by Nethermind's BLS implementation.

**MCL (Miracl Core Library)**  
A portable cryptographic library. Used by Nethermind.

**Secp256k1**  
The elliptic curve used by Ethereum for transaction signing (also used by Bitcoin). All Ethereum clients require a secp256k1 implementation. Nethermind compiles one from C source.

**SHA-256 / SHA-512**  
Cryptographic hash functions used in lockfiles to verify dependency integrity. `go.sum` uses SHA-256; NuGet's `packages.lock.json` uses SHA-512.

**postinstall scripts**  
npm/pnpm lifecycle scripts that run after a package is installed. A common supply chain attack vector — a compromised package can execute arbitrary code via postinstall. pnpm blocks these by default, which is why Lodestar migrated to pnpm.
