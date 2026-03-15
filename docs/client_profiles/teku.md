# Teku — Build Pipeline Profile

**Language:** Java  
**Client Type:** Consensus  
**Maintainer:** Consensys  
**Repository:** https://github.com/Consensys/teku

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~6–8

Key workflow files include:
- `build.yml` — Gradle build and unit tests
- `integration-tests.yml` — Full integration test suite
- `docker.yml` — Docker image builds and publishing
- `release.yml` — Release workflow

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `gradle` (Gradle Wrapper) | Build, test, packaging |
| `./gradlew` | Wrapper script (no system Gradle required) |
| Maven Central | Dependency registry |

**Java version:** Pinned via `.java-version` or `build.gradle` toolchain specification  
**Gradle version:** Pinned in `gradle/wrapper/gradle-wrapper.properties`

---

## Lockfile

- **File:** `gradle.lockfile` (per subproject)
- **Committed:** ✅ Yes
- **Mechanism:** Gradle dependency locking (`./gradlew dependencies --write-locks`)

Gradle's dependency locking mechanism writes exact resolved versions + checksums to `gradle.lockfile`. All submodule locks must be updated together, enforced by CI.

---

## Docker Support

- **Base image:** Eclipse Temurin (OpenJDK)
- **Multi-arch:** Yes (`linux/amd64`, `linux/arm64`)
- **Registry:** Docker Hub (`consensys/teku`)
- **Build method:** Standard multi-stage Dockerfile
- **Notable:** Separate images for different JVM runtime configurations

---

## Build Commands

From the README and build scripts:

```bash
# Build
./gradlew installDist

# Run tests
./gradlew test

# Full build with integration tests
./gradlew build

# Create distribution archive
./gradlew distTar

# Docker build
docker build -t teku .

# Run Teku
./build/install/teku/bin/teku
```

---

## Workflow Complexity

**Complexity rating:** Medium

- Standard Gradle multi-project build
- Separate jobs for unit vs integration tests
- Gradle build cache used in CI
- JVM matrix testing (multiple Java versions)
- Checkstyle and code quality gates enforced

---

## Notable CI Features

1. **Gradle build cache** — Incremental builds reuse cached task outputs
2. **Checkstyle enforcement** — Code style checked as part of CI gate
3. **JVM compatibility matrix** — Tests run against multiple Java LTS versions
4. **Consensys org standards** — Shared CI patterns with Besu (sister client)

---

## Supply Chain Security

- `gradle.lockfile` committed with exact checksums
- Gradle wrapper checksum verification (`gradle-wrapper.jar` SHA)
- Maven Central over HTTP disabled (HTTPS enforced)
- Dependency verification via Gradle's built-in mechanism

---

## Similarities to Other Clients

- **Shares:** Java + Gradle + `gradle.lockfile` pattern with **Besu** (both Consensys)
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** Docker Hub registry with Besu, Geth, Nethermind, Erigon
- **Notable:** Teku and Besu are the only two clients sharing an organization (Consensys), creating a concentration point in the ecosystem
