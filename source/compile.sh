#!/bin/bash
set -ex

# Source versions from central config
source <(grep ROCM_VERSION source/versions.yml | sed 's/version:/ROCM_VERSION=/')
BUILD_DIR="/tmp/rocm-build"
PLUGIN_NAME="rocm-driver"

function create_package() {
    cd "$BUILD_DIR"
    
    # Create Slackware package structure
    mkdir -p pkg/usr/local/lib/modprobe.d
    mkdir -p pkg/usr/local/lib/firmware/amdgpu
    mkdir -p pkg/install
    
    # Copy driver files from extracted AMD package
    cp -r extract/usr/lib/firmware/amdgpu/* pkg/usr/local/lib/firmware/amdgpu/
    cp -r extract/usr/lib/modules/*-amdgpu/kernel/drivers/gpu/drm/amd/* pkg/usr/local/lib/
    
    # Create modprobe configuration
    echo "options amdgpu gpu_recovery=1" > pkg/usr/local/lib/modprobe.d/amdgpu.conf
    
    # Create install script
    cat > pkg/install/doinst.sh << 'EOF'
#!/bin/sh
if [ -x /sbin/depmod ]; then
    /sbin/depmod -a
fi
if [ -x /sbin/modprobe ]; then
    /sbin/modprobe amdgpu || true
fi
EOF
    chmod +x pkg/install/doinst.sh
    
    # Create slack-desc
    cat > pkg/install/slack-desc << EOF
$PLUGIN_NAME: ROCm Driver for AMD GPUs
$PLUGIN_NAME:
$PLUGIN_NAME: ROCm driver package for AMD GPUs on Unraid systems.
$PLUGIN_NAME: Version: ${ROCM_VERSION}
$PLUGIN_NAME:
$PLUGIN_NAME: This package provides the AMD GPU driver and firmware
$PLUGIN_NAME: for use with Unraid systems.
$PLUGIN_NAME:
$PLUGIN_NAME: Build Date: $(date +'%Y.%m.%d')
$PLUGIN_NAME: Homepage: https://github.com/a-0e/unraid-rocm-driver
$PLUGIN_NAME:
EOF
    
    # Create Slackware package
    cd pkg
    makepkg -l y -c n "../${PLUGIN_NAME}-${ROCM_VERSION}.txz"
    cd ..
    md5sum "${PLUGIN_NAME}-${ROCM_VERSION}.txz" > "${PLUGIN_NAME}-${ROCM_VERSION}.txz.md5"
}

create_package