# Arm Summer School

Code repository for the ARM Summer School. Contains the complete setup for
building the Firmware Image Package (FIP) for the
[FRDM i.MX 93 Development Board][board], as well as a working Linux distribution
and a custom kernel, paired with OP-TEE as a trusted OS. You can find the
board's user manual [here][manual] but you'll need an NXP account.

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

## Build and run

Make sure that the switches are set in the `0001` position (inverted order on
the board) for SPD loading over USB of the FIP to work. Connect all three USB
cables for PWR, SPD, DBG output.

```bash
$ make -j $(nproc)

$ sudo picocom -b 115200 /dev/ttyACM0
$ sudo ./mfgtools/build/uuu/uuu -v -b spl out/flash.bin
```

[board]: https://www.nxp.com/design/design-center/development-boards-and-designs/frdm-i-mx-93-development-board:FRDM-IMX93
[manual]: https://www.nxp.com/webapp/Download?colCode=UM12181&isHTMLorPDF=HTML
[ocw]: https://ocw.cs.pub.ro/courses/ass
