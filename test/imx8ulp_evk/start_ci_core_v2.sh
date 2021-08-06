#!/bin/bash

OUTPUT=`lavacli --uri http://admin:43p8nz0iwe0tb2scya3mrcls8kl0hxw9whf19bac0kdc40lxfu6rtikis00yrcy9teu35ky8kcnrxygcqrxs9m649x3u6dp9gwb36p845kd4ozpzbpq8ft7ufu0u1syz@10.192.242.47/RPC2/ jobs submit imx8ulp_evk_boot_update.yaml`

if [ $? -eq 0 ]
then
	JOB_ID=$(grep -Po -- '[[:digit:]]*' <<< "$OUTPUT")
	echo $JOB_ID

	while [ 1 ]; do

		OUTPUT=$(lavacli --uri http://admin:43p8nz0iwe0tb2scya3mrcls8kl0hxw9whf19bac0kdc40lxfu6rtikis00yrcy9teu35ky8kcnrxygcqrxs9m649x3u6dp9gwb36p845kd4ozpzbpq8ft7ufu0u1syz@10.192.242.47/RPC2/ jobs show $JOB_ID)

		echo $OUTPUT

		JOB_STATUS=$(grep -Po -- 'state       : \K\w*' <<< "$OUTPUT")

		if [ "$JOB_STATUS" = "Finished" ] || [ "$JOB_STATUS" = "Complete" ] || [ "$JOB_STATUS" = "Incomplete" ] || [ "$JOB_STATUS" = "Canceled" ]
		then
			echo "Job: $JOB_ID finished.....$JOB_STATUS, continue to do the next test"
			break
		else
			echo "job not finished: $JOB_STATUS ..."
			sleep 20
		fi
	done

else

	echo "job submit failed...."

fi

OUTPUT=`lavacli --uri http://admin:43p8nz0iwe0tb2scya3mrcls8kl0hxw9whf19bac0kdc40lxfu6rtikis00yrcy9teu35ky8kcnrxygcqrxs9m649x3u6dp9gwb36p845kd4ozpzbpq8ft7ufu0u1syz@10.192.242.47/RPC2/ jobs submit imx8ulp_evk_vte_core.yaml`

if [ $? -eq 0 ]
then
	JOB_ID=$(grep -Po -- '[[:digit:]]*' <<< "$OUTPUT")
	echo $JOB_ID

	while [ 1 ]; do

		OUTPUT=$(lavacli --uri http://admin:43p8nz0iwe0tb2scya3mrcls8kl0hxw9whf19bac0kdc40lxfu6rtikis00yrcy9teu35ky8kcnrxygcqrxs9m649x3u6dp9gwb36p845kd4ozpzbpq8ft7ufu0u1syz@10.192.242.47/RPC2/ jobs show $JOB_ID)

		echo $OUTPUT

		JOB_STATUS=$(grep -Po -- 'state       : \K\w*' <<< "$OUTPUT")

		if [ "$JOB_STATUS" = "Finished" ] || [ "$JOB_STATUS" = "Complete" ] || [ "$JOB_STATUS" = "Incomplete" ] || [ "$JOB_STATUS" = "Canceled" ]
		then
			echo "Job: $JOB_ID finished.....$JOB_STATUS, continue to do the next test"
			break
		else
			echo "job not finished: $JOB_STATUS ..."
			sleep 60
		fi
	done

else

	echo "job submit failed...."

fi
