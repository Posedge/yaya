#!/bin/bash
#
# Script to write an image to an SD card.

set -e

IMAGE="$1"
DEVICE="$2"
if [ -z "$DEVICE" ]; then
    echo "Usage: $0 <image> <sd-card>"
    exit 1
fi

if echo "$DEVICE" | grep -v '^\/dev\/sd[a-z]$' >/dev/null; then
    echo "Expected device pattern like '/dev/sd?'. Received: $DEVICE"
    exit 1
fi

echo "About the device at $DEVICE:"
echo ""
sudo lsblk -o name,mountpoint,label,size,uuid "$DEVICE"
echo ""
echo "This will override all contents on $DEVICE."
echo "THIS OPERATION CANNOT BE UNDONE!"
read -p "Proceed? [y/N] " REPLY
if [ ! "${REPLY^^}" == "Y" ]; then
    echo "Aborting."
    exit 0
fi

echo ""
echo "Flashing SD card..."
sudo dd if="$IMAGE" of="$DEVICE" bs=16M status=progress
sync
sudo eject "$DEVICE"
echo "Done."