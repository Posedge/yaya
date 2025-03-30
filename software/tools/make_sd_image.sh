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

if [ "${DATA_PARTITION_SIZE: -1}" != "G" ]; then
    echo Specify data partition size with \'G\' suffix.
    exit 1
fi
data_part_size=$((${DATA_PARTITION_SIZE: 0:-1} * 1024**3))

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

    # Shell settings
    printf "\nalias ll='ls -lah'\n" | tee -a /home/pi/.bashrc | tee -a /root/.bashrc

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

# Partitioning
# We will be implementing an A/B partitioning scheme, with two system partitions being able to flash each other on the
# fly. This way we will not require flashing a new OS version on the SD card, but we can do it remotely, and we can also
# have a persistent data partition.
partition_sizes=$(sfdisk $output -l --bytes -o SIZE -q)
if [ ! $(echo "$partition_sizes" | wc -l) = 3 ]; then
    echo "Expected two partitions. Something went wrong. Output: $partition_sizes"
    exit 1
fi
echo "Partitions in image: "
sfdisk $output -l
echo ""
echo "Adding extra partitions..."

boot_part_size=$(echo "$partition_sizes" | sed -n 2p)
system_part_size=$(echo "$partition_sizes" | sed -n 3p)
system_part_sectors=$(sfdisk $output -l -o SECTORS -q | sed -n 3p)
system_part_end=$(sfdisk $output -l -o END -q | sed -n 3p)
data_part_sectors=$(( $data_part_size / 512 ))
total_size=$(( $system_part_end * 512 + $system_part_sectors * 512 + $data_part_size + 16*2**20 ))
echo Total size: $total_size bytes

# Temporarily resize the image to fit the entire partitioning scheme,
# otherwise the partitioning tools will refuse to create a table as specified.
truncate -s $total_size $output

# Create a second system partition. The Raspberry Pi OS will also not resize the existing system partition to fill the
# entire SD card if additional partitions are present.
printf "
n
p
3
$(( $system_part_end + 1 ))
+$system_part_sectors
w
" | fdisk $output

# Create a persistent data partition
system2_part_end=$(sfdisk $output -l -o END -q | sed -n 4p)
printf "
n
p
3
$(( $system2_part_end + 1 ))
+$data_part_sectors
w
" | fdisk $output

# Truncate back down to the original image size. We only need the updated partition table in this image. We also don't
# want to override an existing data partition on the Pi.
truncate -s "$(( $system_part_end * 512 ))" $output

echo "Created $output."