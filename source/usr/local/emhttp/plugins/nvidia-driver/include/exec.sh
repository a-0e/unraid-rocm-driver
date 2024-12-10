#!/bin/bash

function update(){
KERNEL_V="$(uname -r)"
PACKAGE="nvidia"
CURENTTIME=$(date +%s)
CHK_TIMEOUT=300
if [ -f /tmp/nvidia_driver ]; then
  FILETIME=$(stat /tmp/nvidia_driver -c %Y)
  DIFF=$(expr $CURENTTIME - $FILETIME)
  if [ $DIFF -gt $CHK_TIMEOUT ]; then
    DRIVERS="$(wget -qO- https://api.github.com/repos/ich777/unraid-nvidia-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep -E -v '\.md5$' | sort -V)"
    echo -n "$(grep ${PACKAGE} <<< "$DRIVERS" | awk -F "-" '{print $2}' | sort -V | tail -10)" > /tmp/nvidia_driver
    echo -n "$(grep nvos <<< "$DRIVERS" | awk -F "-" '{print $2}' | sort -V | tail -1)" > /tmp/nvos_driver
    echo -n "$(wget -qO- https://api.github.com/repos/ich777/unraid-nvidia-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep "${PACKAGE}" | grep -E -v '\.md5$' | awk -F "-" '{print $2}' | sort -V | tail -10)" > /tmp/nvidia_driver
    if [ ! -s /tmp/nvidia_driver ]; then
      echo -n "$(modinfo nvidia | grep "version:" | awk '{print $2}' | head -1)" > /tmp/nvidia_driver
    fi
  fi
else
  DRIVERS="$(wget -qO- https://api.github.com/repos/ich777/unraid-nvidia-driver/releases/tags/${KERNEL_V} | jq -r '.assets[].name' | grep -E -v '\.md5$' | sort -V)"
  echo -n "$(grep ${PACKAGE} <<< "$DRIVERS" | awk -F "-" '{print $2}' | sort -V | tail -10)" > /tmp/nvidia_driver
  echo -n "$(grep nvos <<< "$DRIVERS" | awk -F "-" '{print $2}' | sort -V | tail -10)" > /tmp/nvos_driver
  if [ ! -s /tmp/nvidia_driver ]; then
    echo -n "$(modinfo nvidia | grep "version:" | awk '{print $2}' | head -1)" > /tmp/nvidia_driver
  fi
fi
# Check if driver version 470 is in /tmp/nvos_driver
if [ ! $(grep "470" /tmp/nvidia_driver) ]; then
  LEGACY_DRIVER="$(echo "$DRIVERS" | awk -F "-" '{print $2}' | grep "470")"
  if [ ! -z "${LEGACY_DRIVER}" ]; then
    sed -i "1s/^/${LEGACY_DRIVER}\n/" /tmp/nvidia_driver
  fi
fi
if [ -f /tmp/nvidia_branches ]; then
  FILETIME=$(stat /tmp/nvidia_branches -c %Y)
  DIFF=$(expr $CURENTTIME - $FILETIME)
  if [ $DIFF -gt $CHK_TIMEOUT ]; then
    echo -n "$(wget -q -N -O /tmp/nvidia_branches https://raw.githubusercontent.com/ich777/versions/master/nvidia_versions)"
    if [ ! -s /tmp/nvidia_branches ]; then
      rm -rf /tmp/nvidia_branches
    fi
  fi
else
  echo -n "$(wget -q -N -O /tmp/nvidia_branches https://raw.githubusercontent.com/ich777/versions/master/nvidia_versions)"
fi
}

function update_version(){
sed -i "/driver_version=/c\driver_version=${1}" "/boot/config/plugins/nvidia-driver/settings.cfg"
if [[ "${1}" != "latest" && "${1}" != "latest_prb" && "${1}" != "latest_nfb" ]]; then
  sed -i "/update_check=/c\update_check=false" "/boot/config/plugins/nvidia-driver/settings.cfg"
  echo -n "$(crontab -l | grep -v '/usr/local/emhttp/plugins/nvidia-driver/include/update-check.sh &>/dev/null 2>&1'  | crontab -)"
fi
/usr/local/emhttp/plugins/nvidia-driver/include/download.sh
}

function get_latest_version(){
KERNEL_V="$(uname -r)"
echo -n "$(cat /tmp/nvidia_driver | tail -1)"
}

function get_prb(){
echo -n "$(comm -12 <(cat /tmp/nvidia_driver | awk -F '.' '{printf "%d.%03d.%d\n", $1,$2,$3}' | awk -F '.' '{printf "%d.%03d.%02d\n", $1,$2,$3}') <(echo "$(cat /tmp/nvidia_branches | grep 'PRB' | cut -d '=' -f2 | sort -V | awk -F '.' '{printf "%d.%03d.%d\n", $1,$2,$3}' | awk -F '.' '{printf "%d.%03d.%02d\n", $1,$2,$3}')") | tail -1 | awk -F '.' '{printf "%d.%02d.%02d\n", $1,$2,$3}' | awk '{sub(/\.0+$/,"")}1')"
}

function get_nfb(){
echo -n "$(comm -12 <(cat /tmp/nvidia_driver | awk -F '.' '{printf "%d.%03d.%d\n", $1,$2,$3}' | awk -F '.' '{printf "%d.%03d.%02d\n", $1,$2,$3}') <(echo "$(cat /tmp/nvidia_branches | grep 'NFB' | cut -d '=' -f2 | sort -V | awk -F '.' '{printf "%d.%03d.%d\n", $1,$2,$3}' | awk -F '.' '{printf "%d.%03d.%02d\n", $1,$2,$3}')") | tail -1 | awk -F '.' '{printf "%d.%02d.%02d\n", $1,$2,$3}' | awk '{sub(/\.0+$/,"")}1')"
}

function get_nos(){
echo -n "$(cat /tmp/nvos_driver | sort -V | tail -1)"
}

function get_selected_version(){
echo -n "$(cat /boot/config/plugins/nvidia-driver/settings.cfg | grep "driver_version" | cut -d '=' -f2)"
}

function get_installed_version(){
echo -n "$(modinfo nvidia | grep -w "version:" | awk '{print $2}')"
}

function get_license(){
LICENSE="$(modinfo nvidia 2>/dev/null | grep "license" | awk '{print $2}')"
if [ -z "${LICENSE}" ]; then
  echo -n "NONE"
elif [ "${LICENSE}" == "NVIDIA" ]; then
  echo -n "PROPRIETARY"
else
  echo -n "OPENSOURCE"
fi
}

function update_check(){
echo -n "$(cat /boot/config/plugins/nvidia-driver/settings.cfg | grep "update_check" | head -1 | cut -d '=' -f2)"
}

function change_update_check(){
sed -i "/update_check=/c\update_check=${1}" "/boot/config/plugins/nvidia-driver/settings.cfg"
if [ "${1}" == "true" ]; then
  if [ ! "$(crontab -l | grep "/usr/local/emhttp/plugins/nvidia-driver/include/update-check.sh")" ]; then
    echo -n "$((crontab -l ; echo ""$((0 + $RANDOM % 59))" "$(shuf -i 8-9 -n 1)" * * * /usr/local/emhttp/plugins/nvidia-driver/include/update-check.sh &>/dev/null 2>&1") | crontab -)"
  fi
elif [ "${1}" == "false" ]; then
  echo -n "$(crontab -l | grep -v '/usr/local/emhttp/plugins/nvidia-driver/include/update-check.sh &>/dev/null 2>&1'  | crontab -)"
fi

}

$@
