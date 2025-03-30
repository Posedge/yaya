.DELETE_ON_ERROR:
.ONESHELL:
SHELL = bash
.SHELLFLAGS = -ce
all: sd_image

# output directory
BUILD := build
IMAGE_TOOLS := tools/make_sd_image.sh tools/chroot_image.sh
OS_SETUP_FILES := os/custom.toml.template os/chroot_setup.sh

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

$(BUILD)/sd.img: $(BUILD)/base.img build_config.env $(IMAGE_TOOLS) $(OS_SETUP_FILES)
	tools/make_sd_image.sh $(BUILD)/base.img $(BUILD)/sd.img

.PHONY: sd_image
sd_image: $(BUILD)/sd.img

.PHONY: chroot_sd_image
chroot_sd_image: $(BUILD)/sd.img
	sudo tools/chroot_image.sh $(BUILD)/sd.img