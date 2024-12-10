#!/bin/bash
set -e

# Setup test environment
TEST_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Mock environment and config
mkdir -p "$TEST_DIR/boot/config/plugins/rocm-driver"
cat > "$TEST_DIR/boot/config/plugins/rocm-driver/settings.cfg" << EOF
driver_version=latest
update_check=true
EOF

# Mock environment variables used by download.sh
export KERNEL_V="$(uname -r)"
export SET_DRV_V="latest"
export PACKAGE="rocm"
export DL_URL="https://github.com/a-0e/unraid-rocm-driver/releases/download/${KERNEL_V}"
export CUR_V="6.0.2"

# Test cases
test_amdgpu_download() {
    echo "Testing AMDGPU download URLs..."
    
    # Test versioned URL (based on ROCm issue #2111)
    ROCM_VERSION="6.0.2"
    VERSIONED_URL="https://repo.radeon.com/rocm/apt/debian/"
    if ! curl --output /dev/null --silent --head --fail "$VERSIONED_URL"; then
        echo "❌ ROCm APT URL test failed: $VERSIONED_URL"
        return 1
    fi
    echo "✓ ROCm APT URL accessible"
    
    # Test AMDGPU URL
    AMDGPU_URL="https://repo.radeon.com/amdgpu/latest/ubuntu/pool/main/a/amdgpu-install/"
    if ! curl --output /dev/null --silent --head --fail "$AMDGPU_URL"; then
        echo "❌ AMDGPU URL test failed: $AMDGPU_URL"
        return 1
    fi
    echo "✓ AMDGPU URL accessible"
    
    # Test package naming convention
    PACKAGE_LIST=$(curl -s "$AMDGPU_URL")
    if ! echo "$PACKAGE_LIST" | grep -q "amdgpu-install_[0-9].*_all\.deb"; then
        echo "❌ No valid packages found at URL"
        return 1
    fi
    echo "✓ Valid package names found"
    
    return 0
}

test_github_releases() {
    echo "Testing GitHub releases access..."
    
    # Test GitHub API access
    API_URL="https://api.github.com/repos/a-0e/unraid-rocm-driver/releases/tags/${KERNEL_V}"
    if ! curl --output /dev/null --silent --head --fail "$API_URL"; then
        echo "❌ GitHub API test failed: $API_URL"
        return 1
    fi
    echo "✓ GitHub API accessible"
    
    # Verify release assets format
    ASSETS=$(curl -s "$API_URL" | jq -r '.assets[].name' 2>/dev/null || echo "")
    if ! echo "$ASSETS" | grep -q "rocm.*\.txz"; then
        echo "❌ No valid release assets found"
        return 1
    fi
    echo "✓ Valid release assets found"
    
    return 0
}

test_download_function() {
    echo "Testing download function..."
    
    # Mock the download paths
    mkdir -p "$TEST_DIR/boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}"
    
    # Source the download script with mocked environment
    PLUGIN_PATH="$TEST_DIR" source source/usr/local/emhttp/plugins/rocm-driver/include/download.sh
    
    # Test the download function
    if ! download; then
        echo "❌ Download function failed"
        return 1
    fi
    echo "✓ Download function succeeded"
    
    return 0
}

# Run tests
echo "=== Running Download Tests ==="
test_amdgpu_download
test_github_releases
test_download_function
echo "=== Tests Complete ===" 