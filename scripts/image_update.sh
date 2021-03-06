#!/bin/bash

echo $PWD

find=`grep "i.MX8QM ARM2" /sys/devices/soc0/machine |wc -l`
if [ $find -eq 1 ]
then
bootimage=imx-boot-imx8qmlpddr4arm2-sd.bin
nfsroot=imx8qmlpddr4arm2
mount=imx8qm_arm2
mmcblock=mmcblock1
fi

find=`grep "i.MX8QM MEK" /sys/devices/soc0/machine |wc -l`
if [ $find -eq 1 ]
then
bootimage=imx-boot-imx8qmmek-sd.bin
nfsroot=imx8qmmek
mount=imx8qm_mek
mmcblock=mmcblock1
fi

find=`grep "i.MX8QXP MEK" /sys/devices/soc0/machine |wc -l`
if [ $find -eq 1 ]
then
bootimage=imx-boot-imx8qxpmek-sd.bin
nfsroot=imx8qxpmek
mount=imx8qxp_mek
mmcblock=mmcblock1
fi

# Need use the new wget version, the busybox version not support the advanced features,
cp -f ./scripts/wget-1.19.tar.gz /tmp
cd /tmp

tar -xaf ./wget-1.19.tar.gz
cd ./wget-1.19

./configure --prefix=/usr -q   \
            --sysconfdir=/etc  \
            --with-ssl=openssl && make -s > /dev/null && make -s install > /dev/null

echo "install wget ...done"

# create mount point
sudo mkdir /rootfs
# mount the server nfsroot
mount -t nfs -o nolock 10.192.242.241:/nfsroot/${mount} /rootfs
cd /rootfs

# get the boot image
wget -N -q --backups=1 http://yb2.am.freescale.net/build-output/Linux_IMX_4.9_morty_trunk_next/latest/common_bsp/imx-boot/${bootimage}
wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A *{nfsroot}*.tar.bz2 --no-directories \
	 http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_4.9_morty_trunk_next/latest/fsl-imx-internal-xwayland/

# update the image, rootfs, flash.bin

for i in *{nfsroot}*.tar.bz2; do
  if [ -f "$i" ]; then ln -sf $i ${nfsroot}.tar.bz2; fi
done

echo "update rootfs ...done"

# program the boot image to the sd-card
sudo dd if=${bootimage} of=/dev/${mmcblock} bs=33k seek=1;sync

echo "update flash.bin ...done"

cd ~
sudo umount /rootfs

echo "update the image.... done"
