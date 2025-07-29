# important directories
ATF_DIR   := arm-trusted-firmware
UBOOT_DIR := u-boot
MFG_DIR   := mfgtools
BR_DIR    := buildroot
FW_DIR    := firmware
CONF_DIR  := configs
OUT_DIR   := out

# compiling settings
CMAKE := cmake

# default target
build: $(OUT_DIR)/flash.bin \
       $(MFG_DIR)/build/uuu/uuu

# Firmware Image Package (FIP) binary
$(OUT_DIR)/flash.bin: $(UBOOT_DIR)/flash.bin | $(OUT_DIR)/
	@cp $< $@

# creation of ephemeral directory
%/:
	@mkdir -p $@

# full cleanup (except uuu)
clean: clean-uboot clean-atf
	@rm -rf $(OUT_DIR)

################################################################################
# BL2, BL31
################################################################################

LPDDR_BINS=$(wildcard $(FW_DIR)/firmware-imx-8.21/firmware/ddr/synopsys/lpddr*)

$(UBOOT_DIR)/flash.bin: $(UBOOT_DIR)/.config  \
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
# Meta Targets
################################################################################

.SECONDARY:

.PHONY: build clean clean-uboot clean-atf clean-uuu

