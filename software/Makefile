.DELETE_ON_ERROR:
.ONESHELL:
SHELL = bash
.SHELLFLAGS = -ce

# output directory
BUILD := build

build_config.env:
	echo "Create a build_config.env file. See build_config.env.sample for reference."
	exit 1

.PHONY: clean
clean:
	rm -rf $(BUILD)/*

$(BUILD)/base.img.xz: base_image.env
	mkdir -p $(BUILD)
	source ./base_image.env
	curl $$BASE_IMAGE_URL -o $(BUILD)/base.img.xz

$(BUILD)/base.img: $(BUILD)/base.img.xz
	rm -rf $(BUILD)/base.img
	unxz -k $(BUILD)/base.img.xz

$(BUILD)/sd.img: $(BUILD)/base.img
	source ./build_config.env
	if [ -z "$$PI_PASSWORD" -o -z "$$WIFI_SSID" -o -z "$$WIFI_PASSWORD" ]; then
		echo Provide a pi password, wifi SSID and wifi password in your build config.
		exit 1
	fi

	cp $(BUILD)/base.img $(BUILD)/sd.img
	sudo tools/chroot_image.sh $(BUILD)/sd.img <<EOF
		(echo "$$PI_PASSWORD"; echo "$$PI_PASSWORD") | passwd pi || exit 1

		systemctl enable ssh

		echo > /etc/wpa_supplicant/wpa_supplicant.conf '
			country=ch
			update_config=1
			ctrl_interface=/var/run/wpa_supplicant

			network={
				scan_ssid=1
				ssid="$$WIFI_SSID"
				psk="$$WIFI_PASSWORD"
			}
		'
		echo "Created wifi config."

		# TODO any updates to firstboot needed?
	EOF

.PHONY: sd_image
sd_image: $(BUILD)/sd.img

.PHONY: chroot_sd_image
chroot_sd_image: $(BUILD)/sd.img
	sudo tools/chroot_image.sh $(BUILD)/sd.img