#!/bin/bash

# Find platform type in DT kernel
determine_platform_dt()
{
    local find=0

    find=`grep "MX6Q" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx63_d
    fi

    find=`grep "MX6DL" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx61_d
    fi

    find=`grep "MX6SL" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx60_d
    fi

    find=`grep "MX6SX" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx62_d
    fi
    find=`grep "MX8QM" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        #vte=vte_mx82
	vte=vte_IMX8QM-ARM2
    fi
    find=`grep "MX8QXP" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx81
    fi
    find=`grep "MX8MQ" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx82
    fi
    find=`grep "MX6 Quad SABRE Smart Device" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6q-sabresd-auto
    fi

    find=`grep "MX6 DualLite SABRE Smart Device" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6dl-sabresd-auto
    fi

    find=`grep "MX6 Quad SABRE Automotive" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6q-sabreauto-auto
    fi

    find=`grep "MX6 DualLite/Solo SABRE Automotive" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6dl-sabreauto-auto
    fi

    find=`grep "MX6 SoloLite EVK" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6sl-evk-auto
    fi

    find=`grep "MX6 SoloX 17x17 ARM2" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6sx-17x17-arm2-auto
    fi

    find=`grep "MX6 SoloX 19x19 ARM2" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6sx-19x19-arm2-auto
    fi

    find=`grep "MX6 SoloX SDB" /sys/devices/soc0/machine |wc -l`
    if [ $find -eq 1 ]
    then
	testfile=lava-imx6sx-sabresd-auto
    fi

}


determine_platform_dt

if [ ! -d /mnt ]
then
    mkidr mnt
fi

if [ ! -d /mnt/nfs ]
then
    mkdir /mnt/nfs
fi

findmnt /mnt/nfs

if [ $? -ne 0 ];then
    mount -t nfs -o nolock 10.192.244.37:/rootfs/wb /mnt/nfs
fi

#echo ${vte}
#echo ${testfile}

echo `pwd`

#lava_mytest="lava-vte-mytest.sh"

#cp -f ./scripts/${lava_mytest} /mnt/${vte}

#cp -f ./scripts/${testfile} /mnt/${vte}/runtest

cd /mnt/nfs/${vte}
. ./manual_test

bash -c "$*"

#$*
# No need umount /mnt here #
#./${lava_mytest} ${testfile}
