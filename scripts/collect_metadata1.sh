#!/usr/bin/env bash
# collect_metadata.sh
# Collects build pipeline metadata from Ethereum client repositories.
# Usage: ./scripts/collect_metadata.sh [--client <name>] [--output <dir>]
#
# Requires: git, gh (GitHub CLI), jq, curl
# Optional: ripgrep (rg) for faster file searching

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${REPO_ROOT}/data/raw"
CLONE_DIR="/tmp/eth-clients"

declare -A CLIENT_REPOS=(
  ["lighthouse"]="https://github.com/sigp/lighthouse"
  ["prysm"]="https://github.com/prysmaticlabs/prysm"
  ["teku"]="https://github.com/Consensys/teku"
  ["nimbus"]="https://github.com/status-im/nimbus-eth2"
  ["lodestar"]="https://github.com/ChainSafe/lodestar"
  ["grandine"]="https://github.com/grandinetech/grandine"
  ["geth"]="https://github.com/ethereum/go-ethereum"
  ["nethermind"]="https://github.com/NethermindEth/nethermind"
  ["besu"]="https://github.com/hyperledger/besu"
  ["erigon"]="https://github.com/erigontech/erigon"
  ["reth"]="https://github.com/paradigmxyz/reth"
)

# ─── Utility functions ────────────────────────────────────────────────────────

log() { echo "[$(date +%H:%M:%S)] $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

check_deps() {
  local missing=()
  for cmd in git jq curl; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing[*]}"
  fi
  command -v rg &>/dev/null && RG_AVAILABLE=true || RG_AVAILABLE=false
  command -v gh &>/dev/null && GH_AVAILABLE=true || GH_AVAILABLE=false
  log "Using ripgrep: $RG_AVAILABLE | GitHub CLI: $GH_AVAILABLE"
}

# ─── Repository operations ────────────────────────────────────────────────────

clone_or_update() {
  local name="$1"
  local url="$2"
  local dest="$CLONE_DIR/$name"

  if [[ -d "$dest/.git" ]]; then
    log "Updating $name..."
    git -C "$dest" pull --quiet --ff-only 2>/dev/null || log "  (skipping pull — not fast-forwardable)"
  else
    log "Cloning $name (shallow)..."
    git clone --depth=1 --quiet "$url" "$dest"
  fi
}

# ─── Detection functions ──────────────────────────────────────────────────────

# Returns true (exit 0) if $dir contains a Jenkinsfile within 2 levels
_has_jenkinsfile() {
  find "$1" -maxdepth 2 -name "Jenkinsfile" -print -quit 2>/dev/null | grep -q .
}

# Returns true (exit 0) if $dir contains a root-level gradle build file
_has_gradle_root() {
  [[ -f "$1/build.gradle" ]] || [[ -f "$1/build.gradle.kts" ]] || \
  [[ -f "$1/settings.gradle" ]] || [[ -f "$1/settings.gradle.kts" ]]
}

# Returns true (exit 0) if $dir contains a root-level .sln or .csproj file
_has_csharp_root() {
  find "$1" -maxdepth 1 \( -name "*.sln" -o -name "*.csproj" \) -print -quit 2>/dev/null | grep -q .
}

