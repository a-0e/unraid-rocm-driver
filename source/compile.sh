#!/bin/bash
set -ex

# Source versions from central config
source <(grep ROCM_VERSION source/versions.yml | sed 's/version:/ROCM_VERSION=/')
BUILD_DIR="/tmp/rocm-build"
INSTALL_DIR="/usr/local"
WORKSPACE_DIR="${BUILD_DIR}/workspace"

function build_rocm() {
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"

    # Initialize repo tool for ROCm source
    ~/bin/repo init -u https://github.com/ROCm/ROCm.git -b roc-${ROCM_VERSION}.x -m tools/rocm-build/rocm-${ROCM_VERSION}.xml
    ~/bin/repo sync

    # Build core components
    make -f ROCm/tools/rocm-build/ROCm.mk -j $(nproc) rocm-core
    
    # Build runtime components with all architectures
    AMDGPU_TARGETS="${GPU_ARCHS}" make -f ROCm/tools/rocm-build/ROCm.mk -j $(nproc) rocm-runtime
    
    # Create final package
    mkdir -p "$BUILD_DIR/pkg/usr/local"
    cp -r out/*/deb/* "$BUILD_DIR/pkg/"
    cd "$BUILD_DIR/pkg"
    makepkg -l y -c y "$BUILD_DIR/rocm-${ROCM_VERSION}.txz"
    cd ..
    md5sum "rocm-${ROCM_VERSION}.txz" > "rocm-${ROCM_VERSION}.txz.md5"
}

build_rocm