#!/bin/bash

mkdir /mnt/auto_test
mount -o nolock,tcp -t nfs 10.192.224.45:/streams/ttVector/SHAVectors /mnt/auto_test

cd scripts/mm_auto

echo `pwd`

./auto_test.sh -d /mnt/auto_test -AV -e gst1.0_not_support.txt < CMD
