# important directories
ATF_DIR     := arm-trusted-firmware
UBOOT_DIR   := u-boot
FW_DIR      := firmware
OPTEE_DIR   := optee-os
MFG_DIR     := mfgtools
MKIMG_DIR   := imx-mkimage
BR_DIR      := buildroot
LINUX_DIR   := linux
CONF_DIR    := configs
OUT_DIR     := out
OVERLAY_DIR := rootfs-overlay

# compile settings
CMAKE := cmake

################################################################################
# Top-level targets
################################################################################

# default target
build: $(OUT_DIR)/flash.bin \
       $(OUT_DIR)/linux.itb \
       $(MFG_DIR)/build/uuu/uuu

# creation of ephemeral directory
%/:
	@mkdir -p $@

# full cleanup (except uuu)
clean: clean-uboot clean-atf clean-optee clean-linux \
       clean-br clean-mkimage clean-firmware
	@rm -rf $(OUT_DIR)

################################################################################
# Firmware
################################################################################

LPDDR_BINS = $(wildcard $(FW_DIR)/firmware-imx-8.21/firmware/ddr/synopsys/lpddr*)

$(MKIMG_DIR)/iMX93/%: $(FW_DIR)/firmware-imx-8.21/firmware/ddr/synopsys/%
	@cp $< $@

$(MKIMG_DIR)/iMX93/%: $(FW_DIR)/firmware-sentinel-0.11/%
	@cp $< $@

clean-firmware:
	@rm -f $(MKIMG_DIR)/iMX93/lpddr* \
	       $(MKIMG_DIR)/iMX93/mx93a1-ahab-container.img

################################################################################
# Mkimage
################################################################################

$(OUT_DIR)/flash.bin: $(MKIMG_DIR)/iMX93/flash.bin | $(OUT_DIR)/
	@cp $< $@

$(MKIMG_DIR)/iMX93/flash.bin:                                            \
                $(addprefix $(MKIMG_DIR)/iMX93/,$(notdir $(LPDDR_BINS))) \
                $(MKIMG_DIR)/iMX93/mx93a1-ahab-container.img             \
                $(MKIMG_DIR)/iMX93/bl31.bin                              \
                $(MKIMG_DIR)/iMX93/tee.bin                               \
                $(MKIMG_DIR)/iMX93/u-boot-spl.bin                        \
          .WAIT $(MKIMG_DIR)/iMX93/u-boot.bin                            \
          .WAIT $(MKIMG_DIR)/iMX93/u-boot-nodtb.bin                      \
          .WAIT $(MKIMG_DIR)/iMX93/u-boot.img                            \
          .WAIT $(MKIMG_DIR)/iMX93/imx93-11x11-frdm.dtb                  \
          .WAIT $(MKIMG_DIR)/iMX93/mkimage-uboot
	PWD=$(abspath $(MKIMG_DIR))       \
	$(MAKE) -C $(MKIMG_DIR)           \
            SOC=iMX93                 \
            dtbs=imx93-11x11-frdm.dtb \
            TEE_LOAD_ADDR=0xfe000000  \
            CFLAGS="-std=c99"         \
            flash_singleboot