detect_ci_platform() {
  local dir="$1"
  local platforms=()

  [[ -d "$dir/.github/workflows" ]] && platforms+=("github-actions")

  # Guard Jenkins carefully: find exits 0 even when empty, so pipe through grep
  _has_jenkinsfile "$dir" && platforms+=("jenkins")

  [[ -f "$dir/.travis.yml" ]] && platforms+=("travis-ci")
  [[ -f "$dir/.circleci/config.yml" ]] && platforms+=("circleci")
  [[ -f "$dir/.gitlab-ci.yml" ]] && platforms+=("gitlab-ci")
  [[ -f "$dir/azure-pipelines.yml" ]] && platforms+=("azure-pipelines")
  [[ -d "$dir/.buildkite" ]] && platforms+=("buildkite")

  if [[ ${#platforms[@]} -eq 0 ]]; then
    echo "unknown"
  else
    # local IFS is scoped: joins array elements with comma
    printf "%s\n" "${platforms[@]}" | paste -sd, | sed "s/,/, /g"
  fi
}

count_workflows() {
  local dir="$1"
  local wf_dir="$dir/.github/workflows"
  if [[ -d "$wf_dir" ]]; then
    find "$wf_dir" \( -name "*.yml" -o -name "*.yaml" \) | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

# detect_language: language-specific priority ordering avoids false positives.
#   - Java checked via root gradle files BEFORE TypeScript (Besu has package.json
#     for tooling but is a Java project)
#   - C# restricted to ROOT-LEVEL .sln/.csproj only (prevents Go/Java repos with
#     nested vendor .csproj files from being mis-identified)
#   - Nim checked via root .nimble file (uncommon; checked before falling through)
detect_language() {
  local dir="$1"

  # Rust: Cargo.toml at root
  [[ -f "$dir/Cargo.toml" ]] && { echo "Rust"; return; }

  # Go: go.mod at root
  [[ -f "$dir/go.mod" ]] && { echo "Go"; return; }

  # Java: root-level Gradle descriptor (build.gradle, build.gradle.kts,
  #        settings.gradle, settings.gradle.kts).  Checked BEFORE TypeScript
  #        because Java projects (Besu, Teku) often ship a package.json for
  #        documentation tooling / linting scripts.
  _has_gradle_root "$dir" && { echo "Java"; return; }

  # C#: root-level .sln or .csproj only — NOT recursive, to avoid false
  #     positives from vendored C# tooling inside Go/Rust repos.
  _has_csharp_root "$dir" && { echo "C#"; return; }

  # TypeScript/JS: package.json at root (checked after Java and C#)
  [[ -f "$dir/package.json" ]] && { echo "TypeScript"; return; }

  # Nim: root-level .nimble file (primary signal)
  find "$dir" -maxdepth 1 -name "*.nimble" -print -quit 2>/dev/null | grep -q . && \
    { echo "Nim"; return; }

  # Nim fallback: Makefile references nim/nimble with git submodules
  # (handles repos like nimbus-eth2 that may not have .nimble at root in shallow clone)
  if [[ -f "$dir/.gitmodules" ]] && [[ -f "$dir/Makefile" ]]; then
    if grep -qiE "^\s*(NIM |nimble |NIMFLAGS|NIM_COMMIT)" "$dir/Makefile" 2>/dev/null; then
      echo "Nim"; return
    fi
  fi

  echo "unknown"
}

# detect_build_tool: language-aware — only emit tools that make sense for the
# detected language.  Special-case extra tools (bazel, nextest, cross, ci.go)
# are probed separately after the base set.
detect_build_tool() {
  local dir="$1"
  local lang="$2"   # pass language to avoid re-detection
  local tools=()

  case "$lang" in
    Rust)
      tools+=("cargo")
      # make: many Rust projects use a Makefile as a convenience wrapper
      [[ -f "$dir/Makefile" ]] && tools+=("make")
      # cargo-nextest: check workflow files for "cargo nextest" invocation
      if grep -rq "cargo.nextest\|cargo-nextest" "$dir/.github/workflows/" 2>/dev/null; then
        tools+=("cargo-nextest")
      fi
      # cross: used for ARM cross-compilation.
      # Detect by: Cross.toml config file, or explicit "cross build"/"cross test" invocation
      # in workflows. Avoid matching 'cross-compile', 'cross-platform', etc.
      if [[ -f "$dir/Cross.toml" ]] || \
         grep -rqE "^\s*(run:.*)?cross (build|test|check)" "$dir/.github/workflows/" 2>/dev/null; then
        tools+=("cross")
      fi
      ;;
    Go)
      tools+=("go modules")
      [[ -f "$dir/Makefile" ]] && tools+=("make")
      # Geth-specific CI orchestration script
      [[ -f "$dir/build/ci.go" ]] && tools+=("build/ci.go")
      # Bazel: prysm
      if [[ -f "$dir/WORKSPACE" ]] || [[ -f "$dir/WORKSPACE.bazel" ]]; then
        # Prepend bazel — it's the primary build tool for prysm
        tools=("bazel/bazelisk" "go modules" "make")
      fi
      ;;
    Java)
      tools+=("gradle")
      ;;
    C#)
      tools+=("dotnet/msbuild")
      # cmake: used by nethermind for native library builds
      if grep -rq "cmake\|CMakeLists" "$dir/.github/workflows/" 2>/dev/null || \
         find "$dir" -maxdepth 3 -name "CMakeLists.txt" -print -quit 2>/dev/null | grep -q .; then
        tools+=("cmake")
      fi
      ;;
    TypeScript)
      # Detect actual package manager binary used, not just "npm/node"
      if [[ -f "$dir/pnpm-lock.yaml" ]]; then
        tools+=("pnpm")
      elif [[ -f "$dir/yarn.lock" ]]; then
        tools+=("yarn")
      else
        tools+=("npm")
      fi
      # tsc: TypeScript compiler — present if tsconfig.json exists
      [[ -f "$dir/tsconfig.json" ]] && tools+=("tsc")
      ;;
    Nim)
      [[ -f "$dir/Makefile" ]] && tools+=("make")
      # nimble: Nim's package manager / build tool
      find "$dir" -maxdepth 1 -name "*.nimble" -print -quit 2>/dev/null | grep -q . && \
        tools+=("nimble")
      ;;
  esac

  if [[ ${#tools[@]} -eq 0 ]]; then
    echo "unknown"
  else
    printf "%s\n" "${tools[@]}" | paste -sd, | sed "s/,/, /g"
  fi
}

# detect_lockfile: language-aware — gradle.lockfile only for Java, packages.lock.json
# only for C#, git submodule SHAs for Nim/git-submodule projects.
detect_lockfile() {
  local dir="$1"
  local lang="$2"   # pass language to gate language-specific lockfile searches
  local lockfiles=()

  case "$lang" in
    Rust)
      [[ -f "$dir/Cargo.lock" ]] && lockfiles+=("Cargo.lock")
      ;;
    Go)
      [[ -f "$dir/go.sum" ]] && lockfiles+=("go.sum")
      # Bazel WORKSPACE also acts as a dependency pin for prysm
      if [[ -f "$dir/WORKSPACE" ]] || [[ -f "$dir/WORKSPACE.bazel" ]]; then
        lockfiles+=("WORKSPACE")
      fi
      ;;
    Java)
      # gradle.lockfile may be nested under subprojects — search within depth 4
      if find "$dir" -maxdepth 4 -name "gradle.lockfile" -print -quit 2>/dev/null | grep -q .; then
        lockfiles+=("gradle.lockfile")
      fi
      ;;
    C#)
      # packages.lock.json may be nested under project dirs
      if find "$dir" -maxdepth 4 -name "packages.lock.json" -print -quit 2>/dev/null | grep -q .; then
        lockfiles+=("packages.lock.json (partial)")
      fi
      ;;
    TypeScript)
      [[ -f "$dir/pnpm-lock.yaml" ]]   && lockfiles+=("pnpm-lock.yaml")
      [[ -f "$dir/yarn.lock" ]]        && lockfiles+=("yarn.lock")
      [[ -f "$dir/package-lock.json" ]] && lockfiles+=("package-lock.json")
      ;;
    Nim)
      # Nimbus uses git submodules — the "lockfile" is the set of pinned commit SHAs
      [[ -f "$dir/.gitmodules" ]] && lockfiles+=("git submodule SHAs (.gitmodules)")
      ;;
  esac

  if [[ ${#lockfiles[@]} -eq 0 ]]; then
    echo "none"
  else
    printf "%s\n" "${lockfiles[@]}" | paste -sd, | sed "s/,/, /g"
  fi
}

# detect_package_manager: language-driven to avoid false positives from auxiliary
# package.json files in Java/C# repos.
detect_package_manager() {
  local dir="$1"
  local lang="$2"

  case "$lang" in
    Rust)        echo "cargo" ;;
    Go)          echo "go-modules" ;;
    Java)        echo "gradle/maven-central" ;;
    C#)          echo "nuget" ;;
    TypeScript)
      # Distinguish pnpm / yarn / npm by lockfile presence
      [[ -f "$dir/pnpm-lock.yaml" ]]    && { echo "pnpm"; return; }
      [[ -f "$dir/yarn.lock" ]]         && { echo "yarn"; return; }
      echo "npm"
      ;;
    Nim)
      # Nimbus-eth2 uses git submodules, not a package registry
      [[ -f "$dir/.gitmodules" ]] && { echo "git-submodules"; return; }
      echo "nimble"
      ;;
    *)           echo "unknown" ;;
  esac
}

