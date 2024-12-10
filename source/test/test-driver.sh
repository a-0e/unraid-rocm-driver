#!/bin/bash

function test_driver_installation() {
    # Test driver loading
    if ! modinfo amdgpu &>/dev/null; then
        echo "ERROR: amdgpu module not found"
        exit 1
    fi
    
    # Test ROCm functionality
    if ! command -v rocminfo &>/dev/null; then
        echo "ERROR: ROCm tools not installed"
        exit 1
    fi
    
    # Test GPU detection
    if ! rocminfo | grep -q "GPU ID"; then
        echo "ERROR: No compatible GPU detected"
        exit 1
    fi
}

function test_docker_integration() {
    # Test Docker runtime
    if ! docker info | grep -q "Default Runtime: rocm"; then
        echo "ERROR: ROCm runtime not configured in Docker"
        exit 1
    fi
}

test_driver_installation
test_docker_integration 