clean-mkimage:
	@rm -f $(MKIMG_DIR)/iMX93/*.bin  \
	       $(MKIMG_DIR)/iMX93/*.img  \
	       $(MKIMG_DIR)/iMX93/*.dtb  \
	       $(MKIMG_DIR)/iMX93/*.hash \
	       $(MKIMG_DIR)/iMX93/mkimage-uboot

################################################################################
# BL2, BL33
################################################################################

$(MKIMG_DIR)/iMX93/%: $(UBOOT_DIR)/%
	@cp $< $@

$(MKIMG_DIR)/iMX93/u-boot-spl.bin: $(UBOOT_DIR)/spl/u-boot-spl.bin
	@cp $< $@

$(MKIMG_DIR)/iMX93/imx93-11x11-frdm.dtb: $(UBOOT_DIR)/arch/arm/dts/imx93-11x11-frdm.dtb
	@cp $< $@

$(MKIMG_DIR)/iMX93/mkimage-uboot: $(UBOOT_DIR)/tools/mkimage
	@cp $< $@

$(UBOOT_DIR)/spl/u-boot-spl.bin                \
$(UBOOT_DIR)/u-boot.bin                        \
$(UBOOT_DIR)/u-boot-nodtb.bin                  \
$(UBOOT_DIR)/u-boot.img                        \
$(UBOOT_DIR)/arch/arm/dts/imx93-11x11-frdm.dtb \
$(UBOOT_DIR)/tools/mkimage: $(UBOOT_DIR)/.config  \
                            $(UBOOT_DIR)/bl31.bin \
                            $(UBOOT_DIR)/tee.bin
	$(MAKE) -C $(UBOOT_DIR) CROSS_COMPILE=aarch64-linux-gnu-

$(UBOOT_DIR)/.config:
	$(MAKE) -C $(UBOOT_DIR) CROSS_COMPILE=aarch64-linux-gnu- imx93_11x11_frdm_defconfig
	cd $(UBOOT_DIR) && ./scripts/kconfig/merge_config.sh .config ../$(CONF_DIR)/uboot.cfg

clean-uboot:
	$(MAKE) -C $(UBOOT_DIR) distclean
	@rm -f $(UBOOT_DIR)/*.img                      \
	       $(UBOOT_DIR)/*.bin                      \
	       $(UBOOT_DIR)/*.mkimage                  \
	       $(MKIMG_DIR)/iMX93/u-boot-spl.bin       \
	       $(MKIMG_DIR)/iMX93/u-boot.bin           \
	       $(MKIMG_DIR)/iMX93/u-boot-nodtb.bin     \
	       $(MKIMG_DIR)/iMX93/u-boot.img           \
	       $(MKIMG_DIR)/iMX93/imx93-11x11-frdm.dtb \
	       $(MKIMG_DIR)/iMX93/mkimage-uboot

################################################################################
# BL31
################################################################################

$(MKIMG_DIR)/iMX93/bl31.bin \
$(UBOOT_DIR)/bl31.bin: $(ATF_DIR)/build/imx93/release/bl31.bin
	@cp $< $@

$(ATF_DIR)/build/imx93/release/bl31.bin:
	$(MAKE) -C $(ATF_DIR)                 \
	        PLAT=imx93                    \
	        SPD=opteed                    \
	        BL32_BASE=0xfe000000          \
	        IMX_BOOT_UART_BASE=0x44380000 \
	        LOG_LEVEL=40                  \
	        bl31

clean-atf:
	$(MAKE) -C $(ATF_DIR) distclean
	@rm -f $(MKIMG_DIR)/iMX93/bl31.bin

################################################################################
# BL32
################################################################################

$(MKIMG_DIR)/iMX93/tee.bin \
$(UBOOT_DIR)/tee.bin: $(OPTEE_DIR)/out/core/tee-raw.bin
	@cp $< $@

# imx-m93evk defaults:
#   CFG_DRAM_BASE   = 0x80000000 =  2G
#   CFG_DDR_SIZE    = 0x80000000 =  2G
#   CFG_TZDRAM_SIZE = 0x01e00000 = 30M
#   CFG_SHMEM_SIZE  = 0x00200000 =  2M (after TZDRAM)
$(OPTEE_DIR)/out/core/tee-raw.bin:
	$(MAKE) -C $(OPTEE_DIR)                           \
	        CFG_ARM64_core=y                          \
	        PLATFORM=imx-mx93evk                      \
	        CROSS_COMPILE=aarch64-linux-gnu-          \
	        CROSS_COMPILE_core=aarch64-linux-gnu-     \
	        CROSS_COMPILE_ta_arm64=aarch64-linux-gnu- \
	        CFG_TEE_BENCHMARK=n                       \
	        CFG_TEE_CORE_LOG_LEVEL=3                  \
	        DEBUG=1                                   \
	        CFG_IMX_ELE=n                             \
	        CFG_WITH_SOFTWARE_PRNG=y                  \
	        O=out

clean-optee:
	@rm -rf $(OPTEE_DIR)/out
	@rm -f $(MKIMG_DIR)/iMX93/tee.bin

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
# uImage Tree
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
$(BR_DIR)/output/images/rootfs.cpio: $(OVERLAY_DIR)/usr $(BR_DIR)/.config
	$(MAKE) -C $(BR_DIR)

# KERN_IMG implies that modules have been compiled
$(OVERLAY_DIR)/usr: $(KERN_IMG)
	$(MAKE) -C $(LINUX_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 modules
	INSTALL_MOD_PATH=../$(OVERLAY_DIR)/usr $(MAKE) -C $(LINUX_DIR) modules_install

$(BR_DIR)/.config: $(BR_DIR)/configs/ass_defconfig
	$(MAKE) -C $(BR_DIR) ass_defconfig

$(BR_DIR)/configs/ass_defconfig: $(CONF_DIR)/buildroot.cfg
	@cp $< $@

clean-br:
	$(MAKE) -C $(BR_DIR) distclean
	@rm -f $(BR_DIR)/configs/ass_defconfig
	@rm -rf $(OVERLAY_DIR)/usr

################################################################################
# Meta Targets
################################################################################

.SECONDARY:

.PHONY: build clean clean-uboot clean-atf clean-optee clean-uuu clean-linux \
        clean-br clean-mkimage clean-firmware

