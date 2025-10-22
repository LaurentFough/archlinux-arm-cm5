#!/usr/bin/env bash

#set -e
#set -n
set -u
set -v
set -x

#= Download and Install Arch Linux Arm to a Rpi4-64
#= usage: ./cm5_hd_burner.sh /dev/sdX

#= Check if user is root or sudo
if ! [ $( id -u ) = 0 ]; then
    echo "[cm5_hd_burner] Please run this script as sudo or root" 1>&2
    exit 1
fi

HD_PARTDEFAULT=/dev/sdX
if [ "$1" ]; then
    echo "[cm5_hd_burner] Chose: HD/NVME/SD partition: $1"
    HD_PARTDEFAULT=$1
else
    echo "[cm5_hd_burner] No user argument using default value: ${HD_PARTDEFAULT}"
fi

#= Export settings
export HD_DEV=${HD_PARTDEFAULT}
export HD_PARTBOOT=${HD_DEV}1
export HD_PARTROOT=${HD_DEV}2

mkdir -p -v /mnt/hd && export HD_MOUNT=/mnt/hd
mkdir -p -v /tmp/rpi/cm5 && export DL_DIR=/tmp/rpi/cm5

export DIST_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
echo -e -n "[cm5_hd_burner]\n Settings:\nHD_DEV=${HD_DEV}\nBOOT=${HD_PARTBOOT}\nROOT=${HD_PARTROOT}\nHD_MOUNT=${HD_MOUNT}\nDL_DIR=${DL_DIR}\n"

#= Download. Never cache.
mkdir -p -v ${DL_DIR}
(
    cd ${DL_DIR} && \
    curl -JLO http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
)

#= Clean disk
sfdisk --quiet --wipe always ${HD_DEV} << EOF
,512M,0c,
,,,
EOF

#= Format disk
yay -S dosfstools && mkfs.vfat -F 32 ${HD_PARTBOOT}
mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 -F ${HD_PARTROOT}

#= Mount partitions
#= mount root
mkdir -p -v ${HD_MOUNT}
mount ${HD_PARTROOT} ${HD_MOUNT}
#= mount boot
mkdir -p -v ${HD_MOUNT}/boot
mount ${HD_PARTBOOT} ${HD_MOUNT}/boot

#= Extract into HD
bsdtar -xpf ${DL_DIR}/ArchLinuxARM-rpi-aarch64-latest.tar.gz -C ${HD_MOUNT}

#= Change fstab
sed -i 's/mmcblk0/mmcblk1/' ${HD_MOUNT}/etc/fstab

#= Headless Boot - Replace Uboot
mkdir -p -v ${DL_DIR}/uboot
pushd ${DL_DIR}/uboot

#curl -JLO https://pkg.freebsd.org/FreeBSD:13:aarch64/latest/All/u-boot-rpi-arm64-2020.10.txz
curl -JLO https://pkg.freebsd.org/FreeBSD:14:aarch64/latest/All/u-boot-rpi-arm64-2025.04.txz
tar -xfv u-boot-rpi-arm64-2025.04.txz
cp -v ./usr/local/share/u-boot/u-boot-rpi-arm64/u-boot.bin ${HD_MOUNT}/boot/kernel8.img

popd

#= Sync and Umount
sync
umount -R ${HD_MOUNT}
