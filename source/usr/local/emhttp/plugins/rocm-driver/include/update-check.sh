#!/bin/bash
KERNEL_V="$(uname -r)"
SET_DRV_V="$(cat /boot/config/plugins/rocm-driver/settings.cfg | grep 'driver_version' | cut -d '=' -f2)"
PACKAGE="rocm"
DL_URL="https://github.com/yourname/unraid-rocm-driver/releases/download/${KERNEL_V}"
# For demonstration, we assume INSTALLED_V from amdgpu modinfo, real ROCm version detection may differ:
INSTALLED_V="$(modinfo amdgpu | grep 'version:' | awk '{print $2}')"

download() {
if wget -q -nc --show-progress --progress=bar:force:noscroll -O "/boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}" "${DL_URL}/${LAT_PACKAGE}" ; then
  wget -q -nc --show-progress --progress=bar:force:noscroll -O "/boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}.md5" "${DL_URL}/${LAT_PACKAGE}.md5"
  if [ "$(md5sum /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE} | awk '{print $1}')" != "$(cat /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}.md5 | awk '{print $1}')" ]; then
    /usr/local/emhttp/plugins/dynamix/scripts/notify -e "ROCm Driver" -d "Found new ROCm Driver v$(echo $LAT_PACKAGE | cut -d '-' -f2) but checksum failed! Please install manually." -i "alert"
    rm -rf /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}*
    exit 1
  fi
  /usr/local/emhttp/plugins/dynamix/scripts/notify -e "ROCm Driver" -d "New ROCm Driver v$(echo $LAT_PACKAGE | cut -d '-' -f2) found and downloaded! Reboot to install." -l "/Main"
  crontab -l | grep -v '/usr/local/emhttp/plugins/rocm-driver/include/update-check.sh' | crontab -
else
  /usr/local/emhttp/plugins/dynamix/scripts/notify -e "ROCm Driver" -d "Found new ROCm Driver v$(echo $LAT_PACKAGE | cut -d '-' -f2) but download failed! Please install manually." -i "alert"
  crontab -l | grep -v '/usr/local/emhttp/plugins/rocm-driver/include/update-check.sh' | crontab -
  exit 1
fi
}

if [ "${SET_DRV_V}" != "latest" ]; then
  exit 0
fi

# Retrieve the latest package name from GitHub API (placeholder logic)
LAT_PACKAGE="$(wget -qO- https://api.github.com/repos/yourname/unraid-rocm-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep "${PACKAGE}" | grep -E -v '\.md5$' | sort -V | tail -1)"
if [ -z "$LAT_PACKAGE" ]; then
  logger "ROCm-Driver-Plugin: Automatic update check failed, can't get latest version number!"
  exit 1
fi

NEW_VER="$(echo "$LAT_PACKAGE" | cut -d '-' -f2)"
if [ "$NEW_VER" != "$INSTALLED_V" ]; then
  download
fi

# Cleanup old packages
rm -rf $(ls -d /boot/config/plugins/rocm-driver/packages/* 2>/dev/null | grep -v "${KERNEL_V%%-*}")
rm -f $(ls /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/* 2>/dev/null | grep -v "$LAT_PACKAGE")