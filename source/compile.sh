#!/bin/bash
set -ex

# Source versions from central config
source <(grep ROCM_VERSION source/versions.yml | sed 's/version:/ROCM_VERSION=/')
BUILD_DIR="/tmp/rocm-build"
INSTALL_DIR="/usr/local"
PLUGIN_VERSION=$(date +'%Y.%m.%d')

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
    DESTDIR=./install make install
    cd ../..

    # Build ROCR Runtime
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCR-Runtime.git
    cd ROCR-Runtime/src
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    DESTDIR=./install make install
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
    cd ROCclr
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    DESTDIR=./install make install
    cd ../..

    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/OpenCL-SDK.git || {
        echo "Warning: Falling back to master branch for OpenCL-SDK"
        git clone --depth 1 https://github.com/ROCm-Developer-Tools/OpenCL-SDK.git
    }
    cd OpenCL-SDK
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    DESTDIR=./install make install
    cd ../..

    # Create final Slackware package
    mkdir -p pkg/usr/local
    cp -r */build/install/usr/local/* pkg/usr/local/
    cd pkg
    makepkg -l y -c y "$BUILD_DIR/rocm-${ROCM_VERSION}.txz"
    cd ..
    md5sum "rocm-${ROCM_VERSION}.txz" > "rocm-${ROCM_VERSION}.txz.md5"
}

build_rocm