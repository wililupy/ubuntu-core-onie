WARNING! YOU MAY BRICK YOUR ONIE SWITCH! Make sure you have a way to restore
ONIE before proceeding.  This was tested on snappy 16.04 using virtual
ONIE switches in an KVM.  It does not include ASIC drivers.

This also include the inject_kernel.sh script, which is only required if changing
the Kernel in 15.04. Kernel snaps are different. This will make a generic ONIE image
with 16.04.

Contents
--------
mksnappytgz.sh
  * reads standard snappy image and creates tarballs in installer/
mksnappyonieinstaller.sh
  * combines the onie-installer shell script (snappy-onie-installer.bin.1.sh) and the snappy tarballs
snappy-onie-installer.bin.1.sh
  * the script that executes on an ONIE switch (after onie downloads)
installer/
  * embedded in the onie-installer script
installer/installer.conf
  * YOU MUST EDIT THIS BEFORE BUILDING A NEW IMAGE to for serial port settings

How to use
----------
IMPORTANT: Modify installer/installer.conf if you have specific serial port settings

download a snappy image, modify mksnappytgz.sh to read it
  i.e. wget http://people.canonical.com/~mvo/all-snaps/amd64-all-snap.img.xz
  then unxz amd64-all-snap.img.xz

$ ./mksnappytgz.sh # copies snappy into installer/
$ ./mksnappyonieinstaller.sh # creates the installer called onie-installer-$installer.bin

You now have a NOS installer for snappy (embedded), you can, for example, copy onie-installer-$installer.bin to "onie-installer" to /var/www/html in MAAS or in a tftp directory, or any other standard ONIE location

Make sure you have kpartx installed on your machine. The mksnappytgz.sh script uses this to mount the image.

If you need a virtual ONIE switch as well, you can find a README here:
http://people.canonical.com/~dduffey/files/OCP/snappy-onie-15.04/

How it was built
----------------
onie-installer-$installer.bin is an "ONIE NOS Installer" shell script with embedded tarball of snappy.  The .bin is downloaded on a switch via ONIE.  The shell script executes,
 * creates partitions / filesystems on the switch
 * untars snappy to those filesystems
 * updates the snappy grub config to allow it to get back to ONIE
 * updates the bootloader to point to the NOS (snappy) grub, not ONIE

