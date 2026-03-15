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

detect_ci_platform() {
  local dir="$1"
  local platforms=()

  [[ -d "$dir/.github/workflows" ]] && platforms+=("github-actions")
  # Only add if Jenkinsfile actually exists
  if [[ -f "$dir/Jenkinsfile" ]] || find "$dir" -maxdepth 2 -name "Jenkinsfile" | grep -q .; then
    platforms+=("jenkins")
  fi
  #[[ -f "$dir/Jenkinsfile" ]] || find "$dir" -maxdepth 2 -name "Jenkinsfile" -quit 2>/dev/null \
  #  && platforms+=("jenkins")
  [[ -f "$dir/.travis.yml" ]] && platforms+=("travis-ci")
  [[ -f "$dir/.circleci/config.yml" ]] && platforms+=("circleci")
  [[ -f "$dir/.gitlab-ci.yml" ]] && platforms+=("gitlab-ci")
  [[ -f "$dir/azure-pipelines.yml" ]] && platforms+=("azure-pipelines")
  [[ -f "$dir/buildkite.yml" ]] || [[ -d "$dir/.buildkite" ]] && platforms+=("buildkite")

  if [[ ${#platforms[@]} -eq 0 ]]; then
    echo "unknown"
  else
    IFS=',' echo "${platforms[*]}"
  fi
}

count_workflows() {
  local dir="$1"
  local wf_dir="$dir/.github/workflows"
  if [[ -d "$wf_dir" ]]; then
    find "$wf_dir" -name "*.yml" -o -name "*.yaml" | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

#detect_build_tool() {
#  local dir="$1"
#  local tools=()

 # [[ -f "$dir/Cargo.toml" ]] && tools+=("cargo")
  #[[ -f "$dir/go.mod" ]] && tools+=("go-modules")
  #[[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]] && tools+=("gradle")
  #[[ -f "$dir/pom.xml" ]] && tools+=("maven")
  #[[ -f "$dir/package.json" ]] && tools+=("npm/node")
  # Fix for dotnet
  #if find "$dir" -maxdepth 2 -name "*.csproj" | grep -q .; then
  #  tools+=("dotnet")
  #fi

  # Fix for nimble
  #if ls "$dir"/*.nimble 2>/dev/null | grep -q .; then
   # tools+=("nimble")
  #fi
  #[[ -f "$dir/*.sln" ]] || find "$dir" -maxdepth 2 -name "*.csproj" -quit 2>/dev/null \
  #  && tools+=("dotnet")
  #[[ -f "$dir/WORKSPACE" ]] || [[ -f "$dir/WORKSPACE.bazel" ]] && tools+=("bazel")
  #[[ -f "$dir/Makefile" ]] && tools+=("make")
  #find "$dir" -maxdepth 1 -name "*.nimble" -quit 2>/dev/null && tools+=("nimble")

  #if [[ ${#tools[@]} -eq 0 ]]; then
  #  echo "unknown"
  #else
  #  printf '%s\n' "${tools[@]}" | paste -sd',' -
  #fi
#}


detect_build_tool() {
  local dir="$1"
  local tools=()
  local language

  language=$(detect_language "$dir")

  [[ -f "$dir/Cargo.toml" ]] && tools+=("cargo")
  [[ -f "$dir/go.mod" ]] && tools+=("go-modules")
  [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]] && tools+=("gradle")
  [[ -f "$dir/pom.xml" ]] && tools+=("maven")
  [[ -f "$dir/package.json" ]] && tools+=("npm/node")
  [[ -f "$dir/Makefile" ]] && tools+=("make")
  
  # Only add language-specific tools if that language is detected
  if [[ "$language" == "C#" ]] && ([[ -f "$dir/*.sln" ]] || find "$dir" -maxdepth 2 -name "*.csproj" | grep -q .); then
    tools+=("dotnet")
  fi
  
  if [[ "$language" == "Nim" ]] && ls "$dir"/*.nimble 2>/dev/null | grep -q .; then
    tools+=("nimble")
  fi
  
  [[ -f "$dir/WORKSPACE" ]] || [[ -f "$dir/WORKSPACE.bazel" ]] && tools+=("bazel")

  if [[ ${#tools[@]} -eq 0 ]]; then
    echo "unknown"
  else
    printf '%s\n' "${tools[@]}" | paste -sd',' -
  fi
}


#detect_lockfile() {
#  local dir="$1"
#  local lockfiles=()

 # [[ -f "$dir/Cargo.lock" ]] && lockfiles+=("Cargo.lock")
 # [[ -f "$dir/go.sum" ]] && lockfiles+=("go.sum")
 # [[ -f "$dir/pnpm-lock.yaml" ]] && lockfiles+=("pnpm-lock.yaml")
 # [[ -f "$dir/yarn.lock" ]] && lockfiles+=("yarn.lock")
 # [[ -f "$dir/package-lock.json" ]] && lockfiles+=("package-lock.json")
  # Only root directory for most lockfiles
 # [[ -f "$dir/gradle.lockfile" ]] && lockfiles+=("gradle.lockfile")
  # Or limit depth
  #find "$dir" -maxdepth 3 -name "gradle.lockfile" -quit 2>/dev/null && lockfiles+=("gradle.lockfile") 
  #find "$dir" -name "gradle.lockfile" -quit 2>/dev/null && lockfiles+=("gradle.lockfile")
  #find "$dir" -name "packages.lock.json" -quit 2>/dev/null && lockfiles+=("packages.lock.json")

 # if [[ ${#lockfiles[@]} -eq 0 ]]; then
  #  echo "none"
  #else
   # printf '%s\n' "${lockfiles[@]}" | paste -sd',' -
  #fi
#}

detect_lockfile() {
  local dir="$1"
  local lockfiles=()
  local language

  language=$(detect_language "$dir")

  [[ -f "$dir/Cargo.lock" ]] && lockfiles+=("Cargo.lock")
  [[ -f "$dir/go.sum" ]] && lockfiles+=("go.sum")
  [[ -f "$dir/pnpm-lock.yaml" ]] && lockfiles+=("pnpm-lock.yaml")
  [[ -f "$dir/yarn.lock" ]] && lockfiles+=("yarn.lock")
  [[ -f "$dir/package-lock.json" ]] && lockfiles+=("package-lock.json")
  
  # Java projects - look for gradle.lockfile in root or subdirs
  if [[ "$language" == "Java" ]]; then
    if [[ -f "$dir/gradle.lockfile" ]] || find "$dir" -maxdepth 2 -name "gradle.lockfile" | grep -q .; then
      lockfiles+=("gradle.lockfile")
    fi
  fi
  # C# projects - look for packages.lock.json
  if [[ "$language" == "C#" ]]; then
    if [[ -f "$dir/packages.lock.json" ]] || find "$dir" -maxdepth 2 -name "packages.lock.json" | grep -q .; then
      lockfiles+=("packages.lock.json")
    fi
  fi

  if [[ ${#lockfiles[@]} -eq 0 ]]; then
    echo "none"
  else
    printf '%s\n' "${lockfiles[@]}" | paste -sd',' -
  fi
}


detect_language() {
  local dir="$1"

  [[ -f "$dir/Cargo.toml" ]] && { echo "Rust"; return; }
  [[ -f "$dir/go.mod" ]] && { echo "Go"; return; }
  
  # Java check - do this BEFORE Nim
  if [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]] || [[ -f "$dir/pom.xml" ]]; then
    echo "Java"; return;
  fi
  
  # C# check
  if ls "$dir"/*.csproj 2>/dev/null | grep -q .; then
    echo "C#"; return;
  fi
  
  [[ -f "$dir/package.json" ]] && { echo "TypeScript"; return; }
  
  # Nim check - only if no other language detected
  if ls "$dir"/*.nimble 2>/dev/null | grep -q .; then
    echo "Nim"; return;
  fi
  
  echo "unknown"
}

detect_docker() {
  local dir="$1"
  find "$dir" -maxdepth 2 -name "Dockerfile*" | head -1 | grep -q . && echo "true" || echo "false"
}

detect_docker_registry() {
  local dir="$1"
  local wf_dir="$dir/.github/workflows"
  local registries=()

  if [[ -d "$wf_dir" ]]; then
    grep -rl "ghcr.io" "$wf_dir" 2>/dev/null | head -1 | grep -q . && registries+=("ghcr.io")
    grep -rl "docker.io\|docker push\|dockerhub" "$wf_dir" 2>/dev/null | head -1 | grep -q . && registries+=("docker-hub")
    grep -rl "gcr.io" "$wf_dir" 2>/dev/null | head -1 | grep -q . && registries+=("gcr.io")
  fi

  [[ ${#registries[@]} -eq 0 ]] && registries+=("unknown")
  printf '%s\n' "${registries[@]}" | paste -sd',' -
}

detect_package_manager() {
  local dir="$1"

  [[ -f "$dir/pnpm-lock.yaml" ]] && { echo "pnpm"; return; }
  [[ -f "$dir/yarn.lock" ]] && { echo "yarn"; return; }
  [[ -f "$dir/package-lock.json" ]] && { echo "npm"; return; }
  [[ -f "$dir/Cargo.toml" ]] && { echo "cargo"; return; }
  [[ -f "$dir/go.mod" ]] && { echo "go-modules"; return; }
  [[ -f "$dir/build.gradle" ]] && { echo "gradle"; return; }
  [[ -f "$dir/.gitmodules" ]] && { echo "git-submodules"; return; }
  find "$dir" -maxdepth 2 -name "*.csproj" -quit 2>/dev/null && { echo "nuget"; return; }
  find "$dir" -maxdepth 1 -name "*.nimble" -quit 2>/dev/null && { echo "nimble"; return; }

  # Check for git submodules (Nimbus)
  [[ -f "$dir/.gitmodules" ]] && { echo "git-submodules"; return; }

  echo "unknown"
}

detect_bazel() {
  local dir="$1"
  [[ -f "$dir/WORKSPACE" ]] || [[ -f "$dir/WORKSPACE.bazel" ]] && echo "true" || echo "false"
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
  build_tools=$(detect_build_tool "$dir")
  lockfile=$(detect_lockfile "$dir")
  package_manager=$(detect_package_manager "$dir")
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
