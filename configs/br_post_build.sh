#!/bin/bash

# make devtmpfs onto /dev since it's not done for initramfs
sed -i '/# Startup the system/a ::sysinit:/bin/mount -t devtmpfs devtmpfs /dev' \
    ${TARGET_DIR}/etc/inittab

