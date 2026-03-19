# Build Provenance Techniques Detection Results (v2 - Precise Detection)
Generated: Thu Mar 19 23:02:24 WCAST 2026

| Client | Sigstore | SLSA | Reproducible Builds | pNPM | Bazel | Kurtosis | PGP | Geth Rebuild | Other Techniques |
|--------|----------|------|---------------------|------|-------|----------|-----|--------------|------------------|
| lighthouse | ❌ No | ❌ No | ✅ Yes (explicit files) | ❌ No | ❌ No | ✅ Yes (Assertoor) | ❌ No | ❌ No |  Kurtosis |
| prysm | ❌ No | ❌ No | ⚠️ Lockfile only | ❌ No | ✅ Yes (WORKSPACE + BUILD) | ❌ No | ❌ No | ❌ No |  Bazel |
| teku | ✅ Yes (cosign-installer) | ✅ Yes (cosign attest) | ❌ No | ❌ No | ❌ No | ❌ No | ✅ Yes (cosign - keyless) | ❌ No |  Sigstore SLSA |
| nimbus | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |  |
| lodestar | ❌ No | ❌ No | ⚠️ Lockfile only | ✅ Yes (pnpm workspace) | ❌ No | ✅ Yes (Assertoor) | ❌ No | ❌ No |  pNPM Kurtosis |
| grandine | ❌ No | ❌ No | ⚠️ Lockfile only | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |  |
| geth | ❌ No | ❌ No | ⚠️ Lockfile only | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |  |
| nethermind | ❌ No | ❌ No | ✅ Yes (SOURCE_DATE_EPOCH) | ✅ Yes (pnpm in CI) | ❌ No | ✅ Yes (Assertoor) | ❌ No | ❌ No |  pNPM Kurtosis |
| besu | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No | ❌ No |  |
| erigon | ❌ No | ❌ No | ⚠️ Lockfile only | ❌ No | ❌ No | ✅ Yes (Assertoor) | ❌ No | ❌ No |  Kurtosis |
| reth | ❌ No | ❌ No | ✅ Yes (explicit files) | ❌ No | ❌ No | ✅ Yes (Assertoor) | ❌ No | ❌ No |  Kurtosis |
