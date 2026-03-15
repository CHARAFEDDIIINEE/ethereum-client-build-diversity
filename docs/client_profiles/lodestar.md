# Lodestar — Build Pipeline Profile

**Language:** TypeScript / Node.js  
**Client Type:** Consensus  
**Maintainer:** ChainSafe Systems  
**Repository:** https://github.com/ChainSafe/lodestar

---

## CI/CD Platform

- **Primary:** GitHub Actions
- **Workflows directory:** `.github/workflows/`
- **Estimated workflow count:** ~8–10

Key workflow files include:
- `test.yml` — Unit and integration tests
- `build.yml` — TypeScript compilation check
- `docker.yml` — Docker image builds
- `release.yml` — Release workflow with npm publishing
- `lint.yml` — ESLint, Prettier enforcement

---

## Build Tools & Package Manager

| Tool | Purpose |
|------|---------|
| `pnpm` | Package manager (migrated from yarn) |
| `tsc` | TypeScript compiler |
| `vitest` / `mocha` | Test runners |
| `eslint` | Linting |
| `prettier` | Code formatting |

**Unique distinction:** Lodestar is the **only TypeScript/JavaScript consensus client** and the only client using `pnpm`. The migration from `yarn` to `pnpm` was a deliberate **supply chain security decision** — `pnpm` by default blocks `postinstall` scripts, which are a common vector for supply chain attacks in the npm ecosystem.

**Node.js version:** Pinned in `.nvmrc` and `package.json` engines field

---

## Lockfile

- **File:** `pnpm-lock.yaml`
- **Committed:** ✅ Yes
- **Scope:** Full monorepo workspace (all packages)

The `pnpm-lock.yaml` pins exact versions and integrity hashes for all direct and transitive dependencies. Combined with pnpm's blocked postinstall scripts, this provides strong supply chain guarantees.

---

## Docker Support

- **Base image:** `node:XX-alpine` (lightweight Alpine Linux)
- **Multi-arch:** Partial (`linux/amd64`; ARM less emphasized)
- **Registry:** Docker Hub (`chainsafe/lodestar`)
- **Build method:** Multi-stage Dockerfile (build → production image)
- **Notable:** Alpine base keeps image size minimal; Node.js runtime included

---

## Build Commands

From the README and package.json scripts:

```bash
# Install dependencies
pnpm install

# Build TypeScript
pnpm run build

# Run all tests
pnpm run test

# Run unit tests only
pnpm run test:unit

# Lint
pnpm run lint

# Format check
pnpm run check-format

# Docker build
docker build -t lodestar .

# Run beacon node
node packages/cli/bin/lodestar beacon
# or
./lodestar beacon
```

---

## Workflow Complexity

**Complexity rating:** Medium

- Monorepo with multiple packages (workspace-aware builds)
- TypeScript compilation as a separate CI gate
- Node.js version matrix (LTS versions)
- pnpm workspace-aware caching
- Separate lint, format, type-check, and test stages

---

## Notable CI Features

1. **pnpm for supply chain security** — Blocks postinstall scripts by default, a unique and intentional security choice
2. **Monorepo support** — pnpm workspaces manage multiple interdependent packages
3. **Type-checking gate** — TypeScript strict mode errors fail CI
4. **Format enforcement** — Prettier formatting checked, not just style guidelines
5. **npm publishing** — Lodestar packages are published to npm as part of release

---

## Supply Chain Security

- `pnpm-lock.yaml` with full integrity hashes
- `pnpm` blocks `postinstall` scripts (primary motivation for migration from yarn)
- `.npmrc` configuration restricts package fetching
- TypeScript type-checking provides additional code quality gate
- Regular `pnpm audit` in CI

---

## Similarities to Other Clients

- **Unique:** Only TypeScript client; only pnpm user among the 11
- **Shares:** GitHub Actions with 9 other clients
- **Shares:** Docker Hub registry with Teku, Besu, Geth, Nethermind, Erigon
- **Contrast:** Most different from Nimbus (Nim + submodules) and Prysm (Go + Bazel)
