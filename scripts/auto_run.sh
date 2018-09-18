#!/bin/bash

#SOC=(imx6sx imx6q imx6q imx6dl)
#BOARD=(sabresd sabresd sabreauto sabresd)
#U_TEE_FILE=(uTee-6sxsdb uTee-6qsdb uTee-6qauto uTee-6dlsd)

#SOC=(imx6ul imx6sl imx7d)
#BOARD=(14x14-evk evk sabresd)
#NFS=(imx6ul7d imx6slevk imx7dsabresd)
#U_TEE_FILE=(uTee-6ulevk uTee-6slevk uTee-7dsdb)

SOC=(imx6sx)
BOARD=(sabresd)
U_TEE_FILE=(uTee-6sxsdb)
. ./auto_run_6q_dl_sx.sh &

SOC=(imx6q)
BOARD=(sabresd)
U_TEE_FILE=(uTee-6qsdb)
. ./auto_run_6q_dl_sx.sh &

SOC=(imx6q)
BOARD=(sabreauto)
U_TEE_FILE=(uTee-6qauto)
. ./auto_run_6q_dl_sx.sh &

SOC=(imx6dl)
BOARD=(sabresd)
U_TEE_FILE=(uTee-6dlsdb)
. ./auto_run_6q_dl_sx.sh &

SOC=(imx6ul)
BOARD=(14x14-evk)
NFS=(imx6ul7d)
U_TEE_FILE=(uTee-6ulevk)
. ./auto_run_6sl_6ul_7d.sh &

SOC=(imx6sl)
BOARD=(evk)
NFS=(imx6slevk )
U_TEE_FILE=(uTee-6slevk)
. ./auto_run_6sl_6ul_7d.sh &

SOC=(imx7d)
BOARD=(sabresd)
NFS=(imx7dsabresd)
U_TEE_FILE=(uTee-7dsdb)
. ./auto_run_6sl_6ul_7d.sh &

