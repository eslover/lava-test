#!/bin/bash

# Find platform type in DT kernel
determine_platform_dt()
{
    local find=0

    find=`grep "MX8QM" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        #vte=vte_mx82
	vte=vte_IMX8QM-MEK
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

    find=`grep "MX8MM" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx84
    fi

    find=`grep "MX7D" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx7
    fi


    find=`grep "MX7ULP" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx79
    fi

    find=`grep "MX6Q" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx63
    fi

    find=`grep "MX6DL" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx61
    fi

    find=`grep "MX6SL" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx60
    fi

    find=`grep "MX6SX" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx62
    fi

    find=`grep "MX6UL" /sys/devices/soc0/soc_id |wc -l`
    if [ $find -eq 1 ]
    then
        vte=vte_mx64
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
    mount -t nfs -o nolock,vers=3 10.192.244.37:/rootfs/wb /mnt/nfs
fi

echo `pwd`

#cd /mnt/nfs/${vte}
cd /mnt/nfs/L5.10.35_2.0.0_Q2_RC2/${vte}
. ./manual_test

echo "COMMAND:$*"

bash -c "$*"
