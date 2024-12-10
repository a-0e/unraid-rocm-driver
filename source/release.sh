#!/bin/bash

VERSION=$(date +'%Y.%m.%d')
PLUGIN_NAME="rocm-driver"

function prepare_release() {
    sed -i "s/<!ENTITY version.*>/<!ENTITY version   \"$VERSION\">/" "$PLUGIN_NAME.plg"
    
    ./source/compile.sh
    ./source/test/test-driver.sh
    
    ./source/makepkg-unraid.sh
}

function create_github_release() {
    curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"tag_name\": \"v$VERSION\", \"name\": \"Release $VERSION\"}" \
        "https://api.github.com/repos/a-0e/unraid-rocm-driver/releases"
    # Upload assets if needed
}

prepare_release
create_github_release