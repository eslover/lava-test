#/bin/bash

OUTPUT=`lava-tool submit-job http://admin:bfy050frm8st8kubid700at6omb78jmpnr60sow830nyce07r97g8e74rylai1y1e5o7nbiynhux5g107xkobzou74thuaa8njgi20kg83jazhj1oc39wt1o9ww5juwy@10.192.242.34/RPC2 \
/home/r64343/workspace/lava-test/test/imx8qm_mek/imx8qm_mek_vte_release.json`

if [ $? -eq 0 ]
then
	JOB_ID=$(grep -Po -- 'id: \K\w*' <<< "$OUTPUT")
	echo $JOB_ID

	while [ 1 ]; do

		OUTPUT=$(lava-tool job-status http://admin:bfy050frm8st8kubid700at6omb78jmpnr60sow830nyce07r97g8e74rylai1y1e5o7nbiynhux5g107xkobzou74thuaa8njgi20kg83jazhj1oc39wt1o9ww5juwy@10.192.242.34/RPC2 $JOB_ID)

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
