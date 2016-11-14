#!/bin/sh

#  SPDX-License-Identifier:     GPL-2.0

set -ex

# enabled for easier debugging
trap "sleep 3" 0 1 2 3 9 11 13 15

cd $(dirname $0)
. ./installer.conf

echo "Snappy Installer: $installer"

# Install demo on same block device as ONIE
blk_dev=$(blkid | grep ONIE-BOOT | awk '{print $1}' |  sed -e 's/[1-9][0-9]*:.*$//' | sed -e 's/\([0-9]\)\(p\)/\1/' | head -n 1)

[ -b "$blk_dev" ] || {
    echo "Error: Unable to determine block device of ONIE install"
    exit 1
}

demo_volume_label="ubuntu"

# auto-detect whether BIOS or UEFI
if [ -d "/sys/firmware/efi/efivars" ] ; then
    firmware="uefi"
else
    firmware="bios"
fi

# determine ONIE partition type
onie_partition_type=$(onie-sysinfo -t)
if [ "$firmware" = "uefi" ] ; then
    create_demo_partition="create_demo_uefi_partition"
elif [ "$onie_partition_type" = "gpt" ] ; then
    create_demo_partition="create_demo_gpt_partition"
elif [ "$onie_partition_type" = "msdos" ] ; then
    create_demo_partition="create_demo_msdos_partition"
else
    echo "ERROR: Unsupported partition type: $onie_partition_type"
    exit 1
fi

# Creates a new partition for the DEMO OS.
# 
# arg $1 -- base block device
#
# Returns the created partition number in $demo_part
demo_part=
create_demo_gpt_partition()
{
    blk_dev="$1"

    # Delete existing partitions
    for partition in $(cat partitions);
    do
      demo_volume_label=$(echo $partition | cut -f3 -d:)
      demo_part=$(sgdisk -p $blk_dev | grep "$demo_volume_label" | awk '{print $1}')
      if [ -n "$demo_part" ] ; then
          # delete existing partition
          sgdisk -d $demo_part $blk_dev || {
              echo "Error: Unable to delete partition $demo_part on $blk_dev"
              exit 1
          }
          partprobe
      fi
    done

    # Find next available partition
    last_part=$(sgdisk -p $blk_dev | tail -n 1 | awk '{print $1}')
    demo_part=$(( $last_part + 1 ))

    # Create new partition
    echo "Creating new partitions ${blk_dev}$demo_part ..."

    attr_bitmask="0x0"


    for partition in $(cat partitions);
    do

      demo_part_size=$(echo $partition | cut -f1 -d:)
      demo_fstype=$(echo $partition | cut -f2 -d:)
      demo_volume_label=$(echo $partition | cut -f3 -d:)

    sgdisk -g --new=${demo_part}::+${demo_part_size} \
        --attributes=${demo_part}:=:$attr_bitmask \
        --change-name=${demo_part}:$demo_volume_label $blk_dev || {
        echo "Error: Unable to create partition $demo_part on $blk_dev"
        exit 1
    }
      
      partprobe
      
      demo_dev=$(echo $blk_dev | sed -e 's/\(mmcblk[0-9]\)/\1p/')$demo_part

     if [ "$demo_fstype" = "vfat" ]
     then
       labelarg=n
     else
       labelarg=L
     fi

     # Create filesystem on demo partition with a label
     mkfs.$demo_fstype -$labelarg $demo_volume_label $demo_dev || {
         echo "Error: Unable to create file system on $demo_dev"
         exit 1
     }

     # Mount demo filesystem
     demo_mnt=$(mktemp -d) || {
         echo "Error: Unable to create demo file system mount point"
         exit 1
     }

     eval $(echo $demo_volume_label | tr - _)_mnt=$demo_mnt

     mount -t $demo_fstype -o defaults,rw $demo_dev $demo_mnt || {
         echo "Error: Unable to mount $demo_dev on $demo_mnt"
         exit 1
     }

     tar -C $demo_mnt -xzf $demo_volume_label.tgz

      demo_part=$(( $demo_part + 1 ))

    done

    partprobe
}

