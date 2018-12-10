#!/bin/bash

nohup bash -x /home/r64343/workspace/lava-test/scripts/lava-clean-disk.sh > ~/lava-clean-disk.out 2>&1 &
sudo service tftpd-hpa restart
sudo mount /dev/sdb1 /nfsroot
