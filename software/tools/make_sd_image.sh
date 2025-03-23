#!/bin/bash
#
# Script to create an SD card image ready for flashing from the base raspberry pi OS image.

set -e

source ./build_config.env
if [ -z "$$PI_PASSWORD" -o -z "$$WIFI_SSID" -o -z "$$WIFI_PASSWORD" -o -z "$$WIFI_COUNTRY" ]; then
    echo Provide a pi password, wifi SSID, password and country in your build config.
    exit 1
fi

if [ -z "$2" ]; then
    echo "Usage: $0 <input-base-image> <output-sd-image>"
    exit 1
fi

input="$1"
output="$2"
PI_PASSWORD_ENCRYPTED=$(openssl passwd -5 "$PI_PASSWORD")
WIFI_COUNTRY=${WIFI_COUNTRY^^}

rm -rf "$output"
cp "$input" "$output"

customizer_file=$(
    env \
        PI_PASSWORD_ENCRYPTED="$PI_PASSWORD_ENCRYPTED" \
        PI_AUTHORIZED_KEY="$PI_AUTHORIZED_KEY" \
        WIFI_SSID="$WIFI_SSID" \
        WIFI_PASSWORD="$WIFI_PASSWORD" \
        WIFI_COUNTRY="$WIFI_COUNTRY" \
        envsubst < custom.toml.template
)
sudo tools/chroot_image.sh "$output" <<EOF
    echo '$customizer_file' > /boot/custom.toml

    # Startup scripts
    mkdir -p /yaya
    echo > /yaya/setup.sh '
        # Enable wifi
        rfkill unblock wlan
        for filename in /var/lib/systemd/rfkill/*:wlan ; do
            echo 0 > \$filename
        done

        # This file is more of a placeholder at this point.
    '
    echo > /etc/systemd/system/yaya-startup.service '
        [Unit]
        Description=Yaya startup configuration

        [Service]
        Type=simple
        ExecStart=sh /yaya/setup.sh
        RemainAfterExit=yes

        [Install]
        WantedBy=multi-user.target
    '
    systemctl enable yaya-startup.service
EOF

echo "Created $output."