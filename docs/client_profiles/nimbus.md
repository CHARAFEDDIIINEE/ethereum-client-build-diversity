# Nimbus — Build Pipeline Profile

**Language:** Nim  
**Client Type:** Consensus (also has Nimbus-eth1 execution client)  
**Maintainer:** Status Research & Development  
**Repository:** https://github.com/status-im/nimbus-eth2

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Historical:** Jenkins (Status internal; still referenced in some docs)
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~8–12

Key workflow files include:
- `ci.yml` — Main CI matrix (multiple OS + arch)
- `docker.yml` — Multi-arch Docker builds
- `release.yml` — Binary releases
- `fuzzing.yml` — Fuzzing jobs

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `make` | Primary build driver |
| `nimble` | Nim package manager (limited use) |
| `choosenim` | Nim toolchain version management |
| Git submodules | Dependency management (primary method) |

**Unique distinction:** Nimbus is the **only client not using a standard package registry** for dependencies. All dependencies are vendored via **git submodules**, with dependency versions pinned to specific commit SHAs.

**Nim version:** Pinned in `.nim-version` or CI configuration

---

## Lockfile

- **Lockfile equivalent:** Git submodule SHAs in `.gitmodules` + `git submodule status`
- **Registry lockfile:** ❌ None (no package registry used)
- **Mechanism:** Each submodule is pinned to an exact commit hash

This is the most conservative dependency management approach of all 11 clients — no external registry means no supply chain attack via a compromised package index.

---

## Docker Support

- **Base image:** Debian slim / Ubuntu
- **Multi-arch:** Yes — strong ARM support (`linux/amd64`, `linux/arm64`, `linux/arm/v7`)
- **Registry:** Docker Hub (`statusim/nimbus-eth2`)
- **Build method:** Multiple Dockerfiles for different architectures
- **Notable:** Nimbus has the **most comprehensive ARM support** of all clients, reflecting the Status team's focus on running on resource-constrained devices (Raspberry Pi, embedded hardware)

---

## Build Commands

From the README and Makefile:

```bash
# Clone with all submodules
git clone --recurse-submodules https://github.com/status-im/nimbus-eth2.git

# Build beacon node
make nimbus_beacon_node

# Build and run tests
make test

# Build for specific target
make nimbus_beacon_node NIMFLAGS="-d:release"

# Cross-compile for ARM
make nimbus_beacon_node NIMFLAGS="-d:release" \
  CC=aarch64-linux-gnu-gcc \
  PCRE_CFLAGS="" NIM_CROSS_COMPILE=1

# Docker
docker build -t nimbus .
```

---

## Workflow Complexity

**Complexity rating:** Medium-High

- Large OS + arch matrix (Linux x86_64, ARM64, ARMv7, macOS, Windows)
- Submodule initialization required before every build
- Separate jobs for different CPU architectures
- QEMU emulation used for ARM builds in CI
- Historical Jenkins integration adds maintenance complexity

---

## Notable CI Features

1. **Comprehensive ARM matrix** — Builds and tests on ARMv7, ARM64, and x86_64
2. **Git submodule-based deps** — No package registry dependency risk
3. **QEMU cross-compilation** — Enables ARM testing on x86 CI runners
4. **Raspberry Pi focus** — Explicit optimization for low-power embedded devices
5. **Fuzzing integration** — Periodic fuzz testing jobs

---

## Supply Chain Security

- **Strongest isolation from package registries** of all 11 clients
- All dependencies vendored as git submodules with pinned commit SHAs
- No `npm`, `cargo`, `pip`, or other registry fetches at build time
- Tradeoff: harder to update dependencies; requires manual submodule bumps
- Historical Jenkins pipeline adds an internal CI dependency

---

## Similarities to Other Clients

- **Unique:** Only Nim-language client; only client without a package registry
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** ARM multi-arch Docker with Lighthouse, Reth
- **Closest analog:** No close analog — Nim + git submodules is unique across the ecosystem
