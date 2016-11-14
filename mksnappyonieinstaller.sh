#!/bin/bash

. ./installer/installer.conf

rm snappy-onie-installer.bin.2.tar
tar cf snappy-onie-installer.bin.2.tar installer
cat snappy-onie-installer.bin.1.sh snappy-onie-installer.bin.2.tar > onie-installer-${installer}.bin

#scp snappy-onie-installer.bin 192.168.122.188:
