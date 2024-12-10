#!/bin/bash
set -ex

ROCM_VERSION="6.0.2"
BUILD_DIR="/tmp/rocm-build"
INSTALL_DIR="/usr/local"

# Ensure we're running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

function build_rocm() {
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Build ROCT-Thunk-Interface
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git
    cd ROCT-Thunk-Interface
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    make package
    cd ../..

    # Build ROCR Runtime
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCR-Runtime.git
    cd ROCR-Runtime/src
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    make package
    cd ../../..

    # ROCclr and OpenCL-SDK with fallback version checking
    ROCCLR_BRANCH=$(git ls-remote --heads https://github.com/ROCm-Developer-Tools/ROCclr.git "refs/heads/rocm-${ROCM_VERSION}" | cut -f2)
    if [ -z "$ROCCLR_BRANCH" ]; then
        echo "Warning: Branch rocm-${ROCM_VERSION} not found for ROCclr, checking for alternatives..."
        ROCCLR_BRANCH=$(git ls-remote --tags https://github.com/ROCm-Developer-Tools/ROCclr.git "refs/tags/rocm-${ROCM_VERSION}" | cut -f2)
        if [ -z "$ROCCLR_BRANCH" ]; then
            echo "Error: No matching ROCclr version found"
            exit 1
        fi
    fi
    
    git clone --depth 1 -b ${ROCCLR_BRANCH#refs/heads/} https://github.com/ROCm-Developer-Tools/ROCclr.git
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/OpenCL-SDK.git || {
        echo "Warning: Falling back to master branch for OpenCL-SDK"
        git clone --depth 1 https://github.com/ROCm-Developer-Tools/OpenCL-SDK.git
    }
}

build_rocm