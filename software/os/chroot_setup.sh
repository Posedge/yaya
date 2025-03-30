# Intended to be run in a chroot environment within the Pi image.

echo "$customizer_file" > /boot/custom.toml

# Shell settings
printf "\nalias ll='ls -lah'\n" | tee -a /home/pi/.bashrc | tee -a /root/.bashrc

# Startup scripts
mkdir -p /yaya
echo > /yaya/setup.sh '
    # Enable wifi
    rfkill unblock wlan
    for filename in /var/lib/systemd/rfkill/*:wlan ; do
        echo 0 > $filename
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