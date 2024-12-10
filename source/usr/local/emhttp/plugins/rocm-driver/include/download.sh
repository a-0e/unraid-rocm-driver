#!/bin/bash

KERNEL_V="$(uname -r)"
SET_DRV_V="$(grep 'driver_version' '/boot/config/plugins/rocm-driver/settings.cfg' | cut -d '=' -f2)"
PACKAGE="rocm"
DL_URL="https://github.com/yourname/unraid-rocm-driver/releases/download/${KERNEL_V}"
CUR_V="$(modinfo amdgpu | grep 'version:' | awk '{print $2}')"

download() {
if wget -q -nc --show-progress --progress=bar:force:noscroll -O "/boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}" "${DL_URL}/${LAT_PACKAGE}" ; then
  wget -q -nc --show-progress --progress=bar:force:noscroll -O "/boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}.md5" "${DL_URL}/${LAT_PACKAGE}.md5"
  if [ "$(md5sum /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE} | awk '{print $1}')" != "$(cat /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}.md5" | awk '{print $1}')" ]; then
    echo "CHECKSUM ERROR!"
    rm -rf /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/${LAT_PACKAGE}*
    exit 1
  fi
  echo "Successfully downloaded ROCm Driver Package v$(echo $LAT_PACKAGE | cut -d '-' -f2). Please reboot!"
else
  echo "Can't download ROCm Driver Package v$(echo $LAT_PACKAGE | cut -d '-' -f2)."
  exit 1
fi
}

if [ ! -d "/boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}" ]; then
  mkdir -p "/boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}"
fi

# For simplicity, just pick the latest from GitHub for 'latest' or exact version if set
if [ "${SET_DRV_V}" == "latest" ]; then
  LAT_PACKAGE="$(wget -qO- https://api.github.com/repos/yourname/unraid-rocm-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep "${PACKAGE}" | sort -V | tail -1)"
else
  LAT_PACKAGE="$(wget -qO- https://api.github.com/repos/yourname/unraid-rocm-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep "${SET_DRV_V}" | sort -V | tail -1)"
  if [ -z "${LAT_PACKAGE}" ]; then
    # fallback to current if not found
    LAT_PACKAGE="${PACKAGE}-${CUR_V}-${KERNEL_V}-1.txz"
  fi
fi

download

rm -rf $(ls -d /boot/config/plugins/rocm-driver/packages/* 2>/dev/null | grep -v "${KERNEL_V%%-*}")
rm -f $(ls /boot/config/plugins/rocm-driver/packages/${KERNEL_V%%-*}/* 2>/dev/null | grep -v "$LAT_PACKAGE")