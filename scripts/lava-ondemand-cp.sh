#!/bin/bash

SERVER=10.192.242.208
USER=r64343
WORKSP="/home/r64343/workspace/linux-imx_virgin/linux-imx"
BUILD1="build/imx_v8_defconfig/arch/arm64/boot"
BUILD2="build/imx_v7/arch/arm/boot"
TARGET="/nfsroot/ondemand"

scp ${USER}@${SERVER}:${WORKSP}/${ BUILD1}/dts/freescale/*.dtb $TARGET/
scp ${USER}@${SERVER}:${WORKSP}/${ BUILD2}/dts/*.dtb $TARGET/
scp ${USER}@${SERVER}:${WORKSP}/${BUILD2}/zImage $TARGET/
scp ${USER}@${SERVER}:${WORKSP}/${BUILD1}/Image $TARGET/
