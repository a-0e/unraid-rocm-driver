#!/bin/bash
function install_driver() {
    /sbin/installpkg "${PACKAGE}"
    /sbin/depmod -a
    /sbin/modprobe amdgpu
}

install_driver