#/bin/bash

wd=/nfsroot

echo "working directory for the nfsroofs: ${wd} "

[[ -d ${wd} ]] || sudo mkdir ${wd} && sudo chmod -R 777 ${wd}

cd ${wd}

#IMPORTANT: board and soc should be paired, if add one board, please also specify the SOC
SOC=(imx6sl)
N_SOC=${#SOC[@]}

BOARD=(evk)
N_BOARD=${#BOARD[@]}

#IMPORTANT: main trunk build take first to simplified the script
YOCTO_BUILD_WEB=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Regression/latest/common_bsp/")

BUILD=(master)
N_BUILD=${#BUILD[@]}

#fresh start
rm -rf ${wd}/${SOC[0]}*

while [ 1 ]; do

	for (( i=0; i<${N_BOARD}; i++ )); do

		for (( j=0; j<${N_BUILD}; j++ )); do

			cd ${wd}

			if [ ! -d "${SOC[$i]}${BOARD[$i]}${BUILD[j]}" ];then
				mkdir -p ${SOC[$i]}${BOARD[$i]}${BUILD[j]}
			fi

			cd ${SOC[$i]}${BOARD[$i]}${BUILD[j]}

			wget -q --backups=1 ${YOCTO_BUILD_WEB[$j]}zImage-${SOC[$i]}${BOARD[$i]}.bin

			if [ $? -eq 0 ]
			then
				cmp zImage-${SOC[$i]}${BOARD[$i]}.bin zImage-${SOC[$i]}${BOARD[$i]}.bin.1

				if [ $? -eq 0 ]
				then
					sleep 60
				else
					if [ ! -d "image" ];then
						mkdir -p image
					fi

					cd image

					echo "going to delopy platform build image: ${SOC[$i]}${BOARD[$i]}${BUILD[j]}"
					rm -rf *.tar.bz2 *.dtb *.bin

					while !( ls *.dtb &> /dev/null );
					do

						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${SOC[$i]}*.dtb" \
						--no-directories ${YOCTO_BUILD_WEB[$j]}
						sleep 60
					done

					while !( ls *.bin &> /dev/null );
					do
						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${SOC[$i]}*.bin" \
						--no-directories \
							${YOCTO_BUILD_WEB[$j]}
						sleep 60
					done

					while !( ls *.tar.bz2 &> /dev/null );
					do
						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${SOC[$i]}${BOARD[$i]}*.tar.bz2" \
						--no-directories ${YOCTO_BUILD_WEB[$j]}../fsl-imx-internal-xwayland/
						sleep 60
					done

					ln -sf *${SOC[$i]}${BOARD[$i]}*.tar.bz2 ${SOC[$i]}${BOARD[$i]}.tar.bz2;

					if (( $j == 0 ))
					then
						/home/r64343/workspace/lava-test/test/${SOC[$i]}_${BOARD[$i]}/start_ci_master.sh
					else
						/home/r64343/workspace/lava-test/test/${SOC[$i]}_${BOARD[$i]}/start_ci_release.sh
					fi
				fi
			else
				sleep 60

			fi
		done
	done

done
