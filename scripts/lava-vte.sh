#!/bin/bash

mount -t nfs -o nolock 10.192.244.6:/rootfs/wb /mnt
cd /mnt/vte_mx63_d
. ./manual_test
./mytest lava-imx6dl-sabresd-auto

