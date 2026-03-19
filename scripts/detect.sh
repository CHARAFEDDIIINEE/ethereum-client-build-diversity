#!/bin/bash

# Configuration
CLIENTS_DIR="C:\Users\chrfd\ethereum-client-build-diversity\scripts\ethereum-clients" # Directory containing Ethereum client repositories (When using this script, ensure you have cloned the client repos into this directory with the correct names)
OUTPUT_FILE="detection_results_v2.md"

# Client list
clients=(
    "lighthouse"
    "prysm"
    "teku"
    "nimbus"
    "lodestar"
    "grandine"
    "geth"
    "nethermind"
    "besu"
    "erigon"
    "reth"
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize results file
echo "# Build Provenance Techniques Detection Results (v2 - Precise Detection)" > $OUTPUT_FILE
echo "Generated: $(date)" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "| Client | Sigstore | SLSA | Reproducible Builds | pNPM | Bazel | Kurtosis | PGP | Geth Rebuild | Other Techniques |" >> $OUTPUT_FILE
echo "|--------|----------|------|---------------------|------|-------|----------|-----|--------------|------------------|" >> $OUTPUT_FILE

# Function to check for techniques in a client
check_client() {
    local client=$1
    local client_path="$CLIENTS_DIR/$client"
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Analyzing $client...${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ ! -d "$client_path" ]; then
        echo -e "${RED}  ❌ Client directory not found: $client_path${NC}"
        return
    fi
    
    cd "$client_path" || return
    
    # Initialize flags
    local sigstore="❌ No"
    local slsa="❌ No"
    local reproducible="❌ No"
    local pnpm="❌ No"
    local bazel="❌ No"
    local kurtosis="❌ No"
    local pgp="❌ No"
    local geth_rebuild="❌ No"
    local other=""
    
    # 1. SIGSTORE - Look for actual cosign commands and installers
    echo -e "\n${YELLOW}🔍 Checking Sigstore/Cosign...${NC}"
    
    # Check for cosign installer action
    if grep -r "sigstore/cosign-installer" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Cosign installer found (Sigstore)${NC}"
        sigstore="✅ Yes (cosign-installer)"
        other="$other Sigstore"
    # Check for cosign sign commands
    elif grep -r "cosign sign" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Cosign sign command found${NC}"
        sigstore="✅ Yes (cosign sign)"
        other="$other Sigstore"
    # Check for .sigstore files
    elif find . -name "*.sigstore" 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ .sigstore files found${NC}"
        sigstore="✅ Yes (.sigstore files)"
        other="$other Sigstore"
    else
        echo -e "  ❌ No Sigstore implementation found"
    fi
    
    # 2. SLSA - Look for actual SLSA provenance generation
    echo -e "\n${YELLOW}🔍 Checking SLSA/Provenance...${NC}"
    
    # Check for SLSA generator workflow
    if grep -r "slsa-framework/slsa-github-generator" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ SLSA generator found${NC}"
        slsa="✅ Yes (SLSA generator)"
        other="$other SLSA"
    # Check for attest command
    elif grep -r "cosign attest" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Cosign attest found (SLSA provenance)${NC}"
        slsa="✅ Yes (cosign attest)"
        other="$other SLSA"
    # Check for provenance.json generation
    elif grep -r "provenance.json" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Provenance file generation found${NC}"
        slsa="✅ Yes (provenance.json)"
        other="$other SLSA"
    else
        echo -e "  ❌ No SLSA implementation found"
    fi
    
    # 3. REPRODUCIBLE BUILDS - Look for specific indicators
    echo -e "\n${YELLOW}🔍 Checking Reproducible Builds...${NC}"
    
    # Check for explicit reproducible build documentation or workflows
    if [ -f "Dockerfile.reproducible" ] || [ -f "reproducible-builds.md" ]; then
        echo -e "${GREEN}  ✅ Reproducible build files found${NC}"
        reproducible="✅ Yes (explicit files)"
    elif grep -r "SOURCE_DATE_EPOCH" --include="*.yml" --include="*.sh" --include="Dockerfile*" . 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ SOURCE_DATE_EPOCH found (reproducible builds)${NC}"
        reproducible="✅ Yes (SOURCE_DATE_EPOCH)"
    elif grep -r "reproducible builds" --include="*.md" . 2>/dev/null | grep -q .; then
        # Only count if it's in a README or documentation, not just any mention
        if grep -r "reproducible builds" README.md 2>/dev/null | grep -q .; then
            echo -e "${GREEN}  ✅ Reproducible builds documented${NC}"
            reproducible="✅ Yes (documented)"
        else
            echo -e "  ⚠️  Reproducible builds mentioned (non-README)"
        fi
    else
        # Check for lockfiles as minimal indicator
        if [ -f "Cargo.lock" ] || [ -f "go.sum" ] || [ -f "pnpm-lock.yaml" ] || [ -f "gradle.lockfile" ]; then
            echo -e "${YELLOW}  ⚠️  Lockfile present (basic reproducibility)${NC}"
            reproducible="⚠️ Lockfile only"
        else
            echo -e "  ❌ No reproducible build indicators"
        fi
    fi
    
    # 4. pNPM - Look for actual pnpm usage
    echo -e "\n${YELLOW}🔍 Checking pNPM...${NC}"
    
    if [ -f "pnpm-lock.yaml" ] && [ -f "pnpm-workspace.yaml" ]; then
        echo -e "${GREEN}  ✅ pnpm workspace + lockfile found${NC}"
        pnpm="✅ Yes (pnpm workspace)"
        other="$other pNPM"
    elif [ -f "pnpm-lock.yaml" ]; then
        echo -e "${GREEN}  ✅ pnpm lockfile found${NC}"
        pnpm="✅ Yes (pnpm-lock.yaml)"
        other="$other pNPM"
    elif grep -r "pnpm install" --include="*.yml" --include="*.yaml" --include="*.md" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ pnpm install in CI${NC}"
        pnpm="✅ Yes (pnpm in CI)"
        other="$other pNPM"
    else
        echo -e "  ❌ No pnpm found"
    fi
    
    # 5. BAZEL - Look for actual Bazel files
    echo -e "\n${YELLOW}🔍 Checking Bazel...${NC}"
    
    if [ -f "WORKSPACE" ] && [ -f "BUILD.bazel" ]; then
        echo -e "${GREEN}  ✅ Bazel workspace + build files found${NC}"
        bazel="✅ Yes (WORKSPACE + BUILD)"
        other="$other Bazel"
    elif [ -f "WORKSPACE" ] || [ -f "WORKSPACE.bazel" ]; then
        echo -e "${GREEN}  ✅ Bazel WORKSPACE found${NC}"
        bazel="✅ Yes (WORKSPACE)"
        other="$other Bazel"
    elif grep -r "bazel build" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Bazel build in CI${NC}"
        bazel="✅ Yes (bazel build)"
        other="$other Bazel"
    else
        echo -e "  ❌ No Bazel found"
    fi
    
    # 6. KURTOSIS - Look for actual Kurtosis usage
    echo -e "\n${YELLOW}🔍 Checking Kurtosis/Assertoor...${NC}"
    
    if [ -f "kurtosis.yml" ] || [ -f "kurtosis-config.yml" ]; then
        echo -e "${GREEN}  ✅ Kurtosis config files found${NC}"
        kurtosis="✅ Yes (kurtosis.yml)"
        other="$other Kurtosis"
    elif grep -r "kurtosis run" --include="*.yml" --include="*.yaml" --include="*.sh" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Kurtosis run commands found${NC}"
        kurtosis="✅ Yes (kurtosis run)"
        other="$other Kurtosis"
    elif grep -r "assertoor" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Assertoor found (Kurtosis testing)${NC}"
        kurtosis="✅ Yes (Assertoor)"
        other="$other Kurtosis"
    else
        echo -e "  ❌ No Kurtosis found"
    fi
    
    # 7. PGP SIGNATURES - Look for actual signing
    echo -e "\n${YELLOW}🔍 Checking PGP signatures...${NC}"
    
    if [ -f "SHA256SUMS.asc" ] || [ -f "SHA256SUMS.sig" ] || [ -f "checksums.txt.asc" ]; then
        echo -e "${GREEN}  ✅ PGP signature files found${NC}"
        pgp="✅ Yes (signature files)"
    elif grep -r "gpg --sign" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ GPG signing in CI${NC}"
        pgp="✅ Yes (GPG in workflows)"
    elif grep -r "cosign sign" --include="*.yml" --include="*.yaml" .github/workflows/ 2>/dev/null | grep -q .; then
        echo -e "${GREEN}  ✅ Cosign signing (keyless)${NC}"
        pgp="✅ Yes (cosign - keyless)"
    else
        echo -e "  ⚠️  No PGP signatures found in repo"
    fi
    
    # 8. GETH REBUILD - Specific to Geth
    if [ "$client" = "go-ethereum" ]; then
        echo -e "\n${YELLOW}🔍 Checking for Geth Rebuild...${NC}"
        
        if grep -r "geth-rebuild" --include="*.md" . 2>/dev/null | grep -q .; then
            echo -e "${GREEN}  ✅ Geth Rebuild referenced${NC}"
            geth_rebuild="✅ Yes (referenced)"
            other="$other Geth-Rebuild"
        elif [ -f "rebuild.sh" ] || [ -f "verify-rebuild.sh" ]; then
            echo -e "${GREEN}  ✅ Rebuild scripts found${NC}"
            geth_rebuild="✅ Yes (rebuild scripts)"
            other="$other Geth-Rebuild"
        else
            echo -e "  ⚠️  No Geth Rebuild found (external tool)"
        fi
    fi
    
    # Add to results table
    echo "| $client | $sigstore | $slsa | $reproducible | $pnpm | $bazel | $kurtosis | $pgp | $geth_rebuild | $other |" >> "$OLDPWD/$OUTPUT_FILE"
    
    cd - > /dev/null
}

# Main execution
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 BUILD PROVENANCE TECHNIQUES DETECTION v2${NC}"
echo -e "${BLUE}========================================${NC}"

for client in "${clients[@]}"; do
    check_client "$client"
done

echo -e "\n${GREEN}✅ Detection complete! Results saved to: $OUTPUT_FILE${NC}"