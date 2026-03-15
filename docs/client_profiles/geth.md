# Geth (go-ethereum) — Build Pipeline Profile

**Language:** Go  
**Client Type:** Execution  
**Maintainer:** Ethereum Foundation  
**Repository:** https://github.com/ethereum/go-ethereum

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Artifact storage:** Azure Blob Storage (for binary release artifacts)
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~8–10

Key workflow files include:
- `go.yml` — Standard Go tests
- `build.yml` — Build matrix across OS/arch
- `docker.yml` — Docker image publishing

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `go modules` | Dependency management |
| `make` | Build convenience wrapper |
| `build/ci.go` | **Custom Go script** orchestrating CI tasks |
| `go build` | Direct compiler invocation |

**Unique distinction:** Geth uses a **custom Go program (`build/ci.go`)** to orchestrate its CI pipeline rather than shell scripts or a build tool. This Go script handles: building, testing, packaging, cross-compilation, and uploading artifacts to Azure. This is unique among all 11 clients.

**Go version:** Pinned in `go.mod`

---

## Lockfile

- **File:** `go.sum`
- **Committed:** ✅ Yes
- **Scope:** All module dependencies

Standard Go module sum file providing cryptographic verification of all downloaded dependencies.

---

## Docker Support

- **Base image:** Alpine Linux
- **Multi-arch:** Yes (`linux/amd64`, `linux/arm64`, `linux/arm/v7`)
- **Registry:** Docker Hub (`ethereum/client-go`)
- **Build method:** Multi-stage Dockerfile
- **Notable:** One of the most widely pulled Docker images in the Ethereum ecosystem

---

## Build Commands

From the README and Makefile:

```bash
# Build geth binary
make geth

# Build all tools
make all

# Run tests
go test ./...

# Build via ci.go script
go run build/ci.go build

# Cross-compile (via ci.go)
go run build/ci.go xgo --targets=linux/amd64,linux/arm64

# Docker
docker pull ethereum/client-go
docker run -it -p 30303:30303 ethereum/client-go
```

---

## Workflow Complexity

**Complexity rating:** Medium-High

- Custom `build/ci.go` Go program adds sophistication
- Multi-platform binary releases (Linux, macOS, Windows; multiple architectures)
- Azure Blob Storage integration for artifact distribution
- Extensive cross-compilation matrix
- `geth` has one of the oldest, most mature CI setups in the ecosystem

---

## Notable CI Features

1. **`build/ci.go` custom CI orchestrator** — A full Go program replacing shell scripts; handles build, package, cross-compile, and upload. Unique across all 11 clients.
2. **Azure artifact distribution** — Release binaries pushed to Azure Blob Storage (gethstore.blob.core.windows.net)
3. **Broadest OS matrix** — Windows, macOS, and multiple Linux variants all tested
4. **Long-standing CI** — One of the most mature CI setups in the ecosystem (Geth is the oldest client)
5. **PPA / Homebrew / Chocolatey** — Package manager publishing integrated into release pipeline

---

## Supply Chain Security

- `go.sum` cryptographic verification
- Custom CI program reduces reliance on third-party CI actions
- Azure for artifact storage (not GitHub Actions artifacts, which have shorter retention)
- Ethereum Foundation ownership provides organizational accountability

---

## Similarities to Other Clients

- **Shares:** Go + `go.sum` lockfile with **Prysm** and **Erigon**
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** ARM Docker support with Nimbus, Lighthouse, Reth
- **Unique:** Only client using a custom Go CI orchestration program (`build/ci.go`)
- **Unique:** Only client using Azure Blob Storage for artifact distribution
