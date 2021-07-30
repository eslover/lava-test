#!/bin/bash

OUTPUT=`lavacli --uri http://admin:1z70r3y3ohqusk8onxg6ep8b8us95rpyfh25jiytg9y68igwrkhnzolfcc1gqp0ls96ihsttqezxu6wi9w08gpid7xw2pj531lc0q97kdykhjzse0n3epks1w5u17yn6@10.192.242.47/RPC2/ jobs submit imx8mm_evk_boot_update.yaml`

if [ $? -eq 0 ]
then
	JOB_ID=$(grep -Po -- '[[:digit:]]*' <<< "$OUTPUT")
	echo $JOB_ID

	while [ 1 ]; do

		OUTPUT=$(lavacli --uri http://admin:1z70r3y3ohqusk8onxg6ep8b8us95rpyfh25jiytg9y68igwrkhnzolfcc1gqp0ls96ihsttqezxu6wi9w08gpid7xw2pj531lc0q97kdykhjzse0n3epks1w5u17yn6@10.192.242.47/RPC2/ jobs show $JOB_ID)

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

OUTPUT=`lavacli --uri http://admin:1z70r3y3ohqusk8onxg6ep8b8us95rpyfh25jiytg9y68igwrkhnzolfcc1gqp0ls96ihsttqezxu6wi9w08gpid7xw2pj531lc0q97kdykhjzse0n3epks1w5u17yn6@10.192.242.47/RPC2/ jobs submit imx8mm_evk_vte_core.yaml`

if [ $? -eq 0 ]
then
	JOB_ID=$(grep -Po -- '[[:digit:]]*' <<< "$OUTPUT")
	echo $JOB_ID

	while [ 1 ]; do

		OUTPUT=$(lavacli --uri http://admin:1z70r3y3ohqusk8onxg6ep8b8us95rpyfh25jiytg9y68igwrkhnzolfcc1gqp0ls96ihsttqezxu6wi9w08gpid7xw2pj531lc0q97kdykhjzse0n3epks1w5u17yn6@10.192.242.47/RPC2/ jobs show $JOB_ID)

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
