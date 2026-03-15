# Prysm — Build Pipeline Profile

**Language:** Go  
**Client Type:** Consensus  
**Maintainer:** Prysmatic Labs (now Offchain Labs)  
**Repository:** https://github.com/prysmaticlabs/prysm

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Secondary:** Bazel Remote Cache (BuildBuddy or self-hosted)
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~8–10

Key workflow files include:
- `go.yml` — Standard Go tests and linting
- `bazel.yml` — Bazel-based build and test
- `docker.yml` — Container image publishing
- `release.yml` — Binary release pipeline

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `bazel` / `bazelisk` | Hermetic, reproducible builds (primary) |
| `go modules` | Dependency management |
| `gazelle` | Bazel BUILD file generation from Go code |
| `make` | Developer convenience wrapper |

**Unique distinction:** Prysm is the **only Ethereum consensus client** using Bazel for builds. This provides hermetic, fully reproducible builds at the cost of significant complexity.

**Go version:** Pinned in `.bazelrc` and `go.mod`

---

## Lockfile

- **File:** `go.sum`
- **Committed:** ✅ Yes
- **Additional:** Bazel `WORKSPACE` and `go_repositories.bzl` pin all dependencies

The `go.sum` provides cryptographic verification of all Go module downloads. Bazel adds a second layer of hermetic dependency pinning via its own lockfile mechanism.

---

## Docker Support

- **Base image:** `gcr.io/distroless/base` (Google's minimal container images)
- **Multi-arch:** Partial (primarily `linux/amd64`)
- **Registry:** Google Container Registry (`gcr.io/prysmaticlabs/prysm`)
- **Build method:** Bazel rules for container images (using `rules_docker` or `rules_oci`)
- **Notable:** Docker images are built _via Bazel_, not standard `docker build`

---

## Build Commands

From the README and Makefile:

```bash
# Using Bazel (recommended)
bazelisk build //cmd/beacon-chain:beacon-chain
bazelisk build //cmd/validator:validator
bazelisk test //...

# Using Go directly
go build ./cmd/beacon-chain/...
go build ./cmd/validator/...
go test ./...

# Using Makefile
make build
make test
make lint

# Docker (via Bazel)
bazelisk run //cmd/beacon-chain:image
```

---

## Workflow Complexity

**Complexity rating:** High

- Dual build system (Go + Bazel) requires maintaining both
- Bazel remote caching configuration for CI speed
- Large test suite with extensive coverage requirements
- Separate jobs for: unit tests, integration tests, end-to-end tests, fuzz tests
- `gazelle` must be kept in sync with Go code changes

---

## Notable CI Features

1. **Bazel hermetic builds** — Every dependency is pinned; builds are bit-for-bit reproducible
2. **Bazel remote cache** — CI shares a remote build cache to avoid rebuilding unchanged targets
3. **Distroless containers** — Security-focused minimal base images
4. **Gazelle automation** — BUILD files auto-generated from Go import graph

---

## Supply Chain Security

- `go.sum` cryptographic verification
- Bazel WORKSPACE pins all external deps with SHA256 hashes
- Distroless base images minimize attack surface
- No shell scripts in critical build paths (Bazel rules are declarative)

---

## Similarities to Other Clients

- **Shares:** Go language + `go.sum` lockfile with **Geth** and **Erigon**
- **Shares:** GitHub Actions with 9 other clients
- **Unique:** Only client using Bazel across all 11 analyzed
