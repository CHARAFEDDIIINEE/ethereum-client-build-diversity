# Grandine — Build Pipeline Profile

**Language:** Rust  
**Client Type:** Consensus  
**Maintainer:** Sifchain / Grandine team  
**Repository:** https://github.com/grandinetech/grandine

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~4–6 (simplest CI of all consensus clients)

Key workflow files include:
- `ci.yml` — Build and test
- `docker.yml` — Docker image publishing
- `release.yml` — Release pipeline

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `cargo` | Build, test, dependency management |
| `rustup` | Toolchain management |

**Rust toolchain:** Pinned in `rust-toolchain.toml`

---

## Lockfile

- **File:** `Cargo.lock`
- **Committed:** ✅ Yes
- **Scope:** Full workspace

Standard Cargo.lock providing full reproducibility. All dependency hashes verified by cargo during builds.

---

## Docker Support

- **Base image:** Debian slim / Ubuntu
- **Multi-arch:** Partial
- **Registry:** GitHub Container Registry (`ghcr.io/grandinetech/grandine`)
- **Build method:** Multi-stage Dockerfile

---

## Build Commands

From the README:

```bash
# Build release
cargo build --release

# Run tests
cargo test

# Run with specific features
cargo build --release --features=web3signer

# Docker
docker build -t grandine .
```

---

## Workflow Complexity

**Complexity rating:** Low (simplest CI of the 6 consensus clients)

- Fewer workflow files than other clients
- Standard Rust CI pattern (build → test → clippy → fmt)
- Less extensive test matrix
- Newer/smaller team reflected in CI scope

---

## Notable CI Features

1. **Minimal CI footprint** — Reflects the team's lean approach
2. **Standard Rust toolchain** — Follows Rust community conventions closely
3. **GHCR registry** — Alongside Lighthouse and Reth, uses GitHub Container Registry rather than Docker Hub

---

## Supply Chain Security

- `Cargo.lock` committed
- `rust-toolchain.toml` pins exact Rust version
- Cargo's built-in checksum verification

---

## Similarities to Other Clients

- **Shares:** Rust + Cargo + Cargo.lock + GHCR with **Lighthouse** and **Reth**
- **Shares:** GitHub Actions with 9 other clients
- **Unique:** Leanest CI setup of all consensus clients
