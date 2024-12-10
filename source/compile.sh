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

    # Clone main ROCm repository
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCm.git
    cd ROCm

    # Build components directly
    # ROCT-Thunk-Interface (HSA Runtime)
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git
    cd ROCT-Thunk-Interface
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    DESTDIR=./install make install
    cd ../..

    # ROCR Runtime
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCR-Runtime.git
    cd ROCR-Runtime/src
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
          -DAMDGPU_TARGET_TRIPLE="${GPU_ARCHS}" ..
    make -j$(nproc)
    DESTDIR=./install make install
    cd ../../..

    # ROCm OpenCL Runtime
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/ROCclr.git
    cd ROCclr
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
          -DAMDGPU_TARGET_TRIPLE="${GPU_ARCHS}" ..
    make -j$(nproc)
    DESTDIR=./install make install
    cd ../..

    # Create final package
    mkdir -p "$BUILD_DIR/pkg/usr/local"
    find . -path "*/install/usr/local/*" -exec cp -r {} "$BUILD_DIR/pkg/usr/local/" \;
    cd "$BUILD_DIR/pkg"
    makepkg -l y -c y "$BUILD_DIR/rocm-${ROCM_VERSION}.txz"
    cd ..
    md5sum "rocm-${ROCM_VERSION}.txz" > "rocm-${ROCM_VERSION}.txz.md5"
}

build_rocm