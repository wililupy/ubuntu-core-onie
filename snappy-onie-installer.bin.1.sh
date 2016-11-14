#!/bin/sh

# Untar and launch install script in a tmpfs
cur_wd=$(pwd)
archive_path=$(realpath "$0")
tmp_dir=$(mktemp -d)
if [ "$(id -u)" = "0" ] ; then
    mount -t tmpfs tmpfs-installer $tmp_dir || exit 1
fi
cd $tmp_dir
echo -n "Preparing image archive ..."
sed -e '1,/^exit_marker$/d' $archive_path | tar xf - || exit 1
echo " OK."
cd $cur_wd
if [ -n "$extract" ] ; then
    # stop here
    echo "Image extracted to: $tmp_dir"
    if [ "$(id -u)" = "0" ] && [ ! -d "$extract" ] ; then
        echo "To un-mount the tmpfs when finished type:  umount $tmp_dir"
    fi
    exit 0
fi

$tmp_dir/installer/install.sh
rc="$?"

# clean up
if [ "$(id -u)" = "0" ] ; then
    umount $tmp_dir
fi
rm -rf $tmp_dir

exit $rc
exit_marker