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
	if [ -z "$$PI_PASSWORD" ]; then
		echo Provide a password in your build config.
		exit 1
	fi
	cp $(BUILD)/base.img $(BUILD)/sd.img
	sudo tools/chroot_image.sh $(BUILD)/sd.img <<EOF
		(echo "$$PI_PASSWORD"; echo "$$PI_PASSWORD") | passwd pi || exit 1
		systemctl enable ssh
		# TODO any updates to firstboot needed?
	EOF

.PHONY: sd_image
sd_image: $(BUILD)/sd.img

.PHONY: chroot_sd_image
chroot_sd_image: $(BUILD)/sd.img
	sudo tools/chroot_image.sh $(BUILD)/sd.img