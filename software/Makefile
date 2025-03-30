.DELETE_ON_ERROR:
.ONESHELL:
SHELL = bash
.SHELLFLAGS = -ce
all: sd_image

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

$(BUILD)/sd.img: tools/make_sd_image.sh $(BUILD)/base.img build_config.env custom.toml.template
	tools/make_sd_image.sh $(BUILD)/base.img $(BUILD)/sd.img

.PHONY: sd_image
sd_image: $(BUILD)/sd.img

.PHONY: chroot_sd_image
chroot_sd_image: $(BUILD)/sd.img
	sudo tools/chroot_image.sh $(BUILD)/sd.img