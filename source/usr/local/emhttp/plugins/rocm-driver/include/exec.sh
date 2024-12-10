#!/bin/bash

function update(){
KERNEL_V="$(uname -r)"
PACKAGE="rocm"
CURENTTIME=$(date +%s)
CHK_TIMEOUT=300
if [ ! -f /tmp/rocm_driver ]; then
  DRIVERS="$(wget -qO- https://api.github.com/repos/a-0e/unraid-rocm-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep "${PACKAGE}" | grep -E -v '\.md5$' | sort -V)"
  echo -n "$(echo "$DRIVERS" | awk -F "-" '{print $2}' | sort -V | tail -10)" > /tmp/rocm_driver
else
  FILETIME=$(stat /tmp/rocm_driver -c %Y)
  DIFF=$(expr $CURENTTIME - $FILETIME)
  if [ $DIFF -gt $CHK_TIMEOUT ]; then
    DRIVERS="$(wget -qO- https://api.github.com/repos/a-0e/unraid-rocm-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep "${PACKAGE}" | grep -E -v '\.md5$' | sort -V)"
    echo -n "$(echo "$DRIVERS" | awk -F "-" '{print $2}' | sort -V | tail -10)" > /tmp/rocm_driver
  fi
fi
if [ ! -s /tmp/rocm_driver ]; then
  echo -n "$(modinfo amdgpu | grep 'version:' | awk '{print $2}')" > /tmp/rocm_driver
fi
}

function update_version(){
sed -i "/driver_version=/c\driver_version=${1}" "/boot/config/plugins/rocm-driver/settings.cfg"
if [[ "${1}" != "latest" ]]; then
  sed -i "/update_check=/c\update_check=false" "/boot/config/plugins/rocm-driver/settings.cfg"
  crontab -l | grep -v '/usr/local/emhttp/plugins/rocm-driver/include/update-check.sh &>/dev/null 2>&1' | crontab -
fi
/usr/local/emhttp/plugins/rocm-driver/include/download.sh
}

function get_latest_version(){
echo -n "$(tail -1 /tmp/rocm_driver)"
}

function get_selected_version(){
echo -n "$(grep 'driver_version' '/boot/config/plugins/rocm-driver/settings.cfg' | cut -d '=' -f2)"
}

function get_installed_version(){
modinfo amdgpu 2>/dev/null | grep -w "version:" | awk '{print $2}'
}

function update_check(){
echo -n "$(grep 'update_check' '/boot/config/plugins/rocm-driver/settings.cfg' | head -1 | cut -d '=' -f2)"
}

function change_update_check(){
sed -i "/update_check=/c\update_check=${1}" "/boot/config/plugins/rocm-driver/settings.cfg"
if [ "${1}" == "true" ]; then
  if [ ! "$(crontab -l | grep '/usr/local/emhttp/plugins/rocm-driver/include/update-check.sh')" ]; then
    (crontab -l ; echo ""$((0 + $RANDOM % 59))" "$(shuf -i 8-9 -n 1)" * * * /usr/local/emhttp/plugins/rocm-driver/include/update-check.sh &>/dev/null 2>&1") | crontab -
  fi
else
  crontab -l | grep -v '/usr/local/emhttp/plugins/rocm-driver/include/update-check.sh &>/dev/null 2>&1' | crontab -
fi
}

$@