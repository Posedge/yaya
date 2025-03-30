#!/bin/bash
#
# Script using QEMU to emulate a Raspberry Pi and open a shell within the image environment.
# Needs to be executed as root. Usage:
#
# chroot_image.sh <image-file> <<EOF
#   echo "Hello from pi!"
#  EOF
#
# Much of this script is adapted from this gist:
# https://gist.github.com/jkullick/9b02c2061fbdf4a6c4e8a78f1312a689

set -e

IMAGE="$1"
if [ -z "$IMAGE" ]; then
    echo "No image file provided. Run this script as '$0 <image>'."
    exit 1;
fi

. ./build_config.env
if test -z "$PI_MOUNT_POINT"; then
    echo "Empty mount point. Check your configuration."
    exit 1
fi
mkdir -p $PI_MOUNT_POINT

function unmount_loop {
    # Unmount any existing image
    for i in $(losetup -j $IMAGE | cut -d: -f1); do
        echo Unmounting $IMAGE at $i...
        losetup -d $i
    done
}

function clean {
    echo Cleaning up...

    umount $PI_MOUNT_POINT/dev/pts
    umount $PI_MOUNT_POINT/dev
    umount $PI_MOUNT_POINT/sys
    umount $PI_MOUNT_POINT/proc
    umount $PI_MOUNT_POINT/boot
    umount $PI_MOUNT_POINT
    unmount_loop
}

function main {
    unmount_loop

    # Mount image (boot and first system partition only)
    LOOP_BOOT=`losetup -f`
    echo "Loop device for boot partition: $LOOP_BOOT"
    BOOT_START=$(sfdisk $IMAGE -l -o START -q | sed -n 2p)
    losetup $LOOP_BOOT $IMAGE -o $(( $BOOT_START * 512 ))

    LOOP_SYSTEM=`losetup -f`
    echo "Loop device for system partition: $LOOP_SYSTEM"
    SYSTEM_START=$(sfdisk $IMAGE -l -o START -q | sed -n 3p)
    losetup $LOOP_SYSTEM $IMAGE -o $(( $SYSTEM_START * 512 ))

    # Mount image partitions
    echo Mounting raspberry pi image to: $PI_MOUNT_POINT
    mount -o rw ${LOOP_SYSTEM} $PI_MOUNT_POINT
    mount -o rw ${LOOP_BOOT} $PI_MOUNT_POINT/boot

    # Bind mounts from running system
    mount --bind /dev $PI_MOUNT_POINT/dev
    mount --bind /sys $PI_MOUNT_POINT/sys
    mount --bind /proc $PI_MOUNT_POINT/proc
    mount --bind /dev/pts $PI_MOUNT_POINT/dev/pts

    cp /usr/bin/qemu-arm-static $PI_MOUNT_POINT/usr/bin/

    chroot $PI_MOUNT_POINT /bin/bash

    clean
}

main