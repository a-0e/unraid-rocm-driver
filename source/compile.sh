#!/bin/bash
ROCM_VERSION="6.0.2"
BUILD_DIR="/tmp/rocm-build"
INSTALL_DIR="/usr/local"

function build_rocm() {
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    apt-get update && apt-get install -y \
        cmake \
        pkg-config \
        libpci-dev \
        libdrm-dev \
        libssl-dev \
        python3-dev \
        build-essential \
        git
    
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git
    cd ROCT-Thunk-Interface
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    make package
    cd ../..

    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCR-Runtime.git
    cd ROCR-Runtime/src
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    make package
    cd ../../..

    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/ROCclr.git
    git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/OpenCL-SDK.git
    cd OpenCL-SDK
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
    make -j$(nproc)
    make package
    cd ../..
}

function create_package() {
    cd "$BUILD_DIR"
    mkdir -p pkg/usr/local/{lib,include,bin}
    
    cp -r ROCT-Thunk-Interface/build/*.deb pkg/
    cp -r ROCR-Runtime/src/build/*.deb pkg/
    cp -r OpenCL-SDK/build/*.deb pkg/
    
    cd pkg
    for deb in *.deb; do
        dpkg-deb -x "$deb" ./
    done
    
    cd ..
    makepkg -l y -c y "../rocm-${ROCM_VERSION}.txz"
    md5sum "../rocm-${ROCM_VERSION}.txz" > "../rocm-${ROCM_VERSION}.txz.md5"
}

build_rocm
create_package