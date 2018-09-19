#!/bin/bash

#SOC=(imx6sx imx6q imx6q imx6dl)
#BOARD=(sabresd sabresd sabreauto sabresd)
#U_TEE_FILE=(uTee-6sxsdb uTee-6qsdb uTee-6qauto uTee-6dlsd)

#SOC=(imx6ul imx6sl imx7d)
#BOARD=(14x14-evk evk sabresd)
#NFS=(imx6ul7d imx6slevk imx7dsabresd)
#U_TEE_FILE=(uTee-6ulevk uTee-6slevk uTee-7dsdb)

#-s: SOC;-b: BOARD;-u: U_TEE_FILE;-n: NFS

./auto_run_6q_dl_sx.sh -s=imx6sx -b=sabresd -u=uTee-6sxsdb

./auto_run_6q_dl_sx.sh -s=imx6q -b=sabresd -u=uTee-6qsdb

./auto_run_6q_dl_sx.sh -s=imx6q -b=sabreauto -u=uTee-6qauto

./auto_run_6q_dl_sx.sh -s=imx6dl -b=sabresd -u=uTee-6dlsdb

./auto_run_6sl_6ul_7d.sh -s=imx6ul -b=14x14-evk -u=uTee-6ulevk -n=uTee-6ulevk

./auto_run_6sl_6ul_7d.sh -s=imx6sl -b=evk -u=uTee-6slevk -n=imx6slevk

./auto_run_6sl_6ul_7d.sh -s=imx7d -b=sabresd -u=uTee-7dsdb -n=imx7dsabresd

