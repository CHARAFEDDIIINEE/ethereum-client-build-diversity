# Besu — Build Pipeline Profile

**Language:** Java  
**Client Type:** Execution  
**Maintainer:** Consensys (Hyperledger project)  
**Repository:** https://github.com/hyperledger/besu

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~10–12

Key workflow files include:
- `build.yml` — Gradle build and tests
- `docker.yml` — Container image publishing
- `release.yml` — Release pipeline
- `lint.yml` — Spotless formatting + linting
- `dco.yml` — Developer Certificate of Origin validation
- `repolinter.yml` — Repository structure compliance

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `gradle` (Gradle Wrapper) | Build, test, packaging |
| `./gradlew` | Wrapper script |
| Maven Central | Dependency registry |
| Spotless | Code formatting enforcement |

**Hyperledger governance:** Besu follows Hyperledger project requirements, which add governance workflows (DCO, Repolinter) not seen in other clients.

**Java version:** Pinned via Gradle toolchain / `.java-version`  
**Gradle version:** Pinned in `gradle/wrapper/gradle-wrapper.properties`

---

## Lockfile

- **File:** `gradle.lockfile` (per subproject)
- **Committed:** ✅ Yes
- **Mechanism:** Same Gradle dependency locking as Teku (`./gradlew dependencies --write-locks`)

This mirrors Teku's approach exactly — both clients use Gradle locking with the same Consensys toolchain conventions.

---

## Docker Support

- **Base image:** Eclipse Temurin (OpenJDK)
- **Multi-arch:** Yes (`linux/amd64`, `linux/arm64`)
- **Registry:** Docker Hub (`hyperledger/besu`)
- **Build method:** Multi-stage Dockerfile
- **Notable:** Images published under the `hyperledger` org, not `consensys`

---

## Build Commands

From the README and Gradle scripts:

```bash
# Build
./gradlew build

# Build without tests
./gradlew assemble

# Run tests
./gradlew test

# Run acceptance tests
./gradlew acceptanceTest

# Run with Spotless format check
./gradlew spotlessCheck

# Apply Spotless formatting
./gradlew spotlessApply

# Docker build
docker build -t besu .

# Run Besu
./build/install/besu/bin/besu
```

---

## Workflow Complexity

**Complexity rating:** Medium-High

- Gradle multi-project build (many submodules)
- Hyperledger governance requirements add overhead: DCO validation, Repolinter checks
- Spotless enforced as a hard CI gate (PRs fail if code isn't formatted)
- Acceptance test suite in addition to unit tests
- JVM compatibility matrix

---

## Notable CI Features

1. **Hyperledger governance** — DCO (Developer Certificate of Origin) required for all commits; validated by GitHub Action. Repolinter enforces repository structure standards.
2. **Spotless formatter** — Code formatting is a CI requirement, not optional. `spotlessCheck` fails the build on unformatted code.
3. **Repolinter** — Validates the repository meets Hyperledger project standards (license headers, README requirements, etc.)
4. **DCO validation** — Every commit must be signed off; enforced automatically in CI
5. **Acceptance test suite** — Separate acceptance tests beyond unit tests

---

## Supply Chain Security

- `gradle.lockfile` committed with exact checksums
- Gradle wrapper checksum verification
- Maven Central HTTPS enforcement
- Hyperledger governance requirements provide organizational accountability
- Eclipse Temurin (formerly AdoptOpenJDK) is a trusted, community-verified JDK

---

## Similarities to Other Clients

- **Shares:** Java + Gradle + `gradle.lockfile` with **Teku** (both Consensys-aligned)
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** Docker Hub with Geth, Nethermind, Teku, Erigon, Lodestar
- **Unique among clients:** Hyperledger governance requirements (DCO, Repolinter) not present in any other client
- **Notable concentration risk:** Teku + Besu share an organization (Consensys), same language (Java), same build tool (Gradle), same lockfile mechanism — highest concentration pair in the ecosystem
