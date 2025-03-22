#!/bin/bash
#
# Script to create an SD card image ready for flashing from the base raspberry pi OS image.

set -e

source ./build_config.env
if [ -z "$$PI_PASSWORD" -o -z "$$WIFI_SSID" -o -z "$$WIFI_PASSWORD" ]; then
    echo Provide a pi password, wifi SSID and wifi password in your build config.
    exit 1
fi

if [ -z "$1" -o -z "$2" ]; then
    echo "Usage: $0 <input-base-image> <output-sd-image>"
    exit 1
fi

input="$1"
output="$2"

rm -rf "$output"
cp "$input" "$output"
sudo tools/chroot_image.sh "$output" <<EOF
    (echo "$PI_PASSWORD"; echo "$PI_PASSWORD") | passwd pi || exit 1

    systemctl enable ssh

    echo > /etc/wpa_supplicant/wpa_supplicant.conf '
        country=ch
        update_config=1
        ctrl_interface=/var/run/wpa_supplicant

        network={
            scan_ssid=1
            ssid="$WIFI_SSID"
            psk="$WIFI_PASSWORD"
        }
    '
    echo "Created wifi config."

    # TODO any updates to firstboot needed?
EOF

echo "Created $output."