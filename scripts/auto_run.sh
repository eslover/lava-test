#!/bin/bash

#SOC=(imx6sx imx6q imx6q imx6dl)
#BOARD=(sabresd sabresd sabreauto sabresd)
#U_TEE_FILE=(uTee-6sxsdb uTee-6qsdb uTee-6qauto uTee-6dlsd)

#SOC=(imx6ul imx6sl imx7d)
#BOARD=(14x14-evk evk sabresd)
#NFS=(imx6ul7d imx6slevk imx7dsabresd)
#U_TEE_FILE=(uTee-6ulevk uTee-6slevk uTee-7dsdb)

#-s: SOC;-b: BOARD;-u: U_TEE_FILE;-n: NFS

nohup bash -x ./auto_run_base.sh -s=imx6sx -b=sabresd -u=uTee-6sxsdb -i=zImage-imx6qpdlsolox.bin -n=imx6qpdlsolox > ~/imx6sxsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx6q -b=sabresd -u=uTee-6qsdb -i=zImage-imx6qpdlsolox.bin -n=imx6qpdlsolox > ~/imx6qsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx6q -b=sabreauto -u=uTee-6qauto -i=zImage-imx6qpdlsolox.bin -n=imx6qpdlsolox > ~/imx6qard_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx6dl -b=sabresd -u=uTee-6dlsdb -i=zImage-imx6qpdlsolox.bin -n=imx6qpdlsolox > ~/imx6dlsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx6ul -b=14x14-evk -u=uTee-6ulevk -i=zImage-imx6ul7d.bin -n=imx6ul7d > ~/imx6ulevk_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx6sl -b=evk -u=uTee-6slevk -i=zImage-imx6slevk.bin -n=imx6slevk > ~/imx6slevk_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx7d -b=sabresd -u=uTee-7dsdb -i=zImage-imx6ul7d.bin -n=imx6ul7d > ~/imx7dsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx7ulp -b=evk -u=uTee-7ulp -i=zImage-imx7ulpevk.bin -n=imx7ulpevk > ~/imx7ulpevk_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx8mm -b=evk -i=Image-imx8mmevk.bin -n=imx8mmevk > ~/imx8mmevk_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx8qxp -b=mek -i=Image-imx8qxpmek.bin -n=imx8qxpmek > ~/imx8qxpmek_nohup.out 2>&1 &

nohup bash -x ./auto_run_base.sh -s=imx8mq -b=evk -i=Image-imx8mqevk.bin -n=imx8mqevk > ~/imx8mqevk_nohup.out 2>&1 &

#nohup bash -x ./auto_run_base.sh -s=imx8qm -b=mek -i=Image-imx8qmmek.bin -n=imx8qmmek > ~/imx8qmmek_nohup.out 2>&1 &
