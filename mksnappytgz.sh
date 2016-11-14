#!/bin/bash

echo BE CAREFUL uses sudo to remove files only contiue if you know what you are doing
read -s -n1 -rp "Press any key to continue" 
echo


IMG=mlnx-snappy.img
#unxz $IMG.xz

MNT=/tmp/oniemnt
LOOP=loop2
LABELS=(system-boot writable)
FSTYPES=(ext2 ext4)
SIZES=($(sudo kpartx -l $IMG | head -n -1 | tail -n +2 | tr ' ' : | cut -d: -f 5))

echo -n > installer/partitions
mkdir $MNT
sudo rm installer/*.tgz

sudo kpartx -a $IMG

for i in $(seq 0 1)
do
  echo ${SIZES[i]}:${FSTYPES[i]}:${LABELS[i]} >> installer/partitions
  sudo mount -o ro /dev/mapper/${LOOP}p$((i + 2)) $MNT
  sudo tar zcpS -C $MNT -f installer/${LABELS[i]}.tgz .
  sudo umount $MNT
done

sudo kpartx -d /dev/$LOOP
sudo losetup -d /dev/$LOOP

