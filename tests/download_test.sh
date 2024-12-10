#!/bin/bash
set -e

# Setup test environment
TEST_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

test_release_structure() {
    echo "Testing release structure..."
    
    # Check latest release format
    LATEST=$(curl -s "https://api.github.com/repos/a-0e/unraid-rocm-driver/releases/latest")
    
    # Verify date-based version tag
    TAG=$(echo "$LATEST" | jq -r '.tag_name')
    if ! echo "$TAG" | grep -qE '^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}$'; then
        echo "❌ Invalid release tag format: $TAG"
        return 1
    fi
    echo "✓ Release tag format valid: $TAG"
    
    # Check for kernel-specific assets
    KERNEL_V="$(uname -r)"
    ASSETS=$(echo "$LATEST" | jq -r '.assets[].name')
    if ! echo "$ASSETS" | grep -q "rocm.*${KERNEL_V}.*\.txz"; then
        echo "❌ No matching kernel assets found"
        echo "Expected pattern: rocm-*-${KERNEL_V}-*.txz"
        echo "Found assets:"
        echo "$ASSETS"
        return 1
    fi
    echo "✓ Found matching kernel assets"
    
    # Check MD5 files exist
    if ! echo "$ASSETS" | grep -q "\.md5$"; then
        echo "❌ No MD5 checksums found"
        return 1
    fi
    echo "✓ MD5 checksums present"
    
    return 0
}

test_amdgpu_availability() {
    echo "Testing AMDGPU package availability..."
    
    ROCM_VERSION="6.0.2"
    AMDGPU_URL="https://repo.radeon.com/amdgpu/latest/ubuntu/pool/main/a/amdgpu-install/"
    
    # Test URL accessibility
    if ! curl --output /dev/null --silent --head --fail "$AMDGPU_URL"; then
        echo "❌ AMDGPU repository not accessible"
        return 1
    fi
    echo "✓ AMDGPU repository accessible"
    
    # Check for specific version
    EXPECTED_DEB="amdgpu-install_${ROCM_VERSION}.60401-1_all.deb"
    PACKAGES=$(curl -s "$AMDGPU_URL" | grep -o 'amdgpu-install_[0-9].*_all\.deb')
    if ! echo "$PACKAGES" | grep -q "$EXPECTED_DEB"; then
        echo "❌ Expected package not found: $EXPECTED_DEB"
        echo "Available packages:"
        echo "$PACKAGES"
        return 1
    fi
    echo "✓ Found expected AMDGPU package"
    
    return 0
}

# Run tests
echo "=== Running Download Tests ==="
test_release_structure
test_amdgpu_availability
echo "=== Tests Complete ===" 