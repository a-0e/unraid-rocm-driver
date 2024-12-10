#!/bin/bash

VERSION=$(date +'%Y.%m.%d')
PLUGIN_NAME="rocm-driver"

function prepare_release() {
    # Update version in plugin file
    sed -i "s/<!ENTITY version.*>/<!ENTITY version   \"$VERSION\">/" "$PLUGIN_NAME.plg"
    
    # Build package
    ./source/compile.sh
    
    # Run tests
    ./source/test/test-driver.sh
    
    # Create release package
    ./source/makepkg-unraid.sh
}

function create_github_release() {
    # Create GitHub release using API
    curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"tag_name\": \"v$VERSION\", \"name\": \"Release $VERSION\"}" \
        "https://api.github.com/repos/a-0e/unraid-rocm-driver/releases"
        
    # Upload assets
    # ...
}

prepare_release
create_github_release 