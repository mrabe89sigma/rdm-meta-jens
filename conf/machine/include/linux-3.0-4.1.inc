PREFERRED_VERSION_linux-curie = "3.0.35"

UBOOT_ENTRYPOINT = "0x10800000"
UBOOT_LOADADDRESS = "0x10800000"

PREFERRED_VERSION_firmware-imx = "3.0.35-4.0.0"
PREFERRED_VERSION_imx-lib = "3.10.9-1.0.0"
PREFERRED_VERSION_imx-vpu = "3.10.9-1.0.0"
PREFERRED_VERSION_gpu-viv-bin-mx6q = "3.10.9-1.0.0-hfp"

OVERLAY = "#overlay"
OVERLAYFS = "#overlayfs"
UNIONFS = "none"

# 2.6.37 and later kernels use OMAP_SERIAL, ttyO2
# earlier kernels use ttyS2
SERIAL_CONSOLE = "115200 ttymxc0"

KERNEL_MMC_DEV-emmc = "0"
KERNEL_MMC_DEV-sd = "1"
KERNEL_MMC_DEV = "${KERNEL_MMC_DEV-${WANTED_ROOT_DEV}}"
