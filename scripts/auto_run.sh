#/bin/bash

wd=/nfsroot

echo "working directory for the nfsroofs: ${wd} "

[[ -d ${wd} ]] || sudo mkdir ${wd} && sudo chmod -R 777 ${wd}

cd ${wd}

rm -rf test-internal-qt5-imx8qxpmek-license.manifest*
touch test-internal-qt5-imx8qxpmek-license.manifest

#nfs=(imx8qxpmek imx8qmlpddr4arm2)
#plt=(imx8qxp_mek imx8qm_arm2)

nfs=(imx8qxpmek)
plt=(imx8qxp_mek)

N_nfs=${#nfs[@]}
N_plt=${#plt[@]}

while [ 1 ]; do

cd ${wd}

wget -q --backups=1 http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_4.9_morty_trunk_next/latest/fsl-imx-internal-xwayland/test-internal-qt5-imx8qxpmek-license.manifest

cmp test-internal-qt5-imx8qxpmek-license.manifest test-internal-qt5-imx8qxpmek-license.manifest.1

if [ $? -eq 0 ]
then
	sleep 10
else
	for (( i=1; i<${N_plt}+1; i++ )); do
		cd ${wd}
		echo "going to delopy platform: ${plt[$i-1]}"
		mkdir -p ${plt[$i-1]}
		cd ${plt[$i-1]}
		rm -rf *.tar.bz2

		wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${nfs[$i-1]}*.tar.bz2" --no-directories \
			 http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_4.9_morty_trunk_next/latest/fsl-imx-internal-xwayland/

		ln -sf *${nfs[$i-1]}*.tar.bz2 ${nfs[$i-1]}.tar.bz2;

		#start the job
		/home/r64343/workspace/lava-test/test/${plt[$i-1]}/start_ci.sh
	done

fi

done
