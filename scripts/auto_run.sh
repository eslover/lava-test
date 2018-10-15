#!/bin/bash

#SOC=(imx6sx imx6q imx6q imx6dl)
#BOARD=(sabresd sabresd sabreauto sabresd)
#U_TEE_FILE=(uTee-6sxsdb uTee-6qsdb uTee-6qauto uTee-6dlsd)

#SOC=(imx6ul imx6sl imx7d)
#BOARD=(14x14-evk evk sabresd)
#NFS=(imx6ul7d imx6slevk imx7dsabresd)
#U_TEE_FILE=(uTee-6ulevk uTee-6slevk uTee-7dsdb)

#-s: SOC;-b: BOARD;-u: U_TEE_FILE;-n: NFS

nohup bash -x ./auto_run_6q_dl_sx.sh -s=imx6sx -b=sabresd -u=uTee-6sxsdb > imx6sxsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_6q_dl_sx.sh -s=imx6q -b=sabresd -u=uTee-6qsdb > imx6qsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_6q_dl_sx.sh -s=imx6q -b=sabreauto -u=uTee-6qauto > imx6qard_nohup.out 2>&1 &

nohup bash -x ./auto_run_6q_dl_sx.sh -s=imx6dl -b=sabresd -u=uTee-6dlsdb > imx6dlsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_6sl_6ul_7d.sh -s=imx6ul -b=14x14-evk -u=uTee-6ulevk -n=imx6ul7d  > imx6ulevk_nohup.out 2>&1 &

nohup bash -x ./auto_run_6sl_6ul_7d.sh -s=imx6sl -b=evk -u=uTee-6slevk -n=imx6slevk > imx6slevk_nohup.out 2>&1 &

nohup bash -x ./auto_run_6sl_6ul_7d.sh -s=imx7d -b=sabresd -u=uTee-7dsdb -n=imx7dsabresd > imx7dsdb_nohup.out 2>&1 &

nohup bash -x ./auto_run_8qxp.sh > imx8qxpmek_nohup.out 2>&1 &
