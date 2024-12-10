#!/bin/bash
set -ex

ROCM_VERSION=${ROCM_VERSION:-"6.0.2"}
BUILD_DIR=${BUILD_DIR:-"/tmp/rocm-build"}
INSTALL_DIR=${INSTALL_DIR:-"/usr/local"}

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ROCT-Thunk-Interface
git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface.git
cd ROCT-Thunk-Interface
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
make -j$(nproc)
make package
cd ../..

# ROCR-Runtime
git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/RadeonOpenCompute/ROCR-Runtime.git
cd ROCR-Runtime/src
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
make -j$(nproc)
make package
cd ../../..

# ROCclr and OpenCL-SDK
git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/ROCclr.git
git clone --depth 1 -b rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/OpenCL-SDK.git
cd OpenCL-SDK
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR ..
make -j$(nproc)
make package

# Package all built components
mkdir -p $BUILD_DIR/pkg/usr/local/{lib,include,bin}
cp -r */build/*.deb $BUILD_DIR/pkg/
cd $BUILD_DIR/pkg
for deb in *.deb; do
    dpkg-deb -x "$deb" ./
done

# Create final package
cd $BUILD_DIR
makepkg -l y -c y "../rocm-${ROCM_VERSION}.txz"
md5sum "../rocm-${ROCM_VERSION}.txz" > "../rocm-${ROCM_VERSION}.txz.md5"