# Erigon — Build Pipeline Profile

**Language:** Go  
**Client Type:** Execution  
**Maintainer:** Erigon (formerly Turbo-Geth; led by Alexey Akhunov)  
**Repository:** https://github.com/erigontech/erigon

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~10–14

Key workflow files include:
- `ci.yml` — Main build and test matrix
- `docker.yml` — Container publishing
- `release.yml` — Release workflow
- `integration-tests.yml` — Full integration testing
- `kurtosis.yml` — Multi-client testnet via Kurtosis

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `go modules` | Dependency management |
| `make` | Build and convenience tasks |
| `go build` | Direct compilation |
| `kurtosis` | Multi-client testnet orchestration |
| `docker-compose` | Local multi-service testing |

**Go version:** Pinned in `go.mod`

---

## Lockfile

- **File:** `go.sum`
- **Committed:** ✅ Yes
- **Scope:** All module dependencies

Standard Go module sum file providing cryptographic hash verification of all dependencies.

---

## Docker Support

- **Base image:** Alpine Linux
- **Multi-arch:** Yes (`linux/amd64`, `linux/arm64`)
- **Registry:** Docker Hub (`thorax/erigon` or `erigontech/erigon`)
- **Build method:** Multi-stage Dockerfile
- **Notable:** `docker-compose.yml` provided for running multi-service stacks (Erigon + consensus layer)

---

## Build Commands

From the README and Makefile:

```bash
# Build all binaries
make erigon

# Build specific binary
go build -o ./build/bin/erigon ./cmd/erigon

# Run tests
go test ./...
make test

# Integration tests
make integration-tests

# Docker
docker pull thorax/erigon
docker-compose up

# Build with specific flags
go build -tags nosqlite,noboltdb ./cmd/erigon
```

---

## Workflow Complexity

**Complexity rating:** High

- Full node sync tests in CI (not just unit tests)
- Kurtosis Assertoor integration for multi-client testnet validation
- docker-compose stack for service integration testing
- Active fork from Geth with additional architectural complexity (stages, MDBX)
- ARM64 builds in CI matrix

---

## Notable CI Features

1. **Kurtosis integration** — Uses Kurtosis to spin up ephemeral multi-client Ethereum testnets in CI; validates Erigon against consensus clients in automated testnet scenarios
2. **Full sync testing** — CI includes tests that perform actual Ethereum chain sync (not just unit tests)
3. **Assertoor** — Kurtosis Assertoor runs scenario-based tests on the testnet (e.g., "do 10 deposits succeed?")
4. **docker-compose stack** — Full multi-service Docker Compose configuration for local development and CI
5. **MDBX storage** — Custom storage engine (MDBX fork) with its own build requirements

---

## Supply Chain Security

- `go.sum` cryptographic verification
- Go modules' built-in integrity verification
- MDBX bundled directly (not fetched from external registry)
- GitHub Actions with pinned action versions

---

## Similarities to Other Clients

- **Shares:** Go + `go.sum` lockfile with **Prysm** and **Geth**
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** Docker Hub with Geth, Teku, Besu, Nethermind, Lodestar
- **Unique:** Most advanced multi-client testnet integration (Kurtosis) of all execution clients
- **Notable:** Forked from Geth but architecturally diverged significantly (staged sync, MDBX)
