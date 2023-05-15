

################################################################################
####################### Important directories & binaries #######################
################################################################################

ROOT          ?= $(shell realpath ..)
BUILD_DIR     ?= $(ROOT)/build
UBOOT_DIR     ?= $(ROOT)/u-boot
ATF_DIR       ?= $(ROOT)/imx-atf
LINUX_DIR     ?= $(ROOT)/linux
TOOLCHAIN_DIR ?= $(ROOT)/toolchains
IMX_FW_DIR    ?= $(BUILD_DIR)/firmware-imx-$(IMX_FW_VER)

# cross compiler prefix
AARCH64_CROSS_COMPILE ?= $(TOOLCHAIN_DIR)/aarch64/bin/aarch64-none-linux-gnu-

# firmware package components
BL31_BIN = $(ATF_DIR)/build/imx8mq/release/bl31.bin
FW_BINS  = lpddr4_pmu_train_1d_dmem.bin \
           lpddr4_pmu_train_1d_imem.bin \
           lpddr4_pmu_train_2d_dmem.bin \
           lpddr4_pmu_train_2d_imem.bin \
           signed_hdmi_imx8m.bin


################################################################################
####################### Top-level build & clean targets ########################
################################################################################

atf: $(BL31_BIN)

uboot: $(UBOOT_DIR)/flash.bin

clean: atf-clean firmware-clean uboot-clean

################################################################################
############################# ARM Trusted Firmware #############################
################################################################################

ATF_FLAGS = CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) \
            PLAT=imx8mq                            \
            SPD=none                               \

################################### targets ####################################

# bl31 generation target
$(BL31_BIN):
	$(MAKE) -C $(ATF_DIR) $(ATF_FLAGS) bl31

# clean target
atf-clean:
	$(MAKE) -C $(ATF_DIR) distclean


################################################################################
###################### i.MX firmware (for Low-Power DDR) #######################
################################################################################

# look at dirname of link in <firmware> target to see other options
IMX_FW_VER ?= 8.15

################################### targets ####################################

$(info $(IMX_FW_DIR))

$(IMX_FW_DIR)/firmware/ddr/synopsys/%.bin \
$(IMX_FW_DIR)/firmware/hdmi/cadence/%.bin: firmware

# obtain i.MX firmware
firmware:
	wget \
	  http://sources.buildroot.net/firmware-imx/firmware-imx-$(IMX_FW_VER).bin
	chmod +x firmware-imx-$(IMX_FW_VER).bin
	./firmware-imx-$(IMX_FW_VER).bin --auto-accept
	rm -f firmware-imx-$(IMX_FW_VER).bin


# clean target
firmware-clean:
	@rm -rf $(IMX_FW_DIR)

################################################################################
#################################### U-Boot ####################################
################################################################################

UBOOT_DEPS = $(patsubst %,$(UBOOT_DIR)/%,$(FW_BINS)) \
             $(UBOOT_DIR)/bl31.bin                   \
             $(UBOOT_DIR)/.config

UBOOT_FLAGS = CROSS_COMPILE=$(AARCH64_CROSS_COMPILE)

################################### targets ####################################

# firmware package generation target (bl2, bl33 are implied)
$(UBOOT_DIR)/flash.bin: $(UBOOT_DEPS)
	$(MAKE) -C $(UBOOT_DIR) $(UBOOT_FLAGS) flash.bin

# generate config file
$(UBOOT_DIR)/.config:
	$(MAKE) -C $(UBOOT_DIR) $(UBOOT_FLAGS) pico-imx8mq_defconfig

# copy lpddr firmware binaries to u-boot root
# TODO: first dep expanded from flash.bin is considered ephemeral and deleted
#       .PRECIOUS doesn't work, .SECONDARY causes access error; find a solution
$(UBOOT_DIR)/%.bin: $(IMX_FW_DIR)/firmware/ddr/synopsys/%.bin
	@cp $< $@

$(info $(UBOOT_DIR))

# copy hdmi firmware binaries to u-boot root
$(UBOOT_DIR)/%.bin: $(IMX_FW_DIR)/firmware/hdmi/cadence/%.bin
	@cp $< $@

# copy bl31 binary to u-boot root
$(UBOOT_DIR)/bl31.bin: $(BL31_BIN)
	@cp $< $@

# clean target
uboot-clean:
	$(MAKE) -C $(UBOOT_DIR) distclean
	@rm -f $(UBOOT_DEPS)
	@rm -f $(UBOOT_DIR)/signed-hdmi*

