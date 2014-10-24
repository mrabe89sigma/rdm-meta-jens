#!/bin/sh
### BEGIN INIT INFO
# Provides:             flash-production
# Required-Start:       $local_fs
# Required-Stop:      $local_fs
# Default-Start:
# Default-Stop:
# Short-Description:  Flash internal/external sd-card
### END INIT INFO

set -x

SDCARD_DEVICE="/dev/mmcblk0"
if test -e /dev/mmcblk1
then
    SDCARD_DEVICE="/dev/mmcblk1"
fi

UNION_SHADOWS=".shadow/.etc .shadow/.home .shadow/.var_lib"

# use last image container
for c in /data/.flashimg/*-complete.cpi /data/flashimg/*-complete
do
    if [ -f $c -o -d $c ]
    then
	IMAGE_CONTAINER="$c"

	echo 0 >/sys/class/leds/user1/brightness
	echo mmc0 >/sys/class/leds/user1/trigger
	echo 0 >/sys/class/leds/user2/brightness
	echo mmc1 >/sys/class/leds/user2/trigger

	break
    fi
done

for tmp in /var/tmp /data/tmp /tmp
do
    touch ${tmp}/$$ && rm ${tmp}/$$ && TEMP_DIR=${tmp} && break
done

cd ${TEMP_DIR}/

if [ -d "${IMAGE_CONTAINER}" ]
then
    . "${IMAGE_CONTAINER}"/.settings

    BOOT_SPACE="8192"
    IMAGE_ROOTFS_ALIGNMENT="4096"

    BOOTFS_SIZE=$(expr 1024 \* 32)

    SDCARD_SIZE=`fdisk -l $SDCARD_DEVICE | grep "Disk $SDCARD_DEVICE" | awk '{print $5}'`
    SDCARD_SIZE=$(expr $SDCARD_SIZE \/ 1024)

    if test "$DEV" -eq 0
    then
	ROOTFS_SIZE=$(expr 1024 \* 512)
	RECOVERY_SIZE=$(expr 1024 \* 128)
    else
	ROOTFS_SIZE=$(expr 1024 \* 1024)
	RECOVERY_SIZE=$(expr 1024 \* 512)
    fi

    BOOT_SPACE_ALIGNED=$(expr ${BOOTFS_SIZE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
    BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE_ALIGNED} - ${BOOT_SPACE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})

    BOOT_SPACE_START=${IMAGE_ROOTFS_ALIGNMENT}
    BOOT_SPACE_END=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_SPACE_ALIGNED})

    ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
    ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE_ALIGNED} - ${ROOTFS_SIZE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})

    ROOTFS_SPACE_START=${BOOT_SPACE_END}
    ROOTFS_SPACE_END=$(expr ${ROOTFS_SPACE_START} \+ ${ROOTFS_SIZE_ALIGNED})

    RECOVERY_SIZE_ALIGNED=$(expr ${RECOVERY_SIZE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
    RECOVERY_SIZE_ALIGNED=$(expr ${RECOVERY_SIZE_ALIGNED} - ${RECOVERY_SIZE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})

    RECOVERFS_SPACE_START=${ROOTFS_SPACE_END}
    RECOVERFS_SPACE_END=$(expr ${RECOVERFS_SPACE_START} \+ ${RECOVERY_SIZE_ALIGNED})

    # wipe them out ... all of them
    dd if=/dev/zero of=${SDCARD_DEVICE} bs=1M count=512

    parted -s ${SDCARD_DEVICE} mklabel msdos
    parted -s ${SDCARD_DEVICE} unit KiB mkpart primary ${BOOT_SPACE_START} ${BOOT_SPACE_END}
    parted -s ${SDCARD_DEVICE} unit KiB mkpart primary ${ROOTFS_SPACE_START} ${ROOTFS_SPACE_END}
    parted -s ${SDCARD_DEVICE} unit KiB mkpart primary ${RECOVERFS_SPACE_START} ${RECOVERFS_SPACE_END}
    parted -s ${SDCARD_DEVICE} unit KiB mkpart primary ${RECOVERFS_SPACE_END} $(expr ${SDCARD_SIZE} - 1)
    parted ${SDCARD_DEVICE} print

    mkdir -p ${TEMP_DIR}/flashimg/root/boot ${TEMP_DIR}/flashimg/root/data

    mkfs.ext2 -I128 -L "boot-${MACHINE}" ${SDCARD_DEVICE}p1
    mount ${SDCARD_DEVICE}p1 ${TEMP_DIR}/flashimg/root/boot
    mkfs.ext4 -L "data-${MACHINE}" ${SDCARD_DEVICE}p4
    mount ${SDCARD_DEVICE}p4 ${TEMP_DIR}/flashimg/root/data

    dd if=${IMAGE_CONTAINER}/${UBOOT_BIN} of=${SDCARD_DEVICE} seek=2 skip=${UBOOT_PADDING} bs=512
    dd if=${IMAGE_CONTAINER}/${ROOTIMG} of=${SDCARD_DEVICE}p2 bs=1M
    dd if=${IMAGE_CONTAINER}/${RECOVERIMG} of=${SDCARD_DEVICE}p3 bs=1M

    (cd "${IMAGE_CONTAINER}" && tar cf - ${KERNEL}) | (cd ${TEMP_DIR}/flashimg/root/boot && tar xf - && chown -R root:root . && ${KERNEL_PREPARE} && ${KERNEL_SANITIZE})

    mkdir -p ${TEMP_DIR}/flashimg/root/data/tmp
    chmod 01777 ${TEMP_DIR}/flashimg/root/data/tmp
    (cd ${TEMP_DIR}/flashimg/root/data && mkdir -p ${UNION_SHADOWS})

    umount ${TEMP_DIR}/flashimg/root/boot
    umount ${TEMP_DIR}/flashimg/root/data

    sync

    test -e /dev/mmcblk1 || reboot
elif [ -f "${IMAGE_CONTAINER}" ]
then
    tar xjf "${IMAGE_CONTAINER}" .settings
    . ./.settings

    ROOTDEV=`mount | grep "on / type" | sed -e 's/ on.*//'`
    if [ $(echo ${ROOTDEV} | egrep 'p2$') ]
    then
	REGULAR=Y
	tar xjf "${IMAGE_CONTAINER}" -O ${UBOOT_BIN} | dd of=${SDCARD_DEVICE} seek=2 skip=${UBOOT_PADDING} bs=512
	tar xjf "${IMAGE_CONTAINER}" -O ${RECOVERIMG} | dd of=${SDCARD_DEVICE}p3 bs=1M

	mount /boot

	(cd /boot && tar xjf "${IMAGE_CONTAINER}" ${KERNEL} && chown -R root:root . && ${KERNEL_PREPARE})

	reboot
    elif [ $(echo ${ROOTDEV} | egrep 'p3$') ]
    then
	RECOVERY=Y
	mount /boot
	mount /data

	tar xjf "${IMAGE_CONTAINER}" -O ${ROOTIMG} | dd of=${SDCARD_DEVICE}p2 bs=1M
	(cd /boot && ${KERNEL_SANITIZE})
	(cd /data && mkdir -p ${UNION_SHADOWS})

        rm -f /etc/volatile.cache

	rm -f "${IMAGE_CONTAINER}"

	reboot
    else
	echo "Cannot detect normal mode nor recovery mode. Fix and retry."
	exit 1
    fi
fi
