#/bin/bash

cd /nfsroot

rm -rf test-internal-qt5-imx8qxpmek-license.manifest*
touch test-internal-qt5-imx8qxpmek-license.manifest

while [ 1 ]; do

wget -q --backups=1 http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_4.9_morty_trunk_next/latest/fsl-imx-internal-xwayland/test-internal-qt5-imx8qxpmek-license.manifest

cmp test-internal-qt5-imx8qxpmek-license.manifest test-internal-qt5-imx8qxpmek-license.manifest.1

if [ $? -eq 0 ]
then
	sleep 10
else
	/home/r64343/workspace/sandbox-test/test/imx8qm_arm2/start_ci.sh
fi

done
