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

YOCTO_BUILD_WEB_CHN=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Regression_Next_Kernel/latest/common_bsp/" 
		     "http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Full/latest/common_bsp/" 
		     "http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Core/latest/common_bsp/" 
		     "http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_5.4.24-2.1.0/latest/common_bsp/")

YOCTO_BUILD_WEB_ATX=("http://yb2.am.freescale.net/internal-only/Linux_IMX_Regression_Next_Kernel/latest/common_bsp/" 
		     "http://yb2.am.freescale.net/internal-only/Linux_IMX_Full/latest/common_bsp/" 
		     "http://yb2.am.freescale.net/internal-only/Linux_IMX_Core/latest/common_bsp/" 
		     "http://yb2.am.freescale.net/internal-only/Linux_IMX_5.4.24-2.1.0/latest/common_bsp/")

#only for release quick test
#BUILD=(release)
#YOCTO_BUILD_WEB_CHN=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_5.4.24-2.1.0/latest/common_bsp/")
#YOCTO_BUILD_WEB_ATX=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_5.4.24-2.1.0/latest/common_bsp/")

#only for LF quick test
BUILD=(release)
YOCTO_BUILD_WEB_CHN=("http://neptune.ap.freescale.net/Linux_Factory/latest/common_bsp/")
YOCTO_BUILD_WEB_ATX=("http://neptune.ap.freescale.net/Linux_Factory/latest/common_bsp/")

#only for Full quick test
BUILD=(release)
YOCTO_BUILD_WEB_CHN=("http://neptune.ap.freescale.net/Linux_Factory/201/common_bsp/")
YOCTO_BUILD_WEB_ATX=("http://neptune.ap.freescale.net/Linux_Factory/201/common_bsp/")

#only for Core quick test
BUILD=(core)
YOCTO_BUILD_WEB_CHN=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Core/latest/common_bsp/")
YOCTO_BUILD_WEB_ATX=("http://shlinux22.ap.freescale.net/internal-only/Linux_IMX_Core/latest/common_bsp/")

N_BUILD=${#BUILD[@]}

wd=/nfsroot

echo "working directory for the nfsroofs: ${wd} "

[[ -d ${wd} ]] || sudo mkdir ${wd} && sudo chmod -R 777 ${wd}

cd ${wd}

#fresh start
#for (( i=0; i<${N_SOC}; i++ )); do
#	for (( j=0; j<${N_BOARD}; j++ )); do
#		rm -rf ${wd}/${SOC[$i]}${BOARD[$j]}*
#	done
#done

while [ 1 ]; do

	for (( i=0; i<${N_BOARD}; i++ )); do

		for (( j=0; j<${N_BUILD}; j++ )); do

			cd ${wd}

			if [ ! -d "${SOC[$i]}${BOARD[$i]}${BUILD[j]}" ];then
				mkdir -p ${SOC[$i]}${BOARD[$i]}${BUILD[j]}
			fi

			cd ${SOC[$i]}${BOARD[$i]}${BUILD[j]}

			if [ $? -eq 0 ]
			then
				cmp ./Image /nfsroot/ondemand/Image

				if [ $? -eq 0 ]
				then
					sleep 60
				else
					cp -f /nfsroot/ondemand/Image .
					if [ ! -d "image" ];then
						mkdir -p image
					fi

					cd image

					echo "going to delopy platform build image..."
					rm -rf *.tar.bz2 *.dtb *.bin *.tar

					# dtbs
					cp -f /nfsroot/ondemand/${SOC[$i]}*.dtb .

					# kernel
					case ${SOC[i]} in

					imx[6-7]*)
						cp -f /nfsroot/ondemand/zImage ./${IMG[$i]}
						;;
					imx8*)
						cp -f /nfsroot/ondemand/Image ./${IMG[$i]}
						;;
					*)
						echo "Unknown SOC type"
						;;
					esac

					case ${BUILD[j]}  in

					full | regression | release)
						while !( ls *.tar.bz2 &> /dev/null );
						do
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-internal-xwayland/
							if [ $? -eq 0 ]
							then
								break;
							fi

							#new yacto build
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-xwayland/
							if [ $? -eq 0 ]
							then
								break;
							fi

							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${SOC[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-internal-xwayland/
							if [ $? -eq 0 ]
							then
								break;
							fi

							sleep 60
						done
						;;

					core)
						while !( ls *.tar.bz2 &> /dev/null );
						do
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-internal-wayland/
							if [ $? -eq 0 ]
							then
								break;
							fi

							#new yacto build
							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${NFS[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-wayland/
							if [ $? -eq 0 ]
							then
								break;
							fi

							wget -N -q --backups=1 -r -l1 -nH --cut-dirs=2 --no-parent -A "*${SOC[$i]}*.tar.bz2" \
							--no-directories ${YOCTO_BUILD_WEB_CHN[$j]}../fsl-imx-internal-wayland/
							if [ $? -eq 0 ]
							then
								break;
							fi

							sleep 60
						done
						;;
					*)
						echo "Unknown build type"
						;;
					esac

					#create symbol link, try to find one if mulptile
					ln -sf `ls -S *${NFS[$i]}*.tar.bz2 | head -1` ${SOC[$i]}${BOARD[$i]}.tar.bz2;
					if [ $? -ne 0 ]
					then
						ln -sf `ls -S *${SOC[$i]}*.tar.bz2 | head -1` ${SOC[$i]}${BOARD[$i]}.tar.bz2;
					fi

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

							#sudo sed -i --follow-symlinks "/uTee-/c\ wget ${YOCTO_BUILD_WEB_ATX[$j]}optee-os-imx/${U_TEE_FILE[$i]} -O ${U_TEE_FILE[$i],,}" \
							#"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

							#sudo wget -q ${YOCTO_BUILD_WEB_ATX[$j]}optee-os-imx/${U_TEE_FILE[$i]} -O ${FTP_DIR}/${U_TEE_FILE[$i]}


							sudo sed -i --follow-symlinks "/uTee-/c\ wget ${YOCTO_BUILD_WEB_ATX[$j]}imx_uboot/${U_TEE_FILE[$i]} -O ${U_TEE_FILE[$i],,}" \
							"/etc/lava-dispatcher/devices/${SOC[$i]}-${BOARD[$i]}.conf"

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
