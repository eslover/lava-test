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
    -i=*|--image=*)
    IMG+="${i#*=}"
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

FTP_DIR=/var/lib/lava/dispatcher/tmp
N_SOC=${#SOC[@]}
N_BOARD=${#BOARD[@]}
N_U_TEE_FILE=${#U_TEE_FILE[@]}

BUILD=(regression full core release)

N_BUILD=${#BUILD[@]}

YOCTO_BUILD_WEB_CHN=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Regression_Next_Kernel/latest/common_bsp/" 
		     "http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Full/latest/common_bsp/" 
		     "http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Core/latest/common_bsp/" 
		     "http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_4.19.35-1.1.0_GA/latest/common_bsp/")

YOCTO_BUILD_WEB_ATX=("http://yb2.am.freescale.net/internal-only/Linux_IMX_Regression_Next_Kernel/latest/common_bsp/" 
		     "http://yb2.am.freescale.net/build-output/Linux_IMX_Full/latest/common_bsp/" 
		     "http://yb2.am.freescale.net/internal-only/Linux_IMX_Core/latest/common_bsp/" 
		     "http://yb2.am.freescale.net/build-output/Linux_IMX_4.19.35-1.1.0_GA/latest/common_bsp/")

#only for release quick test
#BUILD=(release)
#YOCTO_BUILD_WEB_CHN=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_4.19.35-1.1.0_GA/latest/common_bsp/")
#YOCTO_BUILD_WEB_ATX=("http://yb2.am.freescale.net/build-output/Linux_IMX_4.19.35-1.1.0_GA/latest/common_bsp/")

#only for quick test
BUILD=(release)
YOCTO_BUILD_WEB_CHN=("http://neptune.ap.freescale.net/Linux_Factory/latest/common_bsp/")
YOCTO_BUILD_WEB_ATX=("http://neptune.ap.freescale.net/Linux_Factory/latest/common_bsp/")
wd=/nfsroot

echo "working directory for the nfsroofs: ${wd} "

[[ -d ${wd} ]] || sudo mkdir ${wd} && sudo chmod -R 777 ${wd}

cd ${wd}

#fresh start
#for (( i=0; i<${N_SOC}; i++ )); do
	#for (( j=0; j<${N_BOARD}; j++ )); do
		#rm -rf ${wd}/${SOC[$i]}${BOARD[$j]}*
	#done
#done

while [ 1 ]; do

	for (( i=0; i<${N_BOARD}; i++ )); do

		for (( j=0; j<${N_BUILD}; j++ )); do

			cd ${wd}

			if [ ! -d "${SOC[$i]}${BOARD[$i]}${BUILD[j]}" ];then
				mkdir -p ${SOC[$i]}${BOARD[$i]}${BUILD[j]}
			fi

			cd ${SOC[$i]}${BOARD[$i]}${BUILD[j]}

			wget -q --backups=1 ${YOCTO_BUILD_WEB_CHN[$j]}${IMG[$i]}

			if [ $? -eq 0 ]
			then
				cmp ${IMG[$i]} ${IMG[$i]}.1

				if [ $? -eq 0 ]
				then
					sleep 60
				else
					if [ ! -d "image" ];then
						mkdir -p image
					fi

					cd image

					echo "going to delopy platform build image..."
					rm -rf *.tar.bz2 *.dtb *.bin *.tar

					while !( ls *.dtb &> /dev/null );
					do

						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${SOC[$i]}*.dtb" \
						--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}

						# new Yocto build folder
						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${SOC[$i]}*.dtb" \
						--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}imx_dtbs/
						sleep 60
					done

					while !( ls *.bin &> /dev/null );
					do
						wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${IMG[$i]}*" \
						--no-directories \
							${YOCTO_BUILD_WEB_CHN[$j]}
						sleep 60
					done

					case ${BUILD[j]}  in

					full | regression | release)
						while !( ls *.tar.bz2 &> /dev/null );
						do
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-internal-xwayland/

							#new yacto build
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-xwayland/

							sleep 60
						done
						;;

					core)
						while !( ls *.tar.bz2 &> /dev/null );
						do
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-internal-wayland/

							#new yacto build
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-wayland/

							sleep 60
						done
						;;
					*)
						echo "Unknown build type"
						;;
					esac

					#create symbol link, try to find one if mulptile
					ln -sf `find *${NFS[$i]}*.tar.bz2 | head -1` ${SOC[$i]}${BOARD[$i]}.tar.bz2;

					#bunzip it firstly for the sake of the CPU high loading when mulitple board bootup
					cat ${SOC[$i]}${BOARD[$i]}.tar.bz2 |  bunzip2 > ${SOC[$i]}${BOARD[$i]}.tar
					rm -rf *.bz2

					#trick: on-the-fly to replace the u-boot/op-tee on imx6/7 or flash.bin on imx8
					#serialization: for differnt build-type test,to use one board to test different

					case ${SOC[i]} in

					imx[6-7]*)
						case ${BUILD[j]}  in

						full | regression | release)
							#For the safty, fetch the imx-boot from Austin server
							sudo sed -i --follow-symlinks \
							"/optee.imx/c\ wget ${YOCTO_BUILD_WEB_ATX[$j]}imx_uboot/u-boot-${SOC[$i]}${BOARD[$i]}_sd-optee.imx -O uboot.imx" \
							"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

							sudo sed -i --follow-symlinks "/uTee-/c\ wget ${YOCTO_BUILD_WEB_ATX[$j]}optee-os-imx/${U_TEE_FILE[$i]} -O ${U_TEE_FILE[$i],,}" \
							"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

							sudo wget -q ${YOCTO_BUILD_WEB_ATX[$j]}optee-os-imx/${U_TEE_FILE[$i]} -O ${FTP_DIR}/${U_TEE_FILE[$i]}


							#sudo sed -i --follow-symlinks "/uTee-/c\ wget ${YOCTO_BUILD_WEB_ATX[$j]}imx_uboot/${U_TEE_FILE[$i]} -O ${U_TEE_FILE[$i],,}" \
							#"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

							sudo wget -q ${YOCTO_BUILD_WEB_ATX[$j]}imx_uboot/${U_TEE_FILE[$i]} -O ${FTP_DIR}/${U_TEE_FILE[$i]}
							;;

						core)
							#For the safty, fetch the imx-boot from Austin server
							sudo sed -i --follow-symlinks \
							"/optee.imx/c\ wget ${YOCTO_BUILD_WEB_ATX[$j]}imx_uboot/u-boot-${SOC[$i]}${BOARD[$i]}_sd-optee.imx -O uboot.imx" \
							"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

							sudo sed -i --follow-symlinks "/uTee-/c\ wget ${YOCTO_BUILD_WEB_ATX[$j]}imx_uboot/${U_TEE_FILE[$i]} -O ${U_TEE_FILE[$i],,}" \
							"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

							sudo wget -q ${YOCTO_BUILD_WEB_ATX[$j]}imx_uboot/${U_TEE_FILE[$i]} -O ${FTP_DIR}/${U_TEE_FILE[$i]}
							;;
						*)
							echo "Unknown build type"
							;;
						esac
						;;
					imx8qxp)
						sudo sed -i "/wget/c\    wget ${YOCTO_BUILD_WEB_ATX[$j]}imx-boot/imx-boot-${SOC[$i]}${BOARD[$i]}-sd.bin-flash_linux_m4 -O flash.bin" \
						"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"
						;;
					imx8qm)
						sudo sed -i "/wget/c\    wget ${YOCTO_BUILD_WEB_ATX[$j]}imx-boot/imx-boot-${SOC[$i]}${BOARD[$i]}-sd.bin-flash_linux_m4  -O flash.bin" \
						"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"
						;;
					imx8mm)
						sudo sed -i "/wget/c\    wget ${YOCTO_BUILD_WEB_ATX[$j]}imx-boot/imx-boot-${SOC[$i]}${BOARD[$i]}-sd.bin-flash_evk -O flash.bin" \
						"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"
						;;
					imx8mq)
						sudo sed -i "/wget/c\    wget ${YOCTO_BUILD_WEB_ATX[$j]}imx-boot/imx-boot-${SOC[$i]}${BOARD[$i]}-sd.bin-flash_evk -O flash.bin" \
						"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"
						;;
					*)
						echo "Unknown SOC type"
						;;
					esac

					#submit the lava job and wait for completion
					/home/r64343/workspace/lava-test/test/${SOC[$i]}_${BOARD[$i]}/start_ci_${BUILD[j]}.sh

					#clean up the disk to avoid disk-full
					sudo rm -rf *
				fi
			else
				sleep 60

			fi
		done
	done

done
