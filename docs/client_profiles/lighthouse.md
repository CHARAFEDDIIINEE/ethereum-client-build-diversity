# Lighthouse — Build Pipeline Profile

**Language:** Rust  
**Client Type:** Consensus  
**Maintainer:** Sigma Prime  
**Repository:** https://github.com/sigp/lighthouse

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~10–12

Key workflow files include:
- `test-suite.yml` — Full unit + integration test matrix
- `docker.yml` — Multi-arch Docker image builds (linux/amd64, linux/arm64)
- `release.yml` — Binary release pipeline
- `book.yml` — Documentation builds via mdBook

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `cargo` | Primary build and test runner |
| `rustup` | Toolchain version management |
| `make` | Convenience wrapper for common tasks |
| `cross` | Cross-compilation for ARM targets |

**Rust toolchain:** Pinned in `rust-toolchain.toml`

---

## Lockfile

- **File:** `Cargo.lock`
- **Committed:** ✅ Yes
- **Scope:** All workspace crates

The `Cargo.lock` is committed to the repository, ensuring fully reproducible builds for both CI and developers. All dependency hashes are verified by `cargo` during builds.

---

## Docker Support

- **Base image:** Debian slim
- **Multi-arch:** Yes (`linux/amd64`, `linux/arm64`)
- **Registry:** GitHub Container Registry (`ghcr.io/sigp/lighthouse`)
- **Build method:** Multi-stage Dockerfile (builder + runtime stage)
- **Notable:** Separate Dockerfile variants for different features (e.g., modern CPU optimizations via `Makefile` targets)

---

## Build Commands

From the README and Makefile:

```bash
# Standard release build
cargo build --release

# Run tests
cargo test

# Build with maximal CPU optimizations
RUSTFLAGS="-C target-cpu=native" cargo build --release

# Docker build
docker buildx build --platform linux/amd64,linux/arm64 -t lighthouse .

# Via Makefile
make
make test
make lint
```

---

## Workflow Complexity

**Complexity rating:** Medium-High

- Large test matrix across multiple OS targets
- Separate jobs for: unit tests, integration tests, EF consensus spec tests, beacon fuzz testing
- Self-hosted runners used for some heavy jobs
- Caching: `~/.cargo/registry` and `~/.cargo/git` cached between runs
- Artifact uploads for binaries and test coverage reports

---

## Notable CI Features

1. **Ethereum Foundation Consensus Spec Tests** — Runs the official EF test vectors as part of CI
2. **Fuzz testing** — Periodic fuzzing jobs integrated into CI
3. **Book publishing** — Auto-publishes documentation to GitHub Pages
4. **Release automation** — Automatically creates GitHub Releases with pre-built binaries for multiple platforms

---

## Supply Chain Security

- Cargo.lock committed (full reproducibility)
- `rust-toolchain.toml` pins exact toolchain version
- No postinstall scripts (Rust/Cargo has no equivalent risk)
- Dependency audit: `cargo audit` periodically run

---

## Similarities to Other Clients

- **Shares:** Rust + Cargo + Cargo.lock pattern with **Grandine** and **Reth**
- **Shares:** GitHub Actions monoculture with 9 other clients
- **Shares:** Multi-arch Docker with `linux/arm64` support (Nimbus, Reth)
