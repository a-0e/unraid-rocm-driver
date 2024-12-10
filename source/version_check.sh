#!/bin/bash
set -e

CURRENT_VERSION="6.0.2"
REPOS=(
    "RadeonOpenCompute/ROCT-Thunk-Interface"
    "RadeonOpenCompute/ROCR-Runtime"
    "ROCm-Developer-Tools/ROCclr"
    "ROCm-Developer-Tools/OpenCL-SDK"
)

for repo in "${REPOS[@]}"; do
    echo "Checking $repo..."
    if ! curl -sSf "https://github.com/${repo}/tree/rocm-${CURRENT_VERSION}" >/dev/null 2>&1; then
        echo "Warning: Branch rocm-${CURRENT_VERSION} not found in $repo"
    fi
done