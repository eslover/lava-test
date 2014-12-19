#!/bin/sh

ADDOPT=

if [ $# -eq 0 ]
then
CMDFILE=exec_table_rdp
#CMDFILE=re-test
elif [ $1 == "one" ]
then
CMDFILE=ONSHOT
else
CMDFILE=$1
if [ "$2" = "CPU" ]; then
 cpus=$(cat /proc/cpuinfo  | grep processor | wc -l)
 ADDOPT="-c $cpus"
elif [ "$2" = "IO" ]; then
 cpus=$(cat /proc/cpuinfo  | grep processor | wc -l)
 ADDOPT="-i $cpus"
elif [ "$2" = "MEM"  ]; then
 cpus=$(cat /proc/cpuinfo  | grep processor | wc -l)
 ADDOPT="-m $cpus"
fi
fi

TEST_TYPE=AUTO

#CONTINUE=y

tday=$(date +%Y%m%d%H%M%S)

export STREAM_PATH=/mnt/nfs/test_stream
#mount /dev/mmcblk0p1 /tmp
export TMPDIR=/tmp
export LTPROOT=$(dirname $0)
TEST_PATH=$(dirname $0)
export PATH=$PATH:${TEST_PATH}/testcases/bin

dos2unix ${TEST_PATH}/runtest/$CMDFILE
mount -t tmpfs tmpfs /tmp
#dmesg -c
#enalbe dvfs
#dvfs_ctl=$(find /sys/devices -name *dvfscore*)
#echo 1 > ${dvfs_ctl}/enable

platfm=$(platfm.sh)
ARCH_PLATFORM=${platfm}


if [ "$CONTINUE" = 'y' ];then
#tday=$(date +%m%d%Y)
mac=$(cat /sys/class/net/eth0/address | sed 's/:/_/g')
tday=${mac}
#################partial2auto begin, if not define 'table_file' use origin version############
table_file=$(cat /proc/cmdline | grep "table_file=" | sed 's/table_file=/^/'| cut -d '^' -f 2 | cut -d " " -f 1)
if [  -n "${table_file}" ]; then
        GET_CONFIG=set_case_information.sh
    if [ ! -e ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday ]; then
        NET_ARGS=`/mnt/nfs/tools/printenv netargs`
        MORE_ARGS=`echo "$NET_ARGS" | grep "more_args" | wc -l`
        if [ ${MORE_ARGS} -eq 0 ];then
            NEW_ARGS=`echo "$NET_ARGS" | sed 's/root=/\${more_args} root=/'`
           /mnt/nfs/tools/setenv netargs "${NEW_ARGS}"
        fi
        FIRST_CASE_ID=`cat ${TEST_PATH}/runtest/${CMDFILE} | grep "T..-" | head -n 1 | awk '{print $1}'`
#        ${TEST_PATH}/testcases/bin/${GET_CONFIG} $FIRST_CASE_ID ${table_file}
        /mnt/nfs/tools/partial2auto/${GET_CONFIG} $FIRST_CASE_ID ${table_file}
#        ${TEST_PATH}/testcases/bin/gen_new_cmdfile.sh ${CMDFILE} ${table_file}
        /mnt/nfs/tools/partial2auto/gen_new_cmdfile.sh ${CMDFILE} ${table_file}
    fi
    if [  -e ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday ]; then
         LTC=`cat ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt | grep "T..-" |tail -n 1 | grep "TIMEOUT" | awk '{print $1}'`
         if [ ! -n "$LTC" ]; then
             echo "last case is not timeout case" > /dev/null
            ###################################delete and repalce#############
            BAD_CASE_ID=`cat ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt | grep "T..-" | tail -n 1 | awk '{print $1}'`
            if [ ! $BAD_CASE_ID ]; then
                echo 'NULL'
            else
                echo 'NULL'
                sed '/'"$BAD_CASE_ID"'/d' ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt | tee ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt
                temp_num=`cat ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday`
                temp_num=$(expr ${temp_num} - 1)
            fi
            ###################################delete and repalce############
        else
             echo "last case is timeout case" > /dev/null
             last_timeoutcase_line=`cat ${TEST_PATH}/runtest/${CMDFILE} |grep "T..-LV" | grep -n "${LTC}" | awk '{print $1}' | cut -d ":" -f 1`
             after_timecase_line=$(expr $last_timeoutcase_line + 1)     ##should care a bug ,if has same case ID##
             CASE_AFTER_LTC=`cat ${TEST_PATH}/runtest/${CMDFILE} | grep "T..-LV" | head -n $after_timecase_line | tail -n 1 | awk '{print $1}'`
#            ${TEST_PATH}/testcases/bin/${GET_CONFIG} $CASE_AFTER_LTC ${table_file}
             /mnt/nfs/tools/partial2auto/${GET_CONFIG} $CASE_AFTER_LTC ${table_file}
         fi
    fi
fi
#################partial2auto begin, if not define 'table_file' use origin version############
cat ${TEST_PATH}/runtest/$CMDFILE | sed 's/^#//g' > ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday
if [ -e ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday ]; then
#1 not first run, need change the command file skip the last one
#find the last execute one 
	search=1
	cnt=1
	ll=0
	step=1
    rep=$(cat /proc/cmdline| grep "rep=" | sed 's/rep=/^/'| cut -d '^' -f 2 | cut -d " " -f 1)
	total_tc=$(cat ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday | grep "TGE-"| wc -l)
	while [ $search -eq 1 ];do
	 lct=$(cat ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt | grep "TGE-" | wc -l)
     id=$(cat ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt | grep "TGE-" |tail -n $cnt | head -n 1)
	 timeout=$(echo $id | grep TIMEOUT | wc -l)
	 ide=$(echo $id | wc -L)
	 ll=$(cat ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday)
	 if [ $ll = $(uname -r) ]; then
     echo "test finished for this kernel"
		 exit 255
	 else
		 tstat=$(echo $ll | grep [^0-9] | wc -l)
		 if [ $tstat -gt 0 ]; then
		 #last test is finished
			ll=0
		 fi
	 fi
	 
	 if [ $ide -eq 0 ]; then
#2 the case id not find in this line
			if [ $lct -eq 0 ]; then
	#3 if no case is run before
				search=0
				if [ $ll -eq 0 ]; then
		#4 no former fail? start from first case
					echo 1 > ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
				else
		#4 skip formal fail
					if [ $total_tc -gt $ll ]; then
					    if [ $rep = "1" ]; then
							line=$ll
						else
							line=$(expr $ll + 1)
						fi
					echo $line > ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
					#sh -c "sed -i '1,${line}s/^/#/g' ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday"
					sh -c "cat ${TEST_PATH}/runtest/$CMDFILE | sed '1,${ll}s/^/#/g' > ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday"
					else
						echo "all test failed restart test"
						echo 0 > ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
					fi
				fi
			else
	#3 there is case run before
				if [ $cnt -gt $lct  ]; then
		#4 can not find any start test from begin
					search=0
					echo "former test cases list is changed!"
					if [ $ll -eq 0 ]; then
				#5 if no former fail cases
						echo 1 > ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
					else
				#5 has former fail case
						if [ $total_tc -gt $ll ]; then
					    	if [ $rep = "1" ]; then
								line=$ll
							else
								line=$(expr $ll + 1)
							fi
							echo $line > ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
							#sh -c "sed -i '1,${line}s/^/#/g' ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday"
							sh -c "cat ${TEST_PATH}/runtest/$CMDFILE | sed '1,${ll}s/^/#/g' > ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday"
						else
							echo "all following test failed restart test"
							echo 0 > ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
						fi
					fi
				else
		#4 search former line
      		cnt=$(expr $cnt + 1)
				fi
			fi
	 else
#2 case ID avaialble
	  ss=$(echo $id | awk '{print $1}')
      line=$(grep -n "${ss}" ${TEST_PATH}/runtest/$CMDFILE | awk '{print $1}' | cut -d ":" -f 1)
			if [ -z $ll ]; then
	#3 if no former fail data
				ll=$(echo $line | head -n 1)
			fi
	 		llc=$(echo $line | wc -w)
			if [ $llc -gt 1 ]; then
	#3 if there are multi cases for same ID
				myline=$line
				line=$ll
				for ilc in $myline
				do
					if [ $ilc -eq $ll ]; then
						line=$ll
						break;
					elif [ $ilc -gt $ll ]; then
						line=$ilc
						break;
					else
						echo $line > /dev/null
					fi
				done
			fi
			if [ $timeout -eq 0 ]; then
				if [ ! -z "$line" ] ; then
	#3 has last success case 
					if [ $ll -gt $line ]; then
			#4 former fail cases is after current success case
					    	if [ $rep = "1" ]; then
								line=$ll
							else
								line=$(expr $ll + 1)
							fi
					else
			#4 former fail cases is before the last success cases 
					    	if [ $rep = "1" ]; then
								line=$line
							else
								line=$(expr $line + 1)
							fi
					fi
				else
	#3 has not last success cases
					if [ $rep = "1" ]; then
						line=$ll
					else
						line=$(expr $ll + 1)
					fi
				fi
			else
			#3 timeout cases
				if [ ! -z "$line" ] ; then
		#3 has last success case 
					if [ $ll -gt $line ]; then
			#4 former fail cases is after current success case
					    if [ $rep = "1" ]; then
								line=$ll
						else
							line=$(expr $ll + 1)
						fi
					else
			#4 former fail cases is before the last success cases 
					    if [ $rep = "1" ]; then
							line=$line
						else
							line=$(expr $line + 1)
						fi
					fi
				else
					    if [ $rep = "1" ]; then
							line=$ll
						else
							line=$(expr $ll + 1)
						fi
				fi
			fi
			if [ -z "$line" ]; then
			#if the case id change and can not find then
				line=$ll
			fi
			echo $line > ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
			ll=$(expr $line - 1)
			sh -c "cat ${TEST_PATH}/runtest/$CMDFILE | sed '1,${ll}s/^/#/g' > ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday"
			#sh -c "sed -i '1,${line}s/^/#/g' ${TEST_PATH}/runtest/temp_test_${CMDFILE}_$tday"
			search=0
	 fi
	done
else
#1 fisrt run reset counter
	echo 1 >  ${TEST_PATH}/temp_cnt_${CMDFILE}_$tday
fi
${TEST_PATH}/runltp -p -g ${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.html ${ADDOPT} -l ${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt -f temp_test_${CMDFILE}_$tday -o ${TEST_PATH}/output/${ARCH_PLATFORM}_${CMDFILE}_log_$tday
else
${TEST_PATH}/runltp -p -g ${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.html ${ADDOPT} -l ${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt -f $CMDFILE -o ${TEST_PATH}/${ARCH_PLATFORM}_${CMDFILE}_log_$tday
#${TEST_PATH}/runalltests.sh -v -p -l ${ARCH_PLATFORM}_${TEST_TYPE}_test.txt
fi
lastcmd=$(cat ${TEST_PATH}/runtest/$CMDFILE | grep -v "#" |grep "TGE-" | tail -n 1| awk '{print $1}')
rlastcmd=$(cat ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt | grep "TGE-" | tail -n 1 | awk '{print $1}')
flastcmd=$(cat ${TEST_PATH}/output/LTP_RUN_ON-${ARCH_PLATFORM}_${CMDFILE}_log_${tday}.failed | grep "TGE-" | tail -n 1 | awk '{print $1}')
if [ -z $(echo $lastcmd | grep $rlastcmd)  ];then
     echo "case result and case final result does not match will try restest in new kernel"
else
	echo $(uname -r) > ${TEST_PATH}/temp_cnt_${CMDFILE}_${tday}
fi
append_md5=$(md5sum ${TEST_PATH}/output/${ARCH_PLATFORM}_${CMDFILE}_log_$tday | cut -c 1-6)
mv ${TEST_PATH}/output/${ARCH_PLATFORM}_${CMDFILE}_log_$tday ${TEST_PATH}/output/${ARCH_PLATFORM}_${CMDFILE}_log_${tday}_${append_md5}
mv ${TEST_PATH}/output/LTP_RUN_ON-${ARCH_PLATFORM}_${CMDFILE}_log_${tday}.failed ${TEST_PATH}/output//LTP_RUN_ON-${ARCH_PLATFORM}_${CMDFILE}_log_${tday}_${append_md5}.failed
mv ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_$tday.txt ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_${tday}_${append_md5}.txt

if [ -z $(echo $lastcmd) ];then
	echo "==========VTE case failed=================================================="
	echo "==========No Failed cases=================================================="
	echo "==========================================================================="
else
	echo "==========VTE case failed=================================================="
	cat ${TEST_PATH}/output//LTP_RUN_ON-${ARCH_PLATFORM}_${CMDFILE}_log_${tday}_${append_md5}.failed
fi

echo "==========VTE test summary=================================================="
cat ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_${tday}_${append_md5}.txt

echo "==========VTE test log=================================================="
cat ${TEST_PATH}/output/${ARCH_PLATFORM}_${CMDFILE}_log_${tday}_${append_md5} 

echo "==========Remove VTE tempfile from server============================================"
rm -rf ${TEST_PATH}/output//LTP_RUN_ON-${ARCH_PLATFORM}_${CMDFILE}_log_${tday}_${append_md5}.failed
rm -rf ${TEST_PATH}/results/${ARCH_PLATFORM}_${TEST_TYPE}_${CMDFILE}_${tday}_${append_md5}.txt
rm -rf ${TEST_PATH}/output/${ARCH_PLATFORM}_${CMDFILE}_log_${tday}_${append_md5}

echo "FREESCALE LBG TEST END"
umount /tmp

if [ -z $(echo $lastcmd) ];then
	echo "==========LAVA VTE test pass - no failure========================================"
	exit 0
else
	echo "==========LAVA VTE test failed - please check it=================================="
	exit 1
fi
