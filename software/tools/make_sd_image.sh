#!/bin/bash
#
# Script to create an SD card image ready for flashing from the base raspberry pi OS image.

set -e

if [ -z "$2" ]; then
    echo "Usage: $0 <input-base-image> <output-sd-image>"
    exit 1
fi

source ./build_config.env
if [ -z "$$PI_PASSWORD" -o -z "$$WIFI_SSID" -o -z "$$WIFI_PASSWORD" -o -z "$$WIFI_COUNTRY" ]; then
    echo Provide a pi password, wifi SSID, password and country in your build config.
    exit 1
fi
if [ "${DATA_PARTITION_SIZE: -1}" != "G" ]; then
    echo Specify data partition size with \'G\' suffix.
    exit 1
fi
data_part_size=$((${DATA_PARTITION_SIZE: 0:-1} * 1024**3))

input="$1"
output="$2"
PI_PASSWORD_HASH=$(openssl passwd -5 "$PI_PASSWORD")
WIFI_COUNTRY=${WIFI_COUNTRY^^}

rm -rf "$output"
cp "$input" "$output"

# Setup in a chroot environment within the img file.
export customizer_file=$(
    env \
        PI_PASSWORD_HASH="$PI_PASSWORD_HASH" \
        PI_AUTHORIZED_KEY="$PI_AUTHORIZED_KEY" \
        WIFI_SSID="$WIFI_SSID" \
        WIFI_PASSWORD="$WIFI_PASSWORD" \
        WIFI_COUNTRY="$WIFI_COUNTRY" \
        envsubst < ./os/custom.toml.template
)
sudo tools/chroot_image.sh "$output" 'customizer_file' < ./os/chroot_setup.sh

# Partitioning
# We will be implementing an A/B partitioning scheme, with two system partitions being able to flash each other on the
# fly. This way we will not require flashing a new OS version on the SD card, but we can do it remotely, and we can also
# have a persistent data partition.
echo "Partitions in image: "
sfdisk $output -l
if [ ! "$(sfdisk $output -l -q | wc -l)" = 3 ]; then
    echo "Expected two partitions. Something went wrong."
    exit 1
fi
echo ""
echo "Adding extra partitions..."

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
truncate -s "$(( ($system_part_end + 1) * 512 ))" $output

echo "Created $output."