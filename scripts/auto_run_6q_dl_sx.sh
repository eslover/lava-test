#/bin/bash

for i in "$@"
do
case $i in
    -b=*|--board=*)
    BOARD+="${i#*=}"
    shift # past argument=value
    ;;
    -s=*|--soc=*)
    SOC+="${i#*=}"
    shift # past argument=value
    ;;
    -u=*|--u-tee-file=*)
    U_TEE_FILE+="${i#*=}"
    shift # past argument=value
    ;;
    -n=*|--nfs=*)
    NFS+="${i#*=}"
    shift # past argument=value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument with no value
    ;;
    *)
          # unknown option
    ;;
esac
done

#IMPORTANT: board and soc should be paired, if add one board, please also specify the SOC
#SOC=(imx6sx imx6dl imx6q imx6q)
#BOARD=(sdb sabresd sabreauto sabresd)
#U_TEE_FILE=(uTee-6sxsdb uTee-6dlsdb uTee-6qauto uTee-6qsdb)

N_SOC=${#SOC[@]}
N_BOARD=${#BOARD[@]}
N_U_TEE_FILE=${#U_TEE_FILE[@]}

BUILD=(master release)
N_BUILD=${#BUILD[@]}

#IMPORTANT: main trunk build take first to simplified the script
YOCTO_BUILD_WEB_CHN=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Regression/latest/common_bsp/" 
		 "http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Full/latest/common_bsp/")

YOCTO_BUILD_WEB_ATX=("http://yb2.am.freescale.net/internal-only/Linux_IMX_Regression/latest/common_bsp/" 
		 "http://yb2.am.freescale.net/build-output/Linux_IMX_Full/latest/common_bsp/")

wd=/nfsroot

echo "working directory for the nfsroofs: ${wd} "

[[ -d ${wd} ]] || sudo mkdir ${wd} && sudo chmod -R 777 ${wd}

cd ${wd}

#fresh start
for (( i=0; i<${N_SOC}; i++ )); do
	for (( j=0; j<${N_BOARD}; j++ )); do
		rm -rf ${wd}/${SOC[$i]}${BOARD[$j]}*
	done
done

while [ 1 ]; do

	for (( i=0; i<${N_BOARD}; i++ )); do

		for (( j=0; j<${N_BUILD}; j++ )); do

			cd ${wd}

			if [ ! -d "${SOC[$i]}${BOARD[$i]}${BUILD[j]}" ];then
				mkdir -p ${SOC[$i]}${BOARD[$i]}${BUILD[j]}
			fi

			cd ${SOC[$i]}${BOARD[$i]}${BUILD[j]}

			#wget -q --backups=1 ${YOCTO_BUILD_WEB_CHN[$j]}zImage-${SOC[$i]}${BOARD[$i]}.bin
			wget -q --backups=1 ${YOCTO_BUILD_WEB_CHN[$j]}zImage-imx6qpdlsolox.bin

			if [ $? -eq 0 ]
			then
				#cmp zImage-${SOC[$i]}${BOARD[$i]}.bin zImage-${SOC[$i]}${BOARD[$i]}.bin.1
				cmp zImage-imx6qpdlsolox.bin zImage-imx6qpdlsolox.bin.1

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
						--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}
						sleep 60
					done

					while !( ls *.bin &> /dev/null );
					do
						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*imx6*.bin" \
						--no-directories \
							${YOCTO_BUILD_WEB_CHN[$j]}
						sleep 60
					done

					while !( ls *.tar.bz2 &> /dev/null );
					do
						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*imx6qpdlsolox*.tar.bz2" \
						--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-internal-xwayland/
						sleep 60
					done

					ln -sf *imx6qpdlsolox*.tar.bz2 ${SOC[$i]}${BOARD[$i]}.tar.bz2;

					#here is the trick: replace the u-boot
					#For the safty, fetch the imx-boot from Austin server
					sudo sed -i "/imx-uboot/c\    wget ${YOCTO_BUILD_WEB_ATX[$j]}imx-uboot/u-boot-${SOC[$i]}${BOARD[$i]}_sd-optee.imx -O uboot.imx" \
					"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

					sudo sed -i "/optee-os-imx/c\    wget ${YOCTO_BUILD_WEB_ATX[$j]}optee-os-imx/${U_TEE_FILE[$i]}" \
					"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

					#start the job, the next job sumbmision need wait previous job completion due to the SCUFW update
					#while we support more than one kind of test(release vs master) with one board in the farm
					if [ ${BUILD[j]} == "master" ]
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
