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

mkdir -p $BUILD_DIR/pkg/usr/local/{lib,include,bin}
cp -r */build/*.deb $BUILD_DIR/pkg/
cd $BUILD_DIR/pkg
for deb in *.deb; do
    dpkg-deb -x "$deb" ./
done

# Download and verify AMDGPU package
echo "Checking available AMDGPU packages..."
# First try versioned repository
AMDGPU_BASE_URL="https://repo.radeon.com/amdgpu/${ROCM_VERSION}/ubuntu/pool/main/a/amdgpu-install"
AMDGPU_DEB="amdgpu-install_${ROCM_VERSION}.60401-1_all.deb"

# If versioned fails, try latest
if ! wget -q --spider "${AMDGPU_BASE_URL}/${AMDGPU_DEB}" 2>/dev/null; then
    echo "Checking latest repository..."
    AMDGPU_BASE_URL="https://repo.radeon.com/amdgpu/latest/ubuntu/pool/main/a/amdgpu-install"
    
    # Get list of available packages
    AVAILABLE_PKGS=$(wget -qO- "${AMDGPU_BASE_URL}/" 2>/dev/null | grep -o 'amdgpu-install_[0-9].*_all\.deb' || true)
    
    if [ -n "$AVAILABLE_PKGS" ]; then
        # Get latest version from available packages
        AMDGPU_DEB=$(echo "$AVAILABLE_PKGS" | sort -V | tail -n1)
        echo "Found latest package: ${AMDGPU_DEB}"
    else
        echo "Error: Unable to find AMDGPU packages. Continuing with open source build..."
        AMDGPU_DEB=""
    fi
fi

if [ -n "$AMDGPU_DEB" ]; then
    echo "Downloading from: ${AMDGPU_BASE_URL}/${AMDGPU_DEB}"
    if wget -q --show-progress "${AMDGPU_BASE_URL}/${AMDGPU_DEB}"; then
        echo "Successfully downloaded AMDGPU package"
        dpkg-deb -x "${AMDGPU_DEB}" ./extract
    else
        echo "Error: Failed to download AMDGPU package. Continuing with open source build..."
    fi
fi

cd $BUILD_DIR
makepkg -l y -c y "../rocm-${ROCM_VERSION}.txz"
md5sum "../rocm-${ROCM_VERSION}.txz" > "../rocm-${ROCM_VERSION}.txz.md5"