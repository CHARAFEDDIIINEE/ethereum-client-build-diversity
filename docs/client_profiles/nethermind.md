# Nethermind — Build Pipeline Profile

**Language:** C# / .NET  
**Client Type:** Execution  
**Maintainer:** Nethermind  
**Repository:** https://github.com/NethermindEth/nethermind

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~20+ (most complex CI of all 11 clients)

Key workflow files include:
- `build.yml` — Main .NET build and test
- `publish-nethermind.yml` — Release publishing
- `publish-arm64.yml` — ARM64 native builds
- `build-rocksdb.yml` — RocksDB native library
- `build-bls.yml` — BLS native library
- `build-gmp.yml` — GMP native library  
- `build-mcl.yml` — MCL native library
- `build-secp256k1.yml` — Secp256k1 native library
- `docker.yml` — Container publishing
- `reproducible-build.yml` — Reproducible build verification
- `sync-tests.yml` — Full node sync testing
- And many more...

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `dotnet` / MSBuild | Primary build tool |
| NuGet | .NET package manager |
| `cmake` | Native library builds (C/C++ components) |
| `make` | Native library build wrapper |

**Unique distinction:** Nethermind is the **only C#/.NET client** and has the most complex build pipeline due to its native library dependencies. Several cryptographic and storage libraries are compiled from source: BLS (bls-eth-dotnet), GMP (GNU Multiple Precision), MCL (Miracl Core Library), RocksDB, and Secp256k1.

**.NET version:** Pinned in `global.json`

---

## Lockfile

- **File:** `packages.lock.json` (per project)
- **Committed:** ⚠️ Partial — some projects have lock files; not universally enforced
- **NuGet mechanism:** `RestoreLockedMode=true` in CI enforces locked restoration

NuGet's lock file mechanism is less universally adopted than Cargo.lock or go.sum, reflecting the .NET ecosystem's historical norms.

---

## Docker Support

- **Base image:** `mcr.microsoft.com/dotnet/aspnet` (Microsoft's official .NET runtime)
- **Multi-arch:** Yes (`linux/amd64`, `linux/arm64`)
- **Registry:** Docker Hub (`nethermind/nethermind`)
- **Build method:** Multi-stage Dockerfile with separate native lib stages
- **Notable:** Docker build is complex due to native library compilation requirements

---

## Build Commands

From the README:

```bash
# Build
dotnet build src/Nethermind/Nethermind.Runner

# Publish (self-contained)
dotnet publish src/Nethermind/Nethermind.Runner \
  -r linux-x64 --sc true -o out

# Run tests
dotnet test src/Nethermind/Nethermind.sln

# Docker
docker pull nethermind/nethermind
docker run -it nethermind/nethermind

# Build native libs (example: RocksDB)
cd src/Nethermind/Nethermind.Db.Rocks/libs/
./build_rocksdb.sh
```

---

## Workflow Complexity

**Complexity rating:** Very High (most complex of all 11 clients)

- 20+ workflow files
- Separate workflows for each native library (BLS, GMP, MCL, RocksDB, Secp256k1)
- Reproducible build verification pipeline
- ARM64 native compilation pipeline
- Full sync testing against mainnet snapshots
- .NET + C/C++ mixed-language build requirements

---

## Notable CI Features

1. **Native library build pipelines** — Separate workflows for each C/C++ native dependency; pre-compiled and cached
2. **Reproducible build verification** — Uses `SOURCE_DATE_EPOCH` and deterministic compilation flags; verifies output hashes
3. **Most workflows of all clients** — 20+ GitHub Actions workflows, reflecting the breadth of the build surface
4. **ARM64 dedicated pipeline** — Full separate workflow for ARM64 native library compilation
5. **Full sync tests** — CI includes tests that sync against live or snapshot Ethereum mainnet data

---

## Supply Chain Security

- `packages.lock.json` partially enforced
- `RestoreLockedMode=true` in CI prevents unintended dependency resolution
- Native library sources compiled from scratch (avoids pre-built binary trust issues)
- `SOURCE_DATE_EPOCH` for reproducible builds
- Microsoft Container Registry base images (official .NET support)

---

## Similarities to Other Clients

- **Unique:** Only C#/.NET client; most complex CI; only client with multiple native library build pipelines
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** Docker Hub with Geth, Teku, Besu, Erigon, Lodestar
- **Contrast:** Most different from Grandine (simplest CI) and Lodestar (pure TypeScript, no native deps)
