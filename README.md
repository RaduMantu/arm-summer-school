# Arm Summer School

Code repository for the ARM Summer School. Contains the complete setup for
building the Firmware Image Package (FIP) for the
[FRDM i.MX 93 Development Board][board], as well as a working Linux distribution
and a custom kernel, paired with OP-TEE as a trusted OS. You can find the
board's user manual [here][user-manual] but you'll need an NXP account. Also
check out the i.MX 93 Application Processor Reference Manual [here][ref-manual]
for identifying the memory map.

Lectures and laboratories can be found on our [open courseware][ocw].

## Repo structure

```
arm-summer-school
├── arm-trusted-firmware/
├── u-boot/
├── mfgtools/
├── buildroot/
├── linux/
├── configs/
├── firmware/
├── Makefile
└── README.md
```

- **arm-trusted-firmware:** BL31 (and demo implementations for other BLs)
- **u-boot:** BL2 and BL33
- **mfgtools:** Universal Update Utility (UUU) for flashing the FIP
- **buildroot:** Framework for generating a linux distro from scratch
- **linux:** The kernel
- **configs:** Extra configuration files (e.g., enabling USB in BL2)
- **firmware:** NXP firmware self-extracting scripts
- **Makefile:** Builds the entire project
- **README.md:** This file

## Preparation

Initialize the submodules (might take a while for `linux/`):

```bash
$ git submodule update --init --recursive
```

Extract the firmware directories from the self-extracting scripts only once:

```bash
$ pushd firmware/
$ ./firmware-imx-8.21.bin --auto-accept
$ ./firmware-sentinel-0.11.bin --auto-accept
$ popd
```

Patch NXP's U-Boot fork with the mainline patch that adds the USB driver.

```bash
$ pushd u-boot
$ patch -p1 <../patches/0002-imx-imx93_frdm-Add-basic-board-support.patch
$ popd
```

## Build and run

Make sure that the switches are set in the `0001` position (inverted order on
the board) for SPD loading over USB of the FIP to work. Connect all three USB
cables for PWR, SPD, DBG output.

```bash
$ make -j $(nproc)

$ sudo picocom -b 115200 /dev/ttyACM0
$ sudo ./mfgtools/build/uuu/uuu -v -b spl out/flash.bin
```

For a first time setup, expose one of the two eMMC devices via USB Mass Storage
to your host. Create a parition table, a parition, then format it and store
`linux.itb` on it:

```bash
# (once) expose eMMC 0 via USB controller 0
u-boot=> ums 0 mmc 0

# (once) format eMMC block device
$ fdisk /dev/sda
Command: g          # new GPT partition table
Command: n          # new partition
Command: w          # write changes to disk

# (once) format partition and mount it
$ mkfs.vfat /dev/sda1
$ mount /dev/sda1 /mnt

# (once) copy uImage Tree on board's eMMC
$ cp out/linux.itb /mnt
$ umount .mnt
u-boot=> Ctrl^C

# (otional) check that file has been written to eMMC
u-boot=> fatls mmc 0:1
 419025723   linux.itb

# load it in memory and boot
u-boot> fatload mmc 0:1 0x90000000 linux.itb
419025723 bytes read in 1403 ms (284.8 MiB/s)

# (optional) check that the load addr does not overlap with
# the ramdisk, kernel or fdt once extracted from the itb
u-boot=> fdt list /images/kernel load
load = <0xc0000000>
u-boot=> fdt list /images/fdt load
load = <0xc7000000>
u-boot=> fdt list /images/initrd load
load = <0xc8000000>

# boot kernel from itb
u-boot=> bootm 0x90000000
```

[board]: https://www.nxp.com/design/design-center/development-boards-and-designs/frdm-i-mx-93-development-board:FRDM-IMX93
[user-manual]: https://www.nxp.com/webapp/Download?colCode=UM12181&isHTMLorPDF=HTML
[ref-manual]: https://www.nxp.com/webapp/Download?colCode=IMX93RM
[ocw]: https://ocw.cs.pub.ro/courses/ass
