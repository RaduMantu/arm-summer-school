# important directories
ATF_DIR     := arm-trusted-firmware
UBOOT_DIR   := u-boot
FW_DIR      := firmware
MFG_DIR     := mfgtools
BR_DIR      := buildroot
LINUX_DIR   := linux
CONF_DIR    := configs
OUT_DIR     := out
OVERLAY_DIR := rootfs-overlay

# compiling settings
CMAKE := cmake

# default target
build: $(OUT_DIR)/flash.bin \
       $(OUT_DIR)/linux.itb \
       $(MFG_DIR)/build/uuu/uuu

# Firmware Image Package (FIP) binary
$(OUT_DIR)/flash.bin: $(UBOOT_DIR)/flash.bin | $(OUT_DIR)/
	@cp $< $@

# creation of ephemeral directory
%/:
	@mkdir -p $@

# full cleanup (except uuu)
clean: clean-uboot clean-atf clean-linux clean-br
	@rm -rf $(OUT_DIR)

################################################################################
# BL2, BL31
################################################################################

LPDDR_BINS = $(wildcard $(FW_DIR)/firmware-imx-8.21/firmware/ddr/synopsys/lpddr*)

$(UBOOT_DIR)/flash.bin: $(UBOOT_DIR)/.config \
                        $(UBOOT_DIR)/bl31.bin \
                        $(UBOOT_DIR)/mx93a1-ahab-container.img \
                        $(addprefix $(UBOOT_DIR)/,$(notdir $(LPDDR_BINS)))
	$(MAKE) -C $(UBOOT_DIR) CROSS_COMPILE=aarch64-linux-gnu-

$(UBOOT_DIR)/.config:
	$(MAKE) -C $(UBOOT_DIR) CROSS_COMPILE=aarch64-linux-gnu- imx93_frdm_defconfig
	cd $(UBOOT_DIR) && ./scripts/kconfig/merge_config.sh .config ../$(CONF_DIR)/uboot.cfg

clean-uboot:
	$(MAKE) -C $(UBOOT_DIR) distclean
	@rm -f $(UBOOT_DIR)/*.img
	@rm -f $(UBOOT_DIR)/*.bin
	@rm -f $(UBOOT_DIR)/*.mkimage

################################################################################
# BL31
################################################################################

$(UBOOT_DIR)/bl31.bin: $(ATF_DIR)/build/imx93/release/bl31.bin
	@cp $< $@

$(ATF_DIR)/build/imx93/release/bl31.bin:
	$(MAKE) -C $(ATF_DIR) PLAT=imx93 SPD=none bl31

clean-atf:
	$(MAKE) -C $(ATF_DIR) distclean

################################################################################
# Firmware
################################################################################

$(UBOOT_DIR)/%: $(FW_DIR)/firmware-imx-8.21/firmware/ddr/synopsys/%
	@cp $< $@

$(UBOOT_DIR)/%: $(FW_DIR)/firmware-sentinel-0.11/%
	@cp $< $@

################################################################################
# Universal Update Utility (UUU)
################################################################################

$(MFG_DIR)/build/uuu/uuu:
	$(CMAKE) -S $(MFG_DIR) -B $(MFG_DIR)/build
	$(CMAKE) --build $(MFG_DIR)/build --target all

# not included in top level clean target
clean-uuu:
	@rm -rf $(MFG_DIR)/build

################################################################################
# Mkimage
################################################################################

KERN_DTB = $(LINUX_DIR)/arch/arm64/boot/dts/freescale/imx93-11x11-evk.dtb
KERN_IMG = $(LINUX_DIR)/arch/arm64/boot/Image
BR_CPIO  = $(BR_DIR)/output/images/rootfs.cpio

# generates the micro image tree
$(OUT_DIR)/linux.itb: $(KERN_IMG) $(KERN_DTB) $(BR_CPIO) | $(OUT_DIR)/
	mkimage -f $(CONF_DIR)/linux.its $@

################################################################################
# Linux
################################################################################

# needed by mkimage
$(KERN_IMG): $(LINUX_DIR)/.config
	$(MAKE) -C $(LINUX_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 Image

# needed by mkimage
$(KERN_DTB): $(LINUX_DIR)/.config
	$(MAKE) -C $(LINUX_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 freescale/imx93-11x11-evk.dtb

$(LINUX_DIR)/.config:
	$(MAKE) -C $(LINUX_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 defconfig

clean-linux:
	$(MAKE) -C $(LINUX_DIR) distclean
	@rm -f $(KERN_IMG)

################################################################################
# Buildroot
################################################################################

# needed by mkimage
$(BR_DIR)/output/images/rootfs.cpio: $(OVERLAY_DIR) $(BR_DIR)/.config
	$(MAKE) -C $(BR_DIR)

# KERN_IMG implies that modules have been compiled
$(OVERLAY_DIR): $(KERN_IMG) | $(OVERLAY_DIR)/
	$(MAKE) -C $(LINUX_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 modules
	INSTALL_MOD_PATH=../$(OVERLAY_DIR)/usr $(MAKE) -C $(LINUX_DIR) modules_install

$(BR_DIR)/.config: $(BR_DIR)/configs/ass_defconfig
	$(MAKE) -C $(BR_DIR) ass_defconfig

$(BR_DIR)/configs/ass_defconfig: $(CONF_DIR)/buildroot.cfg
	@cp $< $@

clean-br:
	$(MAKE) -C $(BR_DIR) distclean
	@rm -f $(BR_DIR)/configs/ass_defconfig
	@rm -rf $(OVERLAY_DIR)

################################################################################
# Meta Targets
################################################################################

.SECONDARY:

.PHONY: build clean clean-uboot clean-atf clean-uuu clean-linux clean-br \
        modules-linux

