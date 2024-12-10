#!/bin/bash
CONFIG_FILE="/boot/config/plugins/rocm-driver/settings.cfg"

function init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "first_installation=true" > "$CONFIG_FILE"
        echo "driver_version=latest" >> "$CONFIG_FILE"
        echo "update_check=true" >> "$CONFIG_FILE"
    fi
}

function validate_config() {
    DRIVER_VERSION=$(grep 'driver_version' "$CONFIG_FILE" | cut -d '=' -f2)
    UPDATE_CHECK=$(grep 'update_check' "$CONFIG_FILE" | cut -d '=' -f2)
    # Additional validation can be added here if needed
}

init_config
validate_config