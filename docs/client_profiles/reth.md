# Reth — Build Pipeline Profile

**Language:** Rust  
**Client Type:** Execution  
**Maintainer:** Paradigm  
**Repository:** https://github.com/paradigmxyz/reth

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~10–14

Key workflow files include:
- `unit.yml` — Unit tests with cargo-nextest
- `integration.yml` — Integration tests
- `docker.yml` — Multi-arch Docker builds
- `release.yml` — Release with pre-built binaries
- `lint.yml` — Clippy, rustfmt
- `reproducible.yml` — Reproducible build verification
- `cross.yml` — Cross-compilation for ARM targets
- `bench.yml` — Performance benchmarks

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `cargo` | Build and dependency management |
| `cargo-nextest` | Faster parallel test runner (replaces `cargo test`) |
| `cross` | Cross-compilation for ARM targets |
| `rustup` | Toolchain management |
| `cargo-deny` | Dependency audit (licenses, advisories) |

**Unique distinction:** Reth uses `cargo-nextest` for testing instead of the standard `cargo test`. nextest runs tests in parallel with better output, faster execution, and per-test timeouts — a modern testing approach adopted by few projects.

**Rust toolchain:** Pinned in `rust-toolchain.toml`

---

## Lockfile

- **File:** `Cargo.lock`
- **Committed:** ✅ Yes
- **Scope:** Full workspace

Standard Cargo.lock with full reproducibility. All dependency hashes verified by cargo.

---

## Docker Support

- **Base image:** Debian slim / Ubuntu
- **Multi-arch:** Yes (`linux/amd64`, `linux/arm64`)
- **Registry:** GitHub Container Registry (`ghcr.io/paradigmxyz/reth`)
- **Build method:** Multi-stage Dockerfile
- **Multiple build profiles:**
  - `release` — Standard release build
  - `maxperf` — Maximum performance (LTO, `target-cpu=native`)
  - `reproducible` — Deterministic output builds

---

## Build Commands

From the README and Makefile:

```bash
# Standard release build
cargo build --release

# Maximum performance build
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf

# Run tests (via cargo-nextest)
cargo nextest run

# Run tests (standard)
cargo test

# Cross-compile for ARM
cross build --target aarch64-unknown-linux-gnu --release

# Lint
cargo clippy --all --all-features

# Dependency audit
cargo deny check

# Docker
docker pull ghcr.io/paradigmxyz/reth
docker run ghcr.io/paradigmxyz/reth node
```

---

## Workflow Complexity

**Complexity rating:** High (most sophisticated Rust CI of the three Rust clients)

- Multiple build profiles (release, maxperf, reproducible)
- `cargo-nextest` for advanced test execution
- ARM cross-compilation with `cross`
- `cargo-deny` for dependency license and advisory checks
- Reproducible build verification
- Performance benchmarks in CI
- Newest execution client, reflecting modern Rust CI best practices

---

## Notable CI Features

1. **`cargo-nextest`** — Faster, parallel test runner with better UX and per-test timeouts; replaces `cargo test`. Unique among the three Rust clients.
2. **Multiple build profiles** — Three distinct build configurations: `release`, `maxperf` (LTO + native CPU), and `reproducible` (deterministic)
3. **Reproducible builds** — Verified via hash comparison of deterministic builds
4. **`cargo-deny`** — Checks all dependencies for known security advisories, banned licenses, and duplicate crates
5. **Performance benchmarking** — Automated performance regression detection in CI
6. **`cross` for ARM** — Cross-compilation to `aarch64-unknown-linux-gnu` without requiring ARM hardware

---

## Supply Chain Security

- `Cargo.lock` committed (full reproducibility)
- `cargo-deny` audits all dependencies for CVEs and license issues
- `rust-toolchain.toml` pins exact Rust version
- GHCR for Docker images (tighter GitHub integration)
- Reproducible builds with hash verification

---

## Similarities to Other Clients

- **Shares:** Rust + Cargo + Cargo.lock + GHCR with **Lighthouse** and **Grandine**
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** ARM Docker + GHCR with Lighthouse and Grandine
- **Unique among Rust clients:** `cargo-nextest`, multiple build profiles, `cargo-deny`, performance benchmarks
- **Notable:** Most modern/comprehensive CI of the three Rust clients; reflects Paradigm's investment in tooling quality
