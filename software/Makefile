SHELL = bash

# output directory
BUILD := build

build_config.env:
	echo "Create a build_config.env file. See build_config.env.sample for reference."
	exit 1

$(BUILD)/base.img.xz: build_config.env
	mkdir -p $(BUILD)
	source ./build_config.env && \
		curl $$BASE_IMAGE_URL -o $(BUILD)/base.img.xz

$(BUILD)/base.img: $(BUILD)/base.img.xz
	rm -rf $(BUILD)/base.img
	unxz -k $(BUILD)/base.img.xz

.PHONY: base_image
base_image: $(BUILD)/base.img

.PHONY: chroot_base_image
chroot_base_image: $(BUILD)/base.img
	sudo sh tools/chroot_image.sh

.PHONY: clean
clean:
	rm -rf $(BUILD)/*