create_demo_uefi_partition()
{
    create_demo_gpt_partition "$1"

 # erase any related EFI BootOrder variables from NVRAM.
    for b in $(efibootmgr | grep "$demo_volume_label" | awk '{ print $1 }') ; do
        local num=${b#Boot}
        # Remove trailing '*'
        num=${num%\*}
        efibootmgr -b $num -B > /dev/null 2>&1
    done

}

# Install legacy BIOS GRUB for DEMO OS
demo_install_grub()
{
    local demo_mnt="$1"
    local blk_dev="$2"

    # Pretend we are a major distro and install GRUB into the MBR of
    # $blk_dev.
    grub-install --boot-directory="$demo_mnt" --recheck "$blk_dev" || {
        echo "ERROR: grub-install failed on: $blk_dev"
        exit 1
    }

}

# Install UEFI BIOS GRUB for DEMO OS
demo_install_uefi_grub()
{
    local demo_mnt="$1"
    local blk_dev="$2"

    # Look for the EFI system partition UUID on the same block device as
    # the ONIE-BOOT partition.
    local uefi_part=0
    for p in $(seq 8) ; do
        if sgdisk -i $p $blk_dev | grep -q C12A7328-F81F-11D2-BA4B-00A0C93EC93B ; then
            uefi_part=$p
            break
        fi
    done

    [ $uefi_part -eq 0 ] && {
        echo "ERROR: Unable to determine UEFI system partition"
        exit 1
    }

    grub_install_log=$(mktemp)
    grub-install \
        --no-nvram \
        --bootloader-id="$demo_volume_label" \
        --efi-directory="/boot/efi" \
        --boot-directory="$demo_mnt" \
        --recheck \
        "$blk_dev" > /$grub_install_log 2>&1 || {
        echo "ERROR: grub-install failed on: $blk_dev"
        cat $grub_install_log && rm -f $grub_install_log
        exit 1
    }
    rm -f $grub_install_log

    # Configure EFI NVRAM Boot variables.  --create also sets the
    # new boot number as active.
    efibootmgr --quiet --create \
        --label "$demo_volume_label" \
        --disk $blk_dev --part $uefi_part \
        --loader "/EFI/$demo_volume_label/grubx64.efi" || {
        echo "ERROR: efibootmgr failed to create new boot variable on: $blk_dev"
        exit 1
    }
 
    
}

eval $create_demo_partition $blk_dev
partprobe

# store installation log in demo file system
onie-support $system_boot_mnt

if [ "$firmware" = "uefi" ] ; then
     demo_install_uefi_grub "$system_boot_mnt"/EFI/ubuntu "$blk_dev"
else    
    demo_install_grub "$system_boot_mnt"/EFI/ubuntu "$blk_dev"
fi

# The persistent ONIE directory location
onie_root_dir=/mnt/onie-boot/onie

# Create the grub directory and copy the grub.cfg and grubenv so that 
# Ubuntu-Core is compatible with ONIE

mkdir -p $system_boot_mnt/EFI/ubuntu/grub
mv $system_boot_mnt/EFI/ubuntu/grub.cfg $system_boot_mnt/EFI/ubuntu/grub/
mv $system_boot_mnt/EFI/ubuntu/grubenv $system_boot_mnt/EFI/ubuntu/grub/

grub_cfg="$system_boot_mnt/EFI/ubuntu/grub/grub.cfg"
echo "Modifying Snappy GRUB file: $grub_cfg"
if [ ! -f $grub_cfg ]
then
  echo error finding grub file
  exit 1
fi

grub_tmp=$(mktemp)

# setup snappy to use serial for grub/boot to be consistent w ONIE

# DEFAULT_GRUB_SERIAL_COMMAND is set in instaler.conf
DEFAULT_GRUB_CMDLINE_LINUX="console=${linux_console0} console=${linux_console1}"
GRUB_SERIAL_COMMAND=${GRUB_SERIAL_COMMAND:-"$DEFAULT_GRUB_SERIAL_COMMAND"}
GRUB_CMDLINE_LINUX=${GRUB_CMDLINE_LINUX:-"$DEFAULT_GRUB_CMDLINE_LINUX"}
export GRUB_SERIAL_COMMAND
export GRUB_CMDLINE_LINUX

cat << EOF > $grub_tmp

$GRUB_SERIAL_COMMAND
terminal_input serial
terminal_output serial

EOF

cat $grub_cfg >> $grub_tmp
cat $grub_tmp | sed "s/console=ttyS0/console=${linux_console0}/" | sed "s/console=tty1/console=${linux_console1}/" > $grub_cfg

# Add any platform specific kernel command line arguments.  This sets
# the $ONIE_EXTRA_CMDLINE_LINUX variable referenced above in
# $GRUB_CMDLINE_LINUX.
if [ -f $onie_root_dir/grub/grub-extra.cfg ]; then
    cat $onie_root_dir/grub/grub-extra.cfg >> $grub_cfg
fi

# Add the logic to support grub-reboot
cat <<EOF >> $grub_cfg
if [ -s \$prefix/grubenv ]; then
  load_env
fi
if [ "\${next_entry}" ] ; then
   set default="\${next_entry}"
   set next_entry=
   save_env next_entry
fi

EOF

# Add menu entries for ONIE -- use the grub fragment provided by the
# ONIE distribution.
$onie_root_dir/grub.d/50_onie_grub >> $grub_cfg

# Copy modified Snappy grub configuration to OEM Snap space
# This allows "sudo snappy update" to persist serial data across
# reboots
#if [ -f "$system_a_mnt/oem/generic-amd64/current/grub.cfg" ]
#then
#  cp $grub_cfg $system_a_mnt/oem/generic-amd64/current/grub.cfg
#else
#  echo failed to find OEM grub.cfg
#  exit 1
#fi

# clean up
umount $system_boot_mnt || {
    echo "Error: Problems umounting"
}


cd /