detect_docker() {
  local dir="$1"
  # Search up to depth 3 to find Dockerfiles in subdirectories (e.g. docker/Dockerfile)
  find "$dir" -maxdepth 3 -name "Dockerfile*" -print -quit 2>/dev/null | grep -q . \
    && echo "true" || echo "false"
}

detect_docker_registry() {
  local dir="$1"
  local wf_dir="$dir/.github/workflows"
  local registries=()

  if [[ -d "$wf_dir" ]]; then
    # GHCR: explicit ghcr.io references
    grep -rq "ghcr\.io" "$wf_dir" 2>/dev/null && registries+=("ghcr.io")

    # GCR: explicit gcr.io references
    grep -rq "gcr\.io" "$wf_dir" 2>/dev/null && registries+=("gcr.io")

    # Docker Hub: explicit docker.io, hub.docker.com, or dockerhub credential vars
    # (DOCKERHUB_TOKEN, DOCKER_HUB_TOKEN, DOCKERHUB_USERNAME, docker/login-action
    #  with no registry: param — which defaults to Docker Hub)
    if grep -rqE \
         "docker\.io|hub\.docker\.com|DOCKERHUB_|DOCKER_HUB_|docker/login-action" \
         "$wf_dir" 2>/dev/null; then
      # Only add docker-hub if ghcr.io / gcr.io are NOT already the sole registry
      # (some repos push to both; if the workflow also has a docker push without a
      #  non-hub registry prefix it goes to Docker Hub)
      registries+=("docker-hub")
    fi
  fi

  if [[ ${#registries[@]} -eq 0 ]]; then
    echo "unknown"
  else
    printf "%s\n" "${registries[@]}" | paste -sd, | sed "s/,/, /g"
  fi
}

detect_bazel() {
  local dir="$1"
  { [[ -f "$dir/WORKSPACE" ]] || [[ -f "$dir/WORKSPACE.bazel" ]]; } \
    && echo "true" || echo "false"
}

# ─── Main collection loop ─────────────────────────────────────────────────────

collect_client_data() {
  local name="$1"
  local dir="$CLONE_DIR/$name"
  local out="$OUTPUT_DIR/${name}.json"

  log "Analyzing $name..."

  local language ci_platform workflow_count build_tools lockfile \
        package_manager docker_support docker_registry uses_bazel

  language=$(detect_language "$dir")
  ci_platform=$(detect_ci_platform "$dir")
  workflow_count=$(count_workflows "$dir")
  build_tools=$(detect_build_tool "$dir" "$language")
  lockfile=$(detect_lockfile "$dir" "$language")
  package_manager=$(detect_package_manager "$dir" "$language")
  docker_support=$(detect_docker "$dir")
  docker_registry=$(detect_docker_registry "$dir")
  uses_bazel=$(detect_bazel "$dir")

  jq -n \
    --arg name "$name" \
    --arg repo "${CLIENT_REPOS[$name]}" \
    --arg language "$language" \
    --arg ci_platform "$ci_platform" \
    --argjson workflow_count "$workflow_count" \
    --arg build_tools "$build_tools" \
    --arg lockfile "$lockfile" \
    --arg package_manager "$package_manager" \
    --arg docker_support "$docker_support" \
    --arg docker_registry "$docker_registry" \
    --arg uses_bazel "$uses_bazel" \
    '{
      name: $name,
      repo: $repo,
      language: $language,
      ci_platform: $ci_platform,
      workflow_count: $workflow_count,
      build_tools: $build_tools,
      lockfile: $lockfile,
      package_manager: $package_manager,
      docker_support: $docker_support,
      docker_registry: $docker_registry,
      uses_bazel: $uses_bazel,
      collected_at: (now | todate)
    }' > "$out"

  log "  → Saved to $out"
}

generate_csv() {
  local raw_dir="$OUTPUT_DIR"
  local csv_file="$REPO_ROOT/data/comparison_matrix_generated.csv"

  log "Generating CSV from collected data..."

  echo "client,language,ci_platform,workflow_count,build_tools,package_manager,lockfile,docker_support,docker_registry,uses_bazel" > "$csv_file"

  for name in "${!CLIENT_REPOS[@]}"; do
    local json_file="$raw_dir/${name}.json"
    if [[ -f "$json_file" ]]; then
      jq -r '[.name, .language, .ci_platform, (.workflow_count | tostring),
              .build_tools, .package_manager, .lockfile,
              .docker_support, .docker_registry, .uses_bazel] | @csv' \
        "$json_file" >> "$csv_file"
    fi
  done

  log "CSV saved to: $csv_file"
}

# ─── Entry point ──────────────────────────────────────────────────────────────

main() {
  local target_client=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --client) target_client="$2"; shift 2 ;;
      --output) OUTPUT_DIR="$2"; shift 2 ;;
      --help|-h)
        echo "Usage: $0 [--client <name>] [--output <dir>]"
        echo "  --client  Collect only for this client (default: all)"
        echo "  --output  Output directory for raw JSON (default: data/raw)"
        exit 0
        ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  check_deps
  mkdir -p "$OUTPUT_DIR" "$CLONE_DIR"

  if [[ -n "$target_client" ]]; then
    [[ -n "${CLIENT_REPOS[$target_client]+x}" ]] || die "Unknown client: $target_client"
    clone_or_update "$target_client" "${CLIENT_REPOS[$target_client]}"
    collect_client_data "$target_client"
  else
    for name in "${!CLIENT_REPOS[@]}"; do
      clone_or_update "$name" "${CLIENT_REPOS[$name]}"
      collect_client_data "$name"
    done
  fi

  generate_csv
  log "Done. Raw data in: $OUTPUT_DIR"
}

main "$@"
