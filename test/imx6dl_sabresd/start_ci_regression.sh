#/bin/bash

OUTPUT=`lava-tool submit-job http://admin:l7y5cz0ttbzedtg7ai1okum11eic3n49igs4t6uiraou0amk3bbs2uqh0impai0y7u9a6mue0ep3m081qjwnw0xtoskocz2xnyina3edkkdjooblh94110e41fl66uq1@10.192.242.176/RPC2 \
/home/r64343/workspace/lava-test/test/imx6dl_sabresd/imx6dl_sabresd_vte_regression.json`

if [ $? -eq 0 ]
then
	JOB_ID=$(grep -Po -- 'id: \K\w*' <<< "$OUTPUT")
	echo $JOB_ID

	while [ 1 ]; do

		OUTPUT=$(lava-tool job-status http://admin:l7y5cz0ttbzedtg7ai1okum11eic3n49igs4t6uiraou0amk3bbs2uqh0impai0y7u9a6mue0ep3m081qjwnw0xtoskocz2xnyina3edkkdjooblh94110e41fl66uq1@10.192.242.176/RPC2 $JOB_ID)

		echo $OUTPUT

		JOB_STATUS=$(grep -Po -- 'Status: \K\w*' <<< "$OUTPUT")

		if [ "$JOB_STATUS" = "Complete" ] || [ "$JOB_STATUS" = "Incomplete" ] || [ "$JOB_STATUS" = "Canceled" ]
		then
			echo "Job: $JOB_ID finished....., continue to do the next test"
			break
		else
			echo "job not finished: $JOB_STATUS ..."
			sleep 60
		fi
	done

else

	echo "job submit failed...."

fi
