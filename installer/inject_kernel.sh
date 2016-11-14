#!/bin/bash

# Script to include necessary kernel/modules/devices for FB Wedge,
# 1. first run mksnappytgz.sh (in parent dir)
# 2. untar the device specific tarball in installer/
# 3. run ./build_wedge.sh
# 4. run  mksnappyonieinstaller.sh (in parent dir)

# ./etc includes to rc.local to disable autopilto and create /dev
# ./lib includes kernel modules
# ./EFI includes the kernel (vmlinuz) in a and b

gunzip system-boot.tgz
gunzip system-a.tgz

tar uvf system-boot.tar ./EFI
tar uvf system-a.tar ./etc ./lib

gzip system-boot.tar
gzip system-a.tar

mv system-boot.tar.gz system-boot.tgz
mv system-a.tar.gz system-a.tgz
