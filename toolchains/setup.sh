#!/bin/bash

# change these if you want another version
URL='https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz'
VERSION='10.3'

# these pretty much stay the same
ARCHIVE=$(basename ${URL})
DIRNAME=${ARCHIVE%.tar.xz}

# download archive; rename directory; create symlink (used in Makefile)
wget ${URL}
tar xf ${ARCHIVE}
mv ${DIRNAME} aarch64-${VERSION}
ln -s aarch64-${VERSION} aarch64
rm -f ${ARCHIVE}

