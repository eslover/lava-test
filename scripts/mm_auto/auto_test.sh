#!/bin/bash
#auto_test.sh

# This script feed gplay with media files and parse the output of gplay to realize the auto testing
# Testing results and logs will save in files

# version history
# 2014/02/28      first version
# 2014/03/03      fix problem of UTF-8 strings support of 'column' command
#                 improve the EOS check before and during a command
#                 fix problem of the logging, use >> instead of > for gplay
# 2014/03/04      Add test mode option for different testing purpose
# 2014/03/07      fix the problem of missing logs when clear the log pipe, 
#                 use two log pipe file, one for result analyse, one for EOS detection
# 2014/03/11      increase the exit command wait time, 
#                 kill prevous gplay process if exist before start a new one
#                 default to depress the printing on console, just show the testing progress
#                 and add an option to enable the printing on console
# 2014/03/14      Add support for gplay1.0 test. ask user to input gstreamer version before testing.
# 2014/03/31      Add filter reason
# 2014/04/02      support continue remaining command if possible
# 2014/04/02      Add support for cpu/memory usage statistic

# uncomment for debugging
#set -xv

# the version of this script
VER=0.6
echo "`basename $0` version $VER"

# disable gstreamer debugging info
export GST_DEBUG=0

# UTF8 support
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# only record log of error files
LOG_ERR_ONLY=1

# show logs on console?
SHOW_CON_LOG=0

# wheather continue remain command if one command failed
TRY_REMAIN_CMD=0

# setup the time out value
PLAY_START_TIMEOUT=5
CMD_WAIT=1
CMD_STOP_TIMEOUT=5
CMD_PLAY_TIMEOUT=3
CMD_PAUSE_TIMEOUT=1
CMD_RATE_TIMEOUT=3
CMD_SEEK_TIMEOUT=3
CMD_EXIT_WAIT=5
QUERY_WAIT_US=100000
POSITION_CHECK_INTERVAL_US=1000000
USLEEP_500_MS=500000

# seek position tolerance in ms
SEEK_CHECK_TOLERANCE=2

TEST_VIDEO=false
TEST_AUDIO=false
MEDIA_DIR=
PREFIX=
SCAN_MEDIA=false
LIST_FILE=
TEST_NAME=
LOG_FILE="log.txt"
RESULT_FILE="fail.xls"
IGNORE_FILE="fail_ignored.xls"
CMD_FILE=
FILTER_SCRIPT="filter.sh"
#SINGLE_FILE=
GPLAY=
GST_VER=
PS_OPT="aux"
RESULT_FOLDER="result"
TEST_MODE=
DEFAULT_TEST_MODE="single"

TEMP_FILE_LIST=".file_list"
BIN=".gplay_wrap.sh"
DEFAULT_CMDS=".default_auto_cmd"
TEMP_LOG=.tmp_log
TEMP_LOG_PIPE=.log_pipe
TEMP_CMD_PIPE=.cmd_pipe
CPU_MEM_USAGE="cpu_mem_usage"
CPU_MEM_STAT=0

if [ -f /bin/ps ]; then
    ls -l /bin/ps | grep "busybox"
    if [ $? -eq 0 ]; then
	PS_OPT=""
    fi
fi

generate_default_cmd()
{
cat >$DEFAULT_CMDS <<EOF
e 0 20
e 1 70
e 0 10
a
a
s
p
c 0.5
c 4
c -4
c 1
s
p
t 90
t 0
z 0 0 400 400
k 32 32 64 64
s
x

EOF
}

generate_filter_script()
{
cat >$FILTER_SCRIPT <<EOF
#!/bin/bash
#the filtering shell script

# usage: filter.sh input_file filter_list [-v]

#set -xv
# UTF8 support
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

usage()
{
    echo "usage: filter.sh [-p PREFIX][-v] input_file filter_list"
    echo "       input_file: the input file contains all failed files"
    echo "       filter_list: the list of files need to be filtered. if multiple files need to"
    echo "       be applied, specify them quotation mark"
    echo "       -p PREFIX: the prefix path for each file pathname, if this option specified, then the filter will compare"
    echo "       the whole pathname after removing the PREFIX, if this option not specified, then the filter will only"
    echo "       compare the file name"
    echo "       -v: print the filtered files during the process"
}

VERBOSE=0
PREFIX=

while getopts "vhp:" arg
do
    case \$arg in
    v) VERBOSE=1
       ;;
    h) usage
       exit 0
       ;;
    p) PREFIX="\$OPTARG"
       ;;
    ?) echo "Invalid option \$arg"
       exit 1
       ;;
    esac
done

shift \`expr \$OPTIND - 1\`
if [ \$# -lt 2 ]; then
    usage
    exit 0
fi

RESULT_FILE="\$1"
cp \$RESULT_FILE \${RESULT_FILE}.orgin
RESULT_FILE=\${RESULT_FILE%.*}
FILTER_LIST="\$2"
echo "Performing filtering..."

:> \${RESULT_FILE}_temp
:> \${RESULT_FILE}_ignored.xls

if [ -n "\$FILTER_LIST" ]; then
    while read line
    do
        skip=0
        if [ -z "\$line" ]; then
            continue
        fi

        text=\`echo "\$line" | grep -iE "File not exist|file size is 0"\`
        if [ \$? -eq 0 ] && [ -n "\$text" ]; then
            if [ \$VERBOSE -eq 1 ]; then
                echo "{\$line} filtered out"
            fi
            echo -e "\$line" >> \${RESULT_FILE}_ignored.xls
            continue
        fi

        path=\`echo -e "\$line" | cut -f1\`
        reason1=\`echo -e "\$line" | cut -f2\`
        reason2=\`echo -e "\$line" | cut -f3\`
        if [ -n "\$PREFIX" ]; then
	    name=\${path#\$PREFIX}
            if [ "\${name:0:1}" = "/" ]; then
                name=\${name:1}
            fi

            #name=\`echo "\$name" | sed 's/\//\\\\\\\\\\//g'\`
        else
            name=\`basename "\$path"\`
        fi

        if [ -n "\$reason1" ]; then
            #remove any console control string
            reason1=\${reason1##\\33[*m}

            #extract the failed command
            echo "\$reason1" | grep "\[.*\]" >/dev/null
            if [ \$? -eq 0 ]; then
                reason1=\${reason1##*[}
                reason1=\${reason1%%]*}
                if [ "\${reason1:0:1}" = "e" ]; then
                    reason1=[\${reason1:0:3}]
                elif [ "\${reason1:0:1}" != "c" ]; then
                    reason1=[\${reason1:0:1}]
                else
                    reason1=[\${reason1}]
                fi
            fi
        else
            echo -e "\$line" >> \${RESULT_FILE}_temp
            contine
        fi

        if [ -n "\$reason2" ]; then
            reason2=\${reason2##\\33[*m}
        fi

        for file in \$FILTER_LIST
        do
            grep -F "\$name" \$file > .temp_match
            while read ign_line
            do
                ign_line=\`echo "\$ign_line"\`
                if [ "\${ign_line:0:1}" = "#" ] || [ "\${ign_line:0:2}" = "//" ]; then
                    continue
                fi

                ignore_reason1=\`echo "\$ign_line" | cut -d: -f2\`
                echo "\$ign_line" | grep ":" >/dev/null
                if [ \$? -eq 0 ]; then
                    echo "\$ignore_reason1" | grep -F "\$reason1" >/dev/null
                    m1=\$?
                    echo "\$ignore_reason1" | grep -F "[c]" >/dev/null
                    m2=\$?
                    echo "\$reason1" | grep "\[c .*\]" >/dev/null
                    m3=\$?
                    if [ \$m1 -eq 0 ] || [ \$m2 -eq 0 -a \$m3 -eq 0 ]; then
                        ignore_reason2=\`echo "\$ign_line" | cut -d: -f3\`
                        if [ -n "\$ignore_reason2" ]; then
                            echo "\$reason2" | grep -F "\$ignore_reason2" >/dev/null
                            if [ \$? -eq 0 ]; then
                                skip=1
                                break
                            fi
                        else
                            skip=1
                            break
                        fi
                    fi
                else
                    skip=1
                    break
                fi
            done < .temp_match

            if [ \$skip -eq 1 ]; then
                if [ \$VERBOSE -eq 1 ]; then
                    echo "{\$line} filtered out"
                fi
                echo -e "\$line" >> \${RESULT_FILE}_ignored.xls
                break
            fi
        done

        if [ \$skip -eq 0 ]; then
            echo -e "\$line" >> \${RESULT_FILE}_temp
        fi
    done < \${RESULT_FILE}
    rm .temp_match -f >/dev/null
fi

# Generate fail file list for later testing
cut -f1 \${RESULT_FILE}_temp > \${RESULT_FILE}.list

# Sorting
sort -t\$'\t' -k2 \${RESULT_FILE}_temp > \${RESULT_FILE}.xls
rm -f \${RESULT_FILE}_temp

chmod 777 \${RESULT_FILE}.xls
chmod 777 \${RESULT_FILE}.list
chmod 777 \${RESULT_FILE}_ignored.xls

echo "Filtering done"
echo ""
echo "All failed files recorded in : \${RESULT_FILE}"
echo "Failed files after filtering out unsupported files : \${RESULT_FILE}.xls"
echo "Remain failed after filtering : \`awk 'END{print NR}' \${RESULT_FILE}.xls\`"
echo "file \${RESULT_FILE}.list generated for re-check (use -l option)"
echo ""
EOF
    chmod +x $FILTER_SCRIPT
}

# check if failed file should be ignored. 
# $1 the failed file
# $2 the ignore list
check_ignore()
{
    skip=0
    if [ -z "$1" ] || [ -z "$2" ]; then
	return 0
    fi
    
    text=`echo "$1" | grep -iE "File not exist|file size is 0"`
    if [ $? -eq 0 ] && [ -n "$text" ]; then
        return 1
    fi

    path=`echo -e "$1" | cut -f1`
    reason1=`echo -e "$1" | cut -f2`
    reason2=`echo -e "$1" | cut -f3`
    if [ -n "$PREFIX" ]; then
	name=${path#$PREFIX}
	if [ "${name:0:1}" = "/" ]; then
	    name=${name:1}
	fi
	#name=`echo "$name" | sed 's/\//\\\\\//g'`
    else
	name=`basename "$path"`
    fi
    
    if [ -n "$reason1" ]; then
    	reason1=${reason1##\33[*m}
	echo "$reason1" | grep "\[.*\]" >/dev/null
	if [ $? -eq 0 ]; then
	    reason1=${reason1##*[}
		reason1=${reason1%%]*}
	    if [ "${reason1:0:1}" = "e" ]; then
		reason1=[${reason1:0:3}]
	    elif [ "${reason1:0:1}" != "c" ]; then
		reason1=[${reason1:0:1}]
	    else
		reason1=[${reason1}]
	    fi
	fi
    else
	return 0
    fi
    
    if [ -n "$reason2" ]; then
	reason2=${reason2##\33[*m}
    fi
    
    for file in $2
    do
        grep -F "$name" $file > .temp_match
        while read ign_line
        do
            ign_line=`echo "$ign_line"`
            if [ "${ign_line:0:1}" = "#" ] || [ "${ign_line:0:2}" = "//" ]; then
                continue
            fi
	    
            ignore_reason1=`echo "$ign_line" | cut -d: -f2`
            echo "$ign_line" | grep ":" >/dev/null
            if [ $? -eq 0 ]; then
                echo "$ignore_reason1" | grep -F "$reason1" >/dev/null
                m1=$?
                echo "$ignore_reason1" | grep -F "[c]" >/dev/null
                m2=$?
                echo "$reason1" | grep "\[c .*\]" >/dev/null
                m3=$?
                if [ $m1 -eq 0 ] || [ $m2 -eq 0 -a $m3 -eq 0 ]; then
                    ignore_reason2=`echo "$ign_line" | cut -d: -f3`
                    if [ -n "$ignore_reason2" ]; then
                        echo "$reason2" | grep -F "$ignore_reason2" >/dev/null
                        if [ $? -eq 0 ]; then
                            skip=1
                            break
                        fi
                    else
                        skip=1
                        break
                    fi
                fi
            else
                skip=1
                break
            fi
        done < .temp_match
	
        if [ $skip -eq 1 ]; then
            break
        fi
    done
    rm .temp_match -f >/dev/null	

    return $skip
}

# video files find pattern
VIDEO_SEARCH="\
-iname *.mp4 \
-o -iname *.mov \
-o -iname *.f4v \
-o -iname *.3gp \
-o -iname *.avi \
-o -iname *.wmv \
-o -iname *.asf \
-o -iname *.mkv \
-o -iname *.flv \
-o -iname *.mpg \
-o -iname *.vob \
-o -iname *.ts \
-o -iname *.m2ts \
-o -iname *.mpeg \
-o -iname *.rmvb \
-o -iname *.rm \
-o -iname *.rv"


# audio file find pattern
AUDIO_SEARCH="\
-iname *.aac \
-o -iname *.adts \
-o -iname *.wav \
-o -iname *.flac \
-o -iname *.ogg \
-o -iname *.m4a \
-o -iname *.wma \
-o -iname *.mka \
-o -iname *.mp3 \
-o -iname *.ra"

usage()
{
    echo -e "\nUsage : `basename $0` [-d path] [-l file_list] [-V] [-A] [-v] [-C] [-S] [-p prefix] [-e ex_list] [-n test_name] [-m mode] [cmd_list]"
    echo "Note :"
    echo "    -d path         path of the directory containing the meida files to be tested. This"
    echo "                    script will scan the media files in this directory automatically."
    echo "    -l file_list    the pre-generated list of files to be tested."
    echo "    -V              test all video files "
    echo "    -A              test all audio files "
    echo "    -C              try to execute remain command if possible even if previous command failed"
    echo "                    if this option is not specified, once a command failed, all following command will not be executed"
    echo "    -S              Enalbe statistic for cpu usage and memory usage for all files"
    echo "    -p prefix       the prefix of the stream path, if this option specified, then the filter will match the"
    echo "                    whole path name after removing the prefix, if this option is not specified, then the filter"
    echo "                    will only match the file name"
    echo "    -e ex_list      fiter out the unsupported files in the generated result file. "
    echo "                    if multiple files need be specified, enclose them with \"\" and seperated by while space"
    echo "    -n test_name    the prefix of the generated log and result files, also a folder named as"
    echo "                    test_name will be created to hold those result files. if test_name provided"
    echo "                    test_name folder and test_name/test_name_log.txt and test_name/test_name_result.txt"
    echo "                    are generated. otherwise, folder result and result/log.txt and result/result.txt"
    echo "                    will be generated. To continue unfinished test, input same test_name with previous."
    echo "    -m mode         testing mode. could be following:"
    echo "                        single : spawn a new gplay process for each file testing cycle"
    echo "                        playlist : only spawn one gplay process, use the playlist of gplay"
    echo "    cmd_list        the gplay command sequence list which is to be executed during test. "
    echo "                    if the command list is not specified, then the internal command sequence"
    echo "                    will be used"
    echo "    -v              show detail logs on console, by default processing log doesn't show on console"
}

# function : query and check state
# $1 : the state string
# $2 : timeout value
# return : 0 OK, 1 NG, 3: eos
check_state()
{
    counter=0
    while [ 1 ]
    do 
        # query state
	:> $TEMP_LOG_PIPE
	echo "q s" >> $TEMP_CMD_PIPE
	usleep $QUERY_WAIT_US
	grep -i "$1" $TEMP_LOG_PIPE > /dev/null
	if [ $? -eq 0 ]; then
	    break
        else
	    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
	    if [ $? -eq 0 ]; then
		return 3
	    fi

	    grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG >/dev/null
	    if [ $? -eq 0 ]; then
		return 1
	    fi

	    counter=`expr $counter + 1`
	    if [ $counter -ge $2 ]; then
		return 1
	    else
		sleep $CMD_WAIT
	    fi
	fi
    done
    return 0
}

# function : query and check playing position
# $1 : interval in microsecond 
# return 0 position not change, 1 position increased, 2 position decreased, 3 eos, 4 can't get position, 5 position is 0
pos_info=""
check_position()
{
    :> $TEMP_LOG_PIPE
    echo "q p" >> $TEMP_CMD_PIPE
    usleep $QUERY_WAIT_US	
    position1=`grep -i "playing position :" $TEMP_LOG_PIPE | cut -d: -f2`

    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
    if [ $? -eq 0 ]; then
	return 3
    fi

    usleep $1
    :> $TEMP_LOG_PIPE
    echo "q p" >> $TEMP_CMD_PIPE
    usleep $QUERY_WAIT_US
    position2=`grep -i "playing position :" $TEMP_LOG_PIPE | cut -d: -f2`
    position1=`echo $position1`
    position2=`echo $position2`

    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
    if [ $? -eq 0 ]; then
	return 3
    fi
 
    if [ -z "$position1" ] || [ -z "$position2" ]; then
	pos_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
	if [ -z "$pos_info" ]; then
	    pos_info="position error, can not get position value"
	fi
	return 4
    else
	pos_info="position error, `expr $position1 / 1000000`ms->`expr $position2 / 1000000`ms"
        if [ $position2 -gt $position1 ]; then
	    return 1
	elif [ $position2 -lt $position1 ]; then
	    return 2
	elif [ $position2 -eq 0 ] && [ $position1 -eq 0 ]; then
	    return 5
	else
	    return 0
	fi
    fi
}

update_cpu_mem_usage()
{
    PS_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`

    if [ ! -z "$PS_INFO" ]; then
	cur_cpu_usage=`echo "$PS_INFO" | awk '{printf "%d", $3*10}'`
	cur_mem_usage=`echo "$PS_INFO" | awk '{print $6}'`

	if [ "$cpu_usage" = "unknown" ]; then
	    cpu_usage=$cur_cpu_usage
	else
	    if [ $cpu_usage -lt $cur_cpu_usage ]; then
		cpu_usage=$cur_cpu_usage
	    fi
	fi
	
	if [ "$mem_usage" = "unknown" ]; then
	    mem_usage=$cur_mem_usage
	else
	    if [ $mem_usage -lt $cur_mem_usage ]; then
		mem_usage=$cur_mem_usage
	    fi
	fi
    fi
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 2 ]; then
    usage
    exit 1
fi

#while getopts :hAVd:l:e:n: OPTION
while getopts hvAVCSd:l:p:e:n:m: OPTION
do
case $OPTION in
A) TEST_AUDIO=true
   ;;
V) TEST_VIDEO=true
   ;;
d) MEDIA_DIR=$OPTARG
   SCAN_MEDIA=true
   ;;
p) PREFIX=$OPTARG
   ;;
e) FILTER_LIST="$OPTARG"
   ;;
l) LIST_FILE=$OPTARG
   ;;
n) TEST_NAME=$OPTARG
   ;; 
v) SHOW_CON_LOG=1
   ;;
m) TEST_MODE=$OPTARG
   ;;
C) TRY_REMAIN_CMD=1
   ;;
S) CPU_MEM_STAT=1
   ;;
\?) usage
   exit 1
   ;;
esac
done 

shift `expr $OPTIND - 1`
#echo "$@"

CMD_FILE="$1"

echo "Please select the gstreamer version which this test base on: (1.0 or 0.10)?"
read answer
if [ "$answer" = "1.0" ]; then
    GPLAY="gplay-1.0"
    GST_VER="1.0"
elif [ "$answer" = "0.10" ]; then
    GPLAY="gplay"
    GST_VER="0.10"
else
    echo "Wrong gstreamer version number, please input 1.0 or 0.10"
    exit 1
fi

if [ -z "$TEST_MODE" ]; then
    echo "No test mode specified, use the default mode [$DEFAULT_TEST_MODE]"
    TEST_MODE=$DEFAULT_TEST_MODE
elif [ "$TEST_MODE" = "single" ] || [ "$TEST_MODE" = "playlist" ]; then
    echo "Testing with [$TEST_MODE] mode"
else
    echo "Undefined test mode, please check the mode name"
    usage
    exit 1
fi

# for remove the folder prefix
#if [ -n "$MEDIA_DIR" ] && [ ${MEDIA_DIR: -1} != "/" ]; then
#    MEDIA_DIR="${MEDIA_DIR}/"
#fi

if [ ! -z "$TEST_NAME" ]; then
    RESULT_FOLDER=${TEST_NAME}_${TEST_MODE}-$GST_VER
    LOG_FILE=${TEST_NAME}_${TEST_MODE}_$LOG_FILE
    RESULT_FILE=${TEST_NAME}_${TEST_MODE}_$RESULT_FILE
    IGNORE_FILE=${TEST_NAME}_${TEST_MODE}_$IGNORE_FILE
else
    RESULT_FOLDER=${RESULT_FOLDER}_${TEST_MODE}-$GST_VER
fi

if [ ! -d "$RESULT_FOLDER" ]; then
    mkdir $RESULT_FOLDER
    chmod 777 $RESULT_FOLDER
fi

TEMP_FILE_LIST=$RESULT_FOLDER/$TEMP_FILE_LIST
LOG_FILE=$RESULT_FOLDER/$LOG_FILE
RESULT_FILE=$RESULT_FOLDER/$RESULT_FILE
IGNORE_FILE=$RESULT_FOLDER/$IGNORE_FILE
DEFAULT_CMDS=$RESULT_FOLDER/$DEFAULT_CMDS
BIN=$RESULT_FOLDER/$BIN
TEMP_LOG=$RESULT_FOLDER/$TEMP_LOG
TEMP_LOG_PIPE=$RESULT_FOLDER/$TEMP_LOG_PIPE
TEMP_CMD_PIPE=$RESULT_FOLDER/$TEMP_CMD_PIPE
FILTER_SCRIPT=$RESULT_FOLDER/$FILTER_SCRIPT
CPU_MEM_USAGE=$RESULT_FOLDER/$CPU_MEM_USAGE

if [ -z "$CMD_FILE" ]; then
    echo "Command file not specified, use the internal default commands?(y/n)"
    read answer
    if [ "$answer" = "" ] || [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
	generate_default_cmd
	CMD_FILE=$DEFAULT_CMDS
    else
	usage
	exit 1
    fi
fi

if [ ! -f $CMD_FILE ]; then
    echo "File $CMD_FILE not exist!"
    usage
    exit 1
fi

generate_filter_script

continue=0
last_file=
pass=0
fail=0
filtered=0

if [ ! -z "$TEST_NAME" ]; then
    if [ -f "$LOG_FILE" ] && [ -f "$RESULT_FILE" ] && [ -f "$TEMP_FILE_LIST" ]; then
	echo "Continue previous test: $TEST_NAME [$TEST_MODE mode] (y/n)?"
	read answer
	if [ "$answer" = "" ] || [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
	    last_line=`tail -2 $LOG_FILE | grep -i "finished" 2>&1`
	    if [ $? -eq 0 ] && [ -n "$last_line" ]; then
		echo "Previous test $TEST_NAME [$TEST_MODE mode] was finished. Overwrite?(y/n)?"
		read answer
		if [ "$answer" = "" ] || [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
		    continue=0
		else
		    echo "Test canceled"
		    exit 0
	        fi
	    fi
	    continue=1
        fi
    fi
fi

if [ $continue -eq 1 ]; then
    # search last file name of previous test
    last_file=`grep ">>>>>>>>>>" $LOG_FILE | tail -1 | cut -d: -f2`
    TOTAL_CNT=`cat $TEMP_FILE_LIST | wc -l`
    total_remain=$TOTAL_CNT
    if [ -n "$last_file" ]; then
	echo "Continue previous test from file [$last_file]" | tee -a $LOG_FILE
	sub=`grep -nF "$last_file" $TEMP_FILE_LIST | cut -d: -f1`
	if [ -n "$sub" ]; then
	    total_remain=`expr $total_remain - $sub`
	    total_remain=`expr $total_remain + 1`
	fi
    else
	echo "Last file of previous test [$last_file] not found, start from the first file" | tee -a $LOG_FILE
    fi

    if [ $CPU_MEM_STAT -eq 1 ] && [ ! -f $CPU_MEM_USAGE ]; then
	echo -e "File Name\tCPU Usage(%)\tMemory Usage(KB)" > $CPU_MEM_USAGE
	chmod 777 $CPU_MEM_USAGE
    fi
else
    :> $LOG_FILE
    :> $RESULT_FILE
    :> $IGNORE_FILE
    :> $TEMP_FILE_LIST

    chmod 777 $LOG_FILE
    chmod 777 $RESULT_FILE
    chmod 777 $IGNORE_FILE
    chmod 777 $TEMP_FILE_LIST

    if [ $CPU_MEM_STAT -eq 1 ]; then
	echo -e "File Name\tCPU Usage(%)\tMemory Usage(KB)" > $CPU_MEM_USAGE
	chmod 777 $CPU_MEM_USAGE
    fi

    echo "Generated by `basename $0` version $VER @ `date`" > $LOG_FILE


    if [ "$SCAN_MEDIA" = "true" ]; then
	if [ ! -d "$MEDIA_DIR" ]; then
	    echo "Folder $MEDIA_DIR not exist!" | tee -a $LOG_FILE
	    usage
	    exit 1
	fi

	if [ "$TEST_VIDEO" = "false" ] && [ "$TEST_AUDIO" = "false" ]; then
	    echo "You must add option -V or -A or both to specify the test type"
	    usage
	    exit 1
	fi
	
	video_cnt=0
	audio_cnt=0
	if [ "$TEST_VIDEO" = "true" ]; then
	    echo "Searching video files ..." | tee -a $LOG_FILE
	    find $MEDIA_DIR $VIDEO_SEARCH > $TEMP_FILE_LIST 
	    video_cnt=`awk 'END{print NR}' $TEMP_FILE_LIST`
	    echo "video files searching done, found $video_cnt video files" | tee -a $LOG_FILE
	fi
	if [ "$TEST_AUDIO" = "true" ]; then
	    echo "Searching audio files ..." | tee -a $LOG_FILE
	    find $MEDIA_DIR $AUDIO_SEARCH >> $TEMP_FILE_LIST
	    audio_cnt=`awk 'END{print NR}' $TEMP_FILE_LIST`
	    echo "audio files searching done, found `expr $audio_cnt - $video_cnt` audio files" | tee -a $LOG_FILE
	fi
    fi

    if [ ! -z "$LIST_FILE" ]; then
	if [ ! -f "$LIST_FILE" ]; then
	    echo "File $LIST_FILE not exist!" | tee -a $LOG_FILE
	    usage
	    exit 1
	fi
	cat $LIST_FILE >> $TEMP_FILE_LIST
	echo "Add `awk 'END{print NR}' $LIST_FILE` media files from $LIST_FILE" | tee -a $LOG_FILE
    fi
    
    TOTAL_CNT=`cat $TEMP_FILE_LIST | wc -l`
    total_remain=$TOTAL_CNT
fi

START_TIME=`date +%s`
echo "Total $total_remain files to be tested. start testing @ [`date`]" | tee -a $LOG_FILE

# Create gplay wraper script
echo "#!/bin/sh" > $BIN
echo "" >> $BIN
if [ "$TEST_MODE" = "single" ]; then
    echo "$GPLAY \"\$1\" --quiet 2>&1" >> $BIN
elif [ "$TEST_MODE" = "playlist" ]; then
    echo "$GPLAY \"\$1\" --quiet --noautonext 2>&1" >> $BIN
fi 
chmod +x $BIN > /dev/null

line_cnt=0
percent=0 
first_start=1
eos=0
prvious_line=
echo

if [ $SHOW_CON_LOG -eq 0 ]; then
    if [ -f /usr/bin/tput ]; then
	_R=`tput lines`
#    _R2=`expr $_R - 2`
#    tput cup $_R2 0  
#    printf "["
    fi
fi

while read -r line
do
    line_cnt=`expr $line_cnt + 1`
    percent=`expr $line_cnt \* 100`
    percent=`expr $percent / $TOTAL_CNT`

# progress bar printing is slow, disable
#    if [ $SHOW_CON_LOG -eq 0 ]; then
#	_P=`expr $percent + 1`
#	cnt=1
#	while [ $cnt -le $percent ]
#	do
#	    tput cup $_R2 $cnt
#	    printf ">"
#	    cnt=`expr $cnt + 1`
#	done
#	tput cup $_R2 $_P
#	printf ">"
#
#	tput cup $_R2 102  
#	printf "]%d%% [%d of %d]" $percent $line_cnt $TOTAL_CNT
#    fi
    
    if [ "${line:0:1}" = "#" ] || [ -z "$line" ]; then
	if [ $SHOW_CON_LOG -eq 0 ] && [ -f /usr/bin/tput ]; then
	    tput cup $_R 0
	    tput ed
	    printf "[%d of %d][%d%%]: Skip [%s]" $line_cnt $TOTAL_CNT $percent "${line#$MEDIA_DIR}"
	else
	    echo "[$line_cnt of $TOTAL_CNT][$percent%]: Skip ${line#$MEDIA_DIR}"
        fi
	continue
    fi

    if [ ! -z "$last_file" ]; then
	if [ "$last_file" = "$line" ]; then
	    if [ $SHOW_CON_LOG -eq 0 ]; then
		echo "Found last file of previous test : $last_file" >> $LOG_FILE
	    else
		echo "Found last file of previous test : $last_file" | tee -a $LOG_FILE
	    fi
	    last_file=""
	else
	    if [ $SHOW_CON_LOG -eq 0 ] && [ -f /usr/bin/tput ]; then
		tput cup $_R 0
		tput ed
		printf "[%d of %d][%d%%]: Skip [%s]" $line_cnt $TOTAL_CNT $percent "$line"
	    else
		echo "[$line_cnt of $TOTAL_CNT][$percent%]: Skip $line"
	    fi
	    continue
	fi
    fi

    if [ "$TEST_MODE" = "single" ]; then
        # check if previous gplay process still exist, if so, kill it
	counter=0
	while [ 1 ]
	do 
	    if [ -z $PS_OPT ]; then
		PIDS=`ps $PS_OPT | grep -F $GPLAY | grep -v "grep" | awk '{print $1}'`
	    else
		PIDS=`ps $PS_OPT | grep -F $GPLAY | grep -v "grep" | awk '{print $2}'`
	    fi

	    if [ -n "$PIDS" ]; then
		counter=`expr $counter + 1`
		if [ $counter -ge 30 ]; then
		    for pid in $PIDS
		    do
			kill -9 $pid > /dev/null 2>&1
		    done
		    break
		else
		    usleep $QUERY_WAIT_US
		fi
	    else
		break
	    fi
	done
    else
        # wait a moment for previous test. 
	usleep $USLEEP_500_MS
    fi

    eos=0

    if [ $SHOW_CON_LOG -eq 0 ]; then
	if [ -f /usr/bin/tput ]; then
	    tput cup $_R 0
	    tput ed
	    printf "[%d of %d][%d%%][pass:%d][fail:%d][ignored:%d]: Testing [%s] ..." $line_cnt $TOTAL_CNT $percent $pass $fail $filtered "${line#$MEDIA_DIR}"
	else
	    echo "[$line_cnt of $TOTAL_CNT][$percent%][pass:$pass][fail:$fail][ignored:$filtered]: Testing ${line#$MEDIA_DIR} ..."
	fi
	echo -e "\n>>>>>>>>>> Testing :$line:[$line_cnt of $TOTAL_CNT][$percent%]\n" >> $LOG_FILE
    else
	echo -e "\n>>>>>>>>>> Testing :$line:[$line_cnt of $TOTAL_CNT][$percent%]\n" | tee -a $LOG_FILE
    fi

    if [ ! -f "$line" ]; then
	out_line="${line}\tFile not exist\tFile not exist"
	if [ $SHOW_CON_LOG -eq 0 ]; then
	    echo -e "$out_line" >> $IGNORE_FILE
	    echo -e "$out_line" >> $LOG_FILE
	else
	    echo -e "$out_line" | tee -a $IGNORE_FILE $LOG_FILE
	fi

	filtered=$(($filtered+1))
	continue
    fi
    
    sync

    :> $TEMP_LOG_PIPE
    :> $TEMP_LOG
    
    # call gplay wraper script to start gplay in a background shell
    if [ "$TEST_MODE" = "single" ]; then
	:> $TEMP_CMD_PIPE
	if [ $SHOW_CON_LOG -eq 0 ]; then
	    ($BIN "$line" <$TEMP_CMD_PIPE 2>&1 | tee -a $TEMP_LOG_PIPE $TEMP_LOG >/dev/null 2>&1) &
	else
	    ($BIN "$line" <$TEMP_CMD_PIPE 2>&1 | tee -a $TEMP_LOG_PIPE $TEMP_LOG 2>&1) &	
	fi
    elif [ "$TEST_MODE" = "playlist" ]; then
	# check if gplay process exist, if doesn't, start a new one, else issue "l" command to play next file
	PID=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
	if [ -n "$PID" ]; then
	    echo "l $line" >> $TEMP_CMD_PIPE
	else
	    if [ $first_start -eq 0 ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo -e "\ngplay process instance not found, start a new one, previous played file is [$previous_line]\n" >> $LOG_FILE
		else
		    echo -e "\ngplay process instance not found, start a new one, previous played file is [$previous_line]\n" | tee -a $LOG_FILE
		fi
	    fi

	    :> $TEMP_CMD_PIPE
	    if [ $SHOW_CON_LOG -eq 0 ]; then
		($BIN "$line" <$TEMP_CMD_PIPE 2>&1 | tee -a $TEMP_LOG_PIPE $TEMP_LOG >/dev/null 2>&1) &		
	    else
		($BIN "$line" <$TEMP_CMD_PIPE 2>&1 | tee -a $TEMP_LOG_PIPE $TEMP_LOG 2>&1) &
	    fi
	    first_start=0
	fi       
    else
        echo "Unknown test mode [$TEST_MODE]"	
	exit 1
    fi

    previous_line="$line"

    # check if play success
    play_ok=0
    sleep $CMD_WAIT


    if [ $CPU_MEM_STAT -eq 1 ]; then
	cpu_usage="unknown"
	mem_usage="unknown"

	update_cpu_mem_usage
    fi

    counter=0
    while [ 1 ] 
    do  
	err_info=`egrep -h -i ' fail| error|CRITICAL|Segment|time out|Floating point exception|Aborted' $TEMP_LOG`
	if [ $? -eq 0 ] && [ -n "$err_info" ]; then
	    file_size=`du "$line" | cut -f1`
	    err_info=`echo -e "$err_info" | sed ':a ; N;s/\n/ | / ; t a ; ' | sed 's/\t/ /g' | sed -r 's/\x1B\[[0-9;]*[JKmsu]//g'`
	    reason="Start play failed"

	    echo "$err_info" | grep -i "Segmentation fault" >/dev/null
	    if [ $? -eq 0 ]; then
                reason="Segmentation fault"
            fi

	    echo "$err_info" | grep -i "Aborted" >/dev/null
	    if [ $? -eq 0 ]; then
		reason="Aborted"
	    fi

	    echo "$err_info" | grep -i "Floating point exception" >/dev/null
	    if [ $? -eq 0 ]; then
                reason="Floating point exception"
            fi

	    echo "$err_info" | grep -i "CRITICAL" >/dev/null
	    if [ $? -eq 0 ]; then
		reason="CRITICAL"
	    fi

	    out_line="${line}\t$reason\t${err_info} (file size is $file_size)"
	    if [ $SHOW_CON_LOG -eq 0 ]; then
	    	echo -e "$out_line" >> $TEMP_LOG
	    else
		echo -e "$out_line" | tee -a $TEMP_LOG
	    fi

	    check_ignore "$out_line" "$FILTER_LIST"
	    if [ $? -eq 0 ]; then
		fail=$(($fail+1))
		echo -e "$out_line" >> $RESULT_FILE
	    else
		filtered=$(($filtered+1))
		echo -e "$out_line" >> $IGNORE_FILE
	    fi

	    grep 'mem allocation failed' $TEMP_LOG > /dev/null
	    if [ $? -eq 0 ]; then
		echo "Meminfo" >> $TEMP_LOG
		cat /proc/meminfo >> $TEMP_LOG
		ps $PS_OPT >> $TEMP_LOG
	    fi
	    
	    if [ "$TEST_MODE" = "single" ]; then
		gplay_ps=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
		if [ -n "$gplay_ps" ]; then
		    echo "x" >> $TEMP_CMD_PIPE
		fi
		usleep $USLEEP_500_MS
		gplay_ps=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
		if [ -n "$gplay_ps" ]; then
	            killall -9 $GPLAY > /dev/null 2>&1
		fi
	    else
		usleep $USLEEP_500_MS
	    fi

	    play_ok=0
	    cat $TEMP_LOG >> $LOG_FILE
	    break
        fi

	grep "fsl_player_play\(\)" $TEMP_LOG > /dev/null
	if [ $? -eq 0 ]; then
	    # double check the play status
	    echo "q s" >> $TEMP_CMD_PIPE
	    usleep $QUERY_WAIT_US

	    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
	    if [ $? -eq 0 ]; then
		if [ $LOG_ERR_ONLY -eq 0 ]; then
		    cat $TEMP_LOG >> $LOG_FILE
		fi
		eos=1
		break
	    fi

	    grep -i "Current state : Playing" $TEMP_LOG > /dev/null
	    if [ $? -eq 0 ]; then
		play_ok=1
	    else
		grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
		if [ $? -eq 0 ]; then
		    if [ $LOG_ERR_ONLY -eq 0 ]; then
			cat $TEMP_LOG >> $LOG_FILE
		    fi
		    eos=1
		else
		    out_line="${line}\tStart play failed\tPlayer state not in playing state"
		    if [ $SHOW_CON_LOG -eq 0 ]; then
			echo -e "$out_line" >> $TEMP_LOG
		    else
			echo -e "$out_line" | tee -a $TEMP_LOG
		    fi

		    check_ignore "$out_line" "$FILTER_LIST"
		    if [ $? -eq 0 ]; then
			fail=$(($fail+1))
			echo -e "$out_line" >> $RESULT_FILE
		    else
			filtered=$(($filtered+1))
			echo -e "$out_line" >> $IGNORE_FILE
		    fi
		    cat $TEMP_LOG >> $LOG_FILE
		fi
		play_ok=0
	    fi
	    break
        fi
	
	counter=$(($counter+1))
	if [ $counter -ge $PLAY_START_TIMEOUT ]; then
	    out_line="${line}\tStart play failed\tWait play start timeout, timeout is $PLAY_START_TIMEOUT"
	    if [ $SHOW_CON_LOG -eq 0 ]; then
		echo -e "$out_line" >> $TEMP_LOG
	    else
		echo -e "$out_line" | tee -a $TEMP_LOG
	    fi

	    check_ignore "$out_line" "$FILTER_LIST"
	    if [ $? -eq 0 ]; then
		fail=$(($fail+1))
		echo -e "$out_line" >> $RESULT_FILE
	    else
		filtered=$(($filtered+1))
		echo -e "$out_line" >> $IGNORE_FILE
	    fi

	    play_ok=0
	    cat $TEMP_LOG >> $LOG_FILE
	    break
        else
	    sleep $CMD_WAIT
	    continue
	fi
    done

    if [ $play_ok -eq 0 ]; then
	if [ $eos -eq 1 ]; then
	    pass=$(($pass+1))
	    echo ">>>>> EOS <<<<<" >> $LOG_FILE

	    if [ $SHOW_CON_LOG -eq 0 ]; then
		echo -e "$line\tOK" >> $LOG_FILE
	    else
		echo -e "$line\tOK" | tee -a $LOG_FILE
	    fi
	fi
	
	if [ $CPU_MEM_STAT -eq 1 ]; then
	    update_cpu_mem_usage
	    echo -e "${line}\t`awk 'BEGIN{printf "%.1f",'"$cpu_usage"'/10}'`\t$mem_usage" >> $CPU_MEM_USAGE
	fi

	continue
    fi

    # play start OK
    has_video=0
    seekable=0
    paused=false

    # query has video ?
    :> $TEMP_LOG_PIPE
    echo "q v" >> $TEMP_CMD_PIPE
    usleep $QUERY_WAIT_US
    num=`grep -i "video streams :" $TEMP_LOG_PIPE | cut -d: -f2`
    num=`echo $num`
    if [ -n "$num" ] && [ $num -gt 0 ]; then
	has_video=1
    fi

    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
    if [ $? -eq 0 ]; then
	echo ">>>>> EOS <<<<<" >> $LOG_FILE
	if [ $SHOW_CON_LOG -eq 0 ]; then
	    echo -e "$line\tOK" >> $LOG_FILE
	else
	    echo -e "$line\tOK" | tee -a $LOG_FILE
	fi

	if [ $LOG_ERR_ONLY -eq 0 ]; then
	    cat $TEMP_LOG >> $LOG_FILE
	fi

	pass=$(($pass+1))

	if [ $CPU_MEM_STAT -eq 1 ]; then
	    update_cpu_mem_usage
	    echo -e "${line}\t`awk 'BEGIN{printf "%.1f",'"$cpu_usage"'/10}'`\t$mem_usage" >> $CPU_MEM_USAGE
	fi

	continue
    fi
    
    # query seekable ?
    :> $TEMP_LOG_PIPE
    echo "q e" >> $TEMP_CMD_PIPE
    usleep $QUERY_WAIT_US
    grep -i "Seekable : Yes" $TEMP_LOG_PIPE > /dev/null
    if [ $? -eq 0 ]; then
	seekable=1;
    fi

    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
    if [ $? -eq 0 ]; then
	echo ">>>>> EOS <<<<<" >> $LOG_FILE
	if [ $SHOW_CON_LOG -eq 0 ]; then
	    echo -e "$line\tOK" >> $LOG_FILE
	else
	    echo -e "$line\tOK" | tee -a $LOG_FILE
	fi
	
	if [ $LOG_ERR_ONLY -eq 0 ]; then
	    cat $TEMP_LOG >> $LOG_FILE
	fi

	pass=$(($pass+1))

	if [ $CPU_MEM_STAT -eq 1 ]; then
	    update_cpu_mem_usage
	    echo -e "${line}\t`awk 'BEGIN{printf "%.1f",'"$cpu_usage"'/10}'`\t$mem_usage" >> $CPU_MEM_USAGE
	fi

	continue
    fi

    # query duration
    :> $TEMP_LOG_PIPE
    echo "q u" >> $TEMP_CMD_PIPE
    usleep $QUERY_WAIT_US
    DURATION=`grep -i "Duration :" $TEMP_LOG_PIPE | cut -d: -f2`
    DURATION=`echo $DURATION`
    if [ -n "$DURATION" ]; then
	DURATION=`expr $DURATION / 1000000000`
    else
	DURATION=0
    fi

    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
    if [ $? -eq 0 ]; then
	echo ">>>>> EOS <<<<<" >> $LOG_FILE
 	if [ $SHOW_CON_LOG -eq 0 ]; then
	    echo -e "$line\tOK" >> $LOG_FILE
	else
	    echo -e "$line\tOK" | tee -a $LOG_FILE
	fi

	if [ $LOG_ERR_ONLY -eq 0 ]; then
	    cat $TEMP_LOG >> $LOG_FILE
	fi

	pass=$(($pass+1))

	if [ $CPU_MEM_STAT -eq 1 ]; then
	    update_cpu_mem_usage
	    echo -e "${line}\t`awk 'BEGIN{printf "%.1f",'"$cpu_usage"'/10}'`\t$mem_usage" >> $CPU_MEM_USAGE
	fi

	continue
    fi

    cmd_fail=0
    any_cmd_fail=0
    err_info=""
    fseek_fail=0
    aseek_fail=0
    play_fail=0
    pause_fail=0
    stop_fail=0
    trick_fail=0
    rotate_fail=0
    resize_fail=0
    crop_fail=0
    exit_fail=0
    critical_fail=0

    # then execute the command in $CMD_FILE
    while read -r cmd
    do
	if [ -z "$cmd" ] || [ "${cmd:0:1}" = "#" ]; then
	    continue
        fi
	    
	if [ $has_video -eq 0 ]; then
	    case "${cmd:0:1}" in
		z|t|c|f|k)
		    if [ $SHOW_CON_LOG -eq 0 ]; then
			echo "Skip command [$cmd]" >> $TEMP_LOG
		    else
			echo "Skip command [$cmd]" | tee -a $TEMP_LOG
		    fi
		    continue
		    ;;
		*) ;;
	    esac
	fi

	if [ $seekable -eq 0 ]; then
	    if [ "${cmd:0:1}" = "e" ] || [ "${cmd:0:1}" = "c" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip command [$cmd]" >> $TEMP_LOG
		else
		    echo "Skip command [$cmd]" | tee -a $TEMP_LOG
		fi
		continue
	    fi
	fi

	if [ "$TEST_MODE" = "playlist" ]; then
	    if [ "$cmd" = "x" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip command [$cmd] in playlist mode" >> $TEMP_LOG
		else
		    echo "Skip command [$cmd] in playlist mode" | tee -a $TEMP_LOG
		fi
		continue
	    fi
	fi

	cmd_fail=0	    

	grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
	if [ $? -eq 0 ]; then
	    eos=1
	    break
	fi

	if [ $TRY_REMAIN_CMD -eq 1 ]; then
	    # check if we can continue next command
	    if [ $pause_fail -eq 1 ] || [ $stop_fail -eq 1 ] || [ $play_fail -eq 1 ] || [ $exit_fail -eq 1 ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Can't continue remaining commands" >> $TEMP_LOG
		else
		    echo "Can't continue remaining commands" | tee -a $TEMP_LOG
		fi
		break
	    fi

	    if [ $fseek_fail -eq 1 ] && [ "${cmd:0:3}" = "e 0" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip remaining command [$cmd]" >> $TEMP_LOG
		else
		    echo "Skip remaining command [$cmd]" | tee -a $TEMP_LOG
		fi
		continue
            fi

	    if [ $aseek_fail -eq 1 ] && [ "${cmd:0:3}" = "e 1" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip remaining command [$cmd]" >> $TEMP_LOG
		else
		    echo "Skip remaining command [$cmd]" | tee -a $TEMP_LOG
		fi
		continue
	    fi

	    cmd_p=${cmd:0:1}
	    if [ $trick_fail -eq 1 ] && [ "$cmd_p" = "c" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip remaining command [$cmd]" >> $TEMP_LOG
		else
		    echo "Skip remaining command [$cmd]" | tee -a $TEMP_LOG
		fi
		continue
	    fi

	    if [ $rotate_fail -eq 1 ] && [ "$cmd_p" = "t" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip remaining command [$cmd]" >> $TEMP_LOG
		else
		    echo "Skip remaining command [$cmd]" | tee -a $TEMP_LOG
		fi
		continue
	    fi
	    
	    if [ $resize_fail -eq 1 ] && [ "$cmd_p" = "z" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip remaining command [$cmd]" >> $TEMP_LOG
		else
		    echo "Skip remaining command [$cmd]" | tee -a $TEMP_LOG
		fi
		continue
	    fi

	    if [ $crop_fail -eq 1 ] && [ "$cmd_p" = "k" ]; then
		if [ $SHOW_CON_LOG -eq 0 ]; then
		    echo "Skip remaining command [$cmd]" >> $TEMP_LOG
		else
		    echo "Skip remaining command [$cmd]" | tee -a $TEMP_LOG
		fi
		continue
	    fi
	fi

        # execute the command
	if [ $SHOW_CON_LOG -eq 0 ]; then
	    echo -e "\n>>>>> Do Command [$cmd]\n" >> $TEMP_LOG
	else
	    echo -e "\n>>>>> Do Command [$cmd]\n" | tee -a $TEMP_LOG
	fi

	# trick the accurate seek command, convert the proportion to absulute seconds
	if [ "${cmd:0:3}" = "e 1" ] && [ "${cmd:4:1}" != "t" ]; then
	    seek_sec="${cmd:4:2}"
	    seek_sec=`expr $DURATION \* $seek_sec`
	    seek_sec=`expr $seek_sec / 100`
	    cmd="e 1 t$seek_sec"
	fi

	if [ $CPU_MEM_STAT -eq 1 ]; then
	    update_cpu_mem_usage
	fi

	# check if gplay still running
	GP_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
	if [ -z "$GP_INFO" ]; then
	    eos=1
	    break
	fi

	:> $TEMP_LOG_PIPE
	echo "$cmd" >> $TEMP_CMD_PIPE
	sleep $CMD_WAIT

	if [ $CPU_MEM_STAT -eq 1 ]; then
	    update_cpu_mem_usage
	fi

        # check the output of the command
	err_info=`egrep -h -i ' fail| error|CRITICAL|Segment|time out|Floating point exception|Aborted' $TEMP_LOG`
	if [ $? -eq 0 ] && [ -n "$err_info" ]; then
	    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
	    if [ $? -eq 0 ]; then
		echo "$err_info" | grep -v "failed" >/dev/null
		if [ $? -ne 0 ]; then
		    eos=1
		    break
		fi
	    fi

	    err_info=`echo -e "$err_info" | sed ':a ; N;s/\n/ | / ; t a ; ' | sed 's/\t/ /g' | sed -r 's/\x1B\[[0-9;]*[JKmsu]//g'`
	    # or use err_info=`echo "$err_info" | xargs`
		
	    reason=""

	    echo "$err_info" | grep -i "Segmentation fault" >/dev/null
	    if [ $? -eq 0 ]; then
                reason="Segmentation fault : "
		critical_fail=1
	    fi
	    
	    echo "$err_info" | grep "Aborted" >/dev/null
	    if [ $? -eq 0 ]; then
		reason="Aborted : "
		critical_fail=1
	    fi

	    echo "$err_info" | grep -i "Floating point exception" >/dev/null
	    if [ $? -eq 0 ]; then
                reason="Floating point exception : "
		critical_fail=1
	    fi
	    
	    echo "$err_info" | grep -i "CRITICAL" >/dev/null
	    if [ $? -eq 0 ]; then
		reason="CRITICAL : "
		critical_fail=1
	    fi
	    
	    out_line="${line}\t[$cmd] failed\t$reason${err_info}"
	    if [ $SHOW_CON_LOG -eq 0 ]; then
		echo -e "$out_line" >> $TEMP_LOG
	    else
		echo -e "$out_line" | tee -a $TEMP_LOG
	    fi
	    
	    check_ignore "$out_line" "$FILTER_LIST"
	    if [ $? -eq 0 ]; then
		echo -e "$out_line" >> $RESULT_FILE
	    else
		echo -e "$out_line" >> $IGNORE_FILE
	    fi

	    any_cmd_fail=1
	    if [ "$TEST_MODE" = "single" ]; then
		killall -9 $GPLAY > /dev/null 2>&1
	    else
		usleep $USLEEP_500_MS
	    fi
	    
	    if [ $TRY_REMAIN_CMD -eq 1 ]; then
		case "${cmd:0:1}" in
		    s) stop_fail=1;;
		    a) pause_fail=1;;
		    p) play_fail=1;;
		    c) trick_fail=1;;
		    t) rotate_fail=1;;
		    z) resize_fail=1;;
		    k) crop_fail=1;;
		    x) exit_fail=1;;
		    e) 
			if [ "${cmd:2:1}" = "0" ]; then
			    fseek_fail=1
			else
			    aseek_fail=1
			fi
		        ;;
		    *) ;;
		esac
		
		if [ $critical_fail -eq 1 ] || [ $play_fail -eq 1 ] || [ $stop_fail -eq 1 ] || [ $pause_fail -eq 1 ] || [ $exit_fail -eq 1 ]; then
		    break
                else
      		        # check if gplay exit
		    grep -E "fsl_player_deinit|player_exit" $TEMP_LOG >/dev/null
		    if [ $? -eq 0 ]; then
			break
		    else
		        # try to restart the play for following commands
			echo "s" >> $TEMP_CMD_PIPE
			sleep $CMD_WAIT
			echo "p" >> $TEMP_CMD_PIPE
			check_state "Playing" $CMD_PLAY_TIMEOUT
			ret=$?
			if [ $ret -eq 0 ]; then
			    cat $TEMP_LOG >> $LOG_FILE
			    :> $TEMP_LOG
			    continue
			else
			    break
			fi
		    fi
		fi
	    else
		break
	    fi
	fi
        
	grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
	if [ $? -eq 0 ]; then
	    eos=1
	    break
	fi

	# check if gplay still running
	GP_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
	if [ -z "$GP_INFO" ]; then
	    eos=1
	    break
	fi

	case "${cmd:0:1}" in
	    # Check Stop result
	    s)  check_state "Stopped" $CMD_STOP_TIMEOUT
		ret=$?
		if [ $ret -eq 3 ]; then
		    eos=1
		    break
		fi

		if [ $ret -eq 1 ]; then
		    err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
		    if [ -z "$err_info" ]; then
			err_info="Stop timeout $CMD_STOP_TIMEOUT"
		    fi
		    cmd_fail=1
		    stop_fail=1
		else
		    check_position $POSITION_CHECK_INTERVAL_US
		    ret=$?
		    if [ $ret -eq 3 ]; then
			eos=1
			break
		    fi

		    if [ $ret -eq 1 ] || [ $ret -eq 2 ] || [ $ret -eq 4 ]; then
			err_info="stop "${pos_info}
			cmd_fail=1
			stop_fail=1
		    fi
		fi
		;;
	    # Check Play result
	    p) check_state "Playing" $CMD_PLAY_TIMEOUT
		ret=$?
		if [ $ret -eq 3 ]; then
		    eos=1
		    break
		fi

		if [ $ret -eq 1 ]; then
		    err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
		    if [ -z "$err_info" ]; then
			err_info="Play timeout $CMD_PLAY_TIMEOUT"
		    fi
		    cmd_fail=1
		    play_fail=1
		else
		    check_position $POSITION_CHECK_INTERVAL_US
		    ret=$?
		    if [ $ret -eq 3 ]; then
			eos=1
			break
		    fi

		    if [ $ret -eq 0 ] || [ $ret -eq 2 ] || [ $ret -eq 4 ]; then
			err_info="play "${pos_info}
			cmd_fail=1
			play_fail=1
		    fi
		fi
		;;
	    # Check Pause result
	    a)  if [ "$paused" = "false" ]; then
		    check_state "Paused" $CMD_PAUSE_TIMEOUT
	        else
		    check_state "Playing" $CMD_PAUSE_TIMEOUT
		fi

		ret=$?
		if [ $ret -eq 3 ]; then
		    eos=1
		    break
		fi

		if [ $ret -eq 1 ]; then
		    err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
		    if [ -z "$err_info" ]; then
			err_info="pause timeout $CMD_PLAY_TIMEOUT"
		    fi
		    cmd_fail=1
		    pause_fail=1
		else
		    check_position $POSITION_CHECK_INTERVAL_US
		    ret=$?
		    if [ $ret -eq 3 ]; then
			eos=1
			break
		    fi

		    if [ "$paused" = "false" ]; then
			if [ $ret -eq 1 ] || [ $ret -eq 2 ] || [ $ret -eq 4 ]; then
			    err_info="pause on "${pos_info}
			    cmd_fail=1
			    pause_fail=1
			fi
			paused=true;
		    else
			if [ $ret -eq 0 ] || [ $ret -eq 2 ] || [ $ret -eq 4 ]; then
			    err_info="pause off "${pos_info}
			    cmd_fail=1
			    pause_fail=1
			fi
			paused=false;
		    fi
		fi
		;;
	    # Check Video display area
	    z)  :> $TEMP_LOG_PIPE
		echo "q z" >> $TEMP_CMD_PIPE
		usleep $QUERY_WAIT_US

		counter=0
		eos=0
		while [ 1 ]
		do
		    video_size=(`grep -i "display area :" $TEMP_LOG_PIPE | cut -d: -f2`)

		    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
		    if [ $? -eq 0 ]; then
			eos=1
			break
		    fi
		    
		    if [ -z "$video_size" ]; then
			counter=`expr $counter + 1`
			if [ $counter -ge 30 ]; then
			    err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
			    if [ -z "$err_info" ]; then
				err_info="can not get video size info"
			    fi
			    cmd_fail=1
			    resize_fail=1
			    break
			else
			    usleep $QUERY_WAIT_US
			fi
		    else
			break
		    fi
		done

		if [ $eos -eq 1 ]; then
		    break
		fi

		if [ $cmd_fail -eq 0 ]; then
		    x=${video_size[0]}
		    y=${video_size[1]}
		    w=${video_size[2]}
		    h=${video_size[3]}
		    
		    cmd_size=($cmd)
		    ox=${cmd_size[1]}
		    oy=${cmd_size[2]}
		    ow=${cmd_size[3]}
		    oh=${cmd_size[4]}
		    
		    if [ $x -ne $ox ] || [ $y -ne $oy ] || [ $w -ne $ow ] || [ $h -ne $oh ]; then
			err_info="video size required [$ox $oy $ow $oh] but actual is [$x $y $w $h]"
			cmd_fail=1
			resize_fail=1
		    fi
		fi
		;;
	    # Check Video crop 
	    k) 	:> $TEMP_LOG_PIPE
		echo "q k" >> $TEMP_CMD_PIPE
		usleep $QUERY_WAIT_US

		counter=0
		eos=0
		while [ 1 ]
		do
		    crop_size=(`grep -i "video crop :" $TEMP_LOG_PIPE | cut -d: -f2`)

		    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
		    if [ $? -eq 0 ]; then
			eos=1
			break
		    fi

		    if [ -z "$crop_size" ]; then
			counter=`expr $counter + 1`
			if [ $counter -ge 30 ]; then
			    err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
			    if [ -z "$err_info" ]; then
				err_info="can not get crop info"
			    fi
			    cmd_fail=1
			    crop_fail=1
			    break
			else
			    usleep $QUERY_WAIT_US
			fi
		    else
			break
		    fi
		done

		if [ $eos -eq 1 ]; then
		    break
		fi

		if [ $cmd_fail -eq 0 ]; then
		    l=${crop_size[0]}
		    r=${crop_size[1]}
		    t=${crop_size[2]}
		    b=${crop_size[3]}
		    
		    cmd_size=($cmd)
		    ol=${cmd_size[1]}
		    or=${cmd_size[2]}
		    ot=${cmd_size[3]}
		    ob=${cmd_size[4]}
		# driver will round32 of left and top and round8 of right, perform same rounding
		    ol_r=`expr $ol % 32`
		    if [ $ol_r -gt 0 ]; then
			ol_r=`expr 32 - $ol_r`
		    fi
		    ol=`expr $ol + $ol_r`
		    
		    ot_r=`expr $ot % 32`
		    if [ $ot_r -gt 0 ]; then
			ot_r=`expr 32 - $ot_r`
		    fi
		    ot=`expr $ot + $ot_r`
		    
		    or_r=`expr $or % 8`
		    if [ $or_r -gt 0 ]; then
			or_r=`expr 8 - $or_r`
		    fi
		    or=`expr $or + $or_r`
		    
		    if [ $l -ne $ol ] || [ $r -ne $or ] || [ $t -ne $ot ] || [ $b -ne $ob ]; then
			err_info="crop required [$ol $or $ot $ob] but actual is [$l $r $t $b]"
			cmd_fail=1
			crop_fail=1
		    fi
		fi
		;;
	    # Check Video rotation result
	    t) 	:> $TEMP_LOG_PIPE
		echo "q t" >> $TEMP_CMD_PIPE
		usleep $QUERY_WAIT_US
		
		counter=0
		eos=0
		while [ 1 ]
		do
		    rotation=`grep -i "rotation :" $TEMP_LOG_PIPE | cut -d: -f2`
		    rotation=`echo $rotation`
		
		    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
		    if [ $? -eq 0 ]; then
			eos=1
			break
		    fi

		    if [ -z "$rotation" ]; then
			counter=`expr $counter + 1`
			if [ $counter -ge 30 ]; then
			    err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
			    if [ -z "$err_info" ]; then
				err_info="can not get rotation info"		
			    fi
			    cmd_fail=1
			    rotate_fail=1
			    break
			else
			    usleep $QUERY_WAIT_US
			fi
		    else
			break
		    fi
		done

		if [ $eos -eq 1 ]; then
		    break
		fi

		if [ $cmd_fail -eq 0 ]; then
		    cmd_rotate=${cmd:2}
		    
		    if [ "$rotation" -ne "$cmd_rotate" ]; then
			err_info="rotation required $cmd_rotate but actual is $rotation"
			cmd_fail=1
			rotate_fail=1
		    fi
		fi
		;;
	    # Check Video play rate result
	    c)  :> $TEMP_LOG_PIPE
		echo "q c" >> $TEMP_CMD_PIPE
		usleep $QUERY_WAIT_US

		counter=0
		eos=0
		while [ 1 ]
		do
		    speed=`grep -i "play rate :" $TEMP_LOG_PIPE | cut -d: -f2`
		    speed=`echo $speed`

		    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
		    if [ $? -eq 0 ]; then
			eos=1
			break
		    fi

		    GP_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
		    if [ -z "$GP_INFO" ]; then
			eos=1
			break
		    fi
			
		    if [ -z "$speed" ]; then
			counter=`expr $counter + 1`
			if [ $counter -ge 30 ]; then
			    err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
			    if [ -z "$err_info" ]; then
				err_info="can not get play rate info"
			    fi
			    cmd_fail=1
			    trick_fail=1
			    break
			else
			    usleep $QUERY_WAIT_US
			fi
		    else
			break
		    fi
	        done 
		
		if [ $eos -eq 1 ]; then
		    break
		fi

		if [ $cmd_fail -eq 0 ]; then
	            # trim
		    speed=`echo $speed`
		    cmd_speed=${cmd:2}
	            # remove .0 at the end
		    speed=${speed%.0}
		    cmd_speed=${cmd_speed%.0}
		    
		    if [ "$speed" != "$cmd_speed" ]; then
			err_info="speed required $cmd_speed but actual is $speed"
       			cmd_fail=1
			trick_fail=1
		    else
			# if rewind, the position check interval is 10 seconds
		        # if play rate is [0.5, 2], then position check interval is 2 seconds
		        # if play rate is (2, 8], then position check interval is 5 seconds
		        # remove minus prefix -
			speed=${cmd_speed#-}
			minus=true
			if [ "$speed" = "$cmd_speed" ]; then
			    minus=false
			fi
			
			integer_part=${speed%.*}
			timeout=5
			if [ $integer_part -lt 2 ]; then
			    timeout=2
			fi
			
			if [ $integer_part -eq 2 ] && [ "$speed" = "$integer_part" ]; then
			    timeout=2
			fi
			
			if [ "$minus" = "true" ]; then
			    timeout=10
			fi

			counter=0
			eos=0
			while [ 1 ]
			do 
			    check_position $POSITION_CHECK_INTERVAL_US
			    
			    ret=$?
			    if [ $ret -eq 3 ]; then
				eos=1
				break
			    elif [ $ret -eq 1 ] && [ "$minus" = "false" ]; then
				break
			    elif [ $ret -eq 2 ] && [ "$minus" = "true" ]; then
				break
			    elif [ $ret -eq 5 ]; then
				break
			    fi
			    
			    counter=`expr $counter + 1`
			    if [ $counter -ge $timeout ]; then
				err_info="trick play "${pos_info}
				cmd_fail=1
				trick_fail=1
				break
			    fi
			done
			
			if [ $eos -eq 1 ]; then
			    break
			fi
		    fi
		fi
		;;
	    # Check Seek result
	    e)  :> $TEMP_LOG_PIPE
		p_cmd=($cmd)
		seek_mode=${p_cmd[1]}
		seek_pos=${p_cmd[2]}
		if [ $seek_mode -eq 1 ] && [ "${seek_pos:0:1}" = "t" ]; then
		    seek_pos="${seek_pos:1}"
		else
		    seek_pos=`expr $DURATION \* $seek_pos`
		    seek_pos=`expr $seek_pos / 100`
		fi
		
		echo "q p" >> $TEMP_CMD_PIPE
		usleep $QUERY_WAIT_US

		counter=0
		eos=0
		while [ 1 ]
		do
		    position=`grep -i "playing position :" $TEMP_LOG_PIPE | cut -d: -f2`
		    position=`echo $position`

		    grep -E "EOS Found|FSL_PLAYER_UI_MSG_EXIT" $TEMP_LOG > /dev/null
		    if [ $? -eq 0 ]; then
			eos=1
			break
		    fi

		    GP_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
		    if [ -z "$GP_INFO" ]; then
			eos=1
			break
		    fi

		    if [ $counter -ge 50 ]; then
			err_info=`grep -iE "error|failed|fault|Floating point exception|CRITICAL|Aborted" $TEMP_LOG`
			if [ -z "$err_info" ]; then
			    err_info="can not get postion after seek, position=$position, duration=$DURATION"
			fi
			cmd_fail=1
			if [ $seek_mode -eq 1 ]; then
			    aseek_fail=1
			else
			    fseek_fail=1
			fi
			break
		    fi
		    
		    if [ -z "$position" ]; then
			counter=`expr $counter + 1`
			usleep $QUERY_WAIT_US
		    elif [ $position -eq 0 ] && [ $seek_pos -gt 0 ]; then
			counter=`expr $counter + 2`
			:> $TEMP_LOG_PIPE
			echo "q p" >> $TEMP_CMD_PIPE
			usleep $QUERY_WAIT_US
		    else
			break
		    fi
		done

		if [ $eos -eq 1 ]; then
		    break
		fi

		if [ $cmd_fail -eq 0 ]; then
		    timeout=2
		    position=`expr $position / 1000000000`
		    
                    # substract the $CMD_WAIT after the seek command
		    wait_val=`expr $CMD_WAIT`
		    if [ $position -ge $wait_val ]; then
			position=`expr $position - $wait_val`
		    fi
		    
		    if [ $seek_mode -eq 0 ]; then
			pos_tol=`expr $position - $SEEK_CHECK_TOLERANCE`
			if [ $pos_tol -gt $seek_pos ]; then
			    err_info="fast seek required ${seek_pos}s but actual is ${position}s, (tolerance=${SEEK_CHECK_TOLERANCE}s)"
			    cmd_fail=1
			    fseek_fail=1
			fi
		    else
			timeout=5
			if [ $position -gt $seek_pos ]; then
			    diff=`expr $position - $seek_pos`
			    if [ $diff -gt $SEEK_CHECK_TOLERANCE ]; then
				err_info="accurate seek required ${seek_pos}s but actual is ${position}s, (tolerance=${SEEK_CHECK_TOLERANCE}s)"
				cmd_fail=1
				aseek_fail=1
			    fi
			elif [ $position -lt $seek_pos ]; then
			    diff=`expr $seek_pos - $position`
			    if [ $diff -gt $SEEK_CHECK_TOLERANCE ]; then
				err_info="accurate seek required ${seek_pos}s but actual is ${position}s, (tolerance=${SEEK_CHECK_TOLERANCE}s)"
				cmd_fail=1
				aseek_fail=1
			    fi
			fi
		    fi
		    
          	    # further check the postion
		    if [ $cmd_fail -eq 0 ]; then
			counter=0
			eos=0
			while [ 1 ]
			do
			    check_position $POSITION_CHECK_INTERVAL_US
			    ret=$?
			    if [ $ret -eq 3 ]; then
				eos=1
				break
			    elif [ $ret -eq 2 ] || [ $ret -eq 4 ]; then
				err_info="after seek, "${pos_info}
				cmd_fail=1
				if [ $seek_mode -eq 1 ]; then
				    aseek_fail=1
				else
				    fseek_fail=1
				fi
				break
			    elif [ $ret -eq 0 ] || [ $ret -eq 5 ]; then
				counter=`expr $counter + 1`
				if [ $counter -ge $timeout ]; then
				    err_info="after seek, "${pos_info}
				    cmd_fail=1
				    if [ $seek_mode -eq 1 ]; then
					aseek_fail=1
				    else
					fseek_fail=1
				    fi
				    break
				fi
			    else
				break
			    fi
			done

			if [ $eos -eq 1 ]; then
			    break
			fi
		    fi
		fi
		;;
	    x)  counter=0
		while [ 1 ]
		do
		    grep "fsl_player_deinit" $TEMP_LOG > /dev/null
		    if [ $? -eq 0 ]; then
			break
		    fi

	            # check if gplay still running
		    GP_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
		    if [ -z "$GP_INFO" ]; then
			break
		    fi

		    counter=`expr $counter + 1`
		    if [ $counter -ge $CMD_EXIT_WAIT ]; then
			any_cmd_fail=1
			exit_fail=1
			killall -9 $GPLAY > /dev/null 2>&1
			out_line="${line}\t[$cmd] failed\tExit timeout, timeout is `expr $CMD_EXIT_WAIT \* $CMD_WAIT` seconds"
			if [ $SHOW_CON_LOG -eq 0 ]; then
			    echo "exit command timeout, force killed $GPLAY" >> $TEMP_LOG
			    echo -e "$out_line" >> $TEMP_LOG
			else
			    echo "exit command timeout, force killed $GPLAY" | tee -a $TEMP_LOG
			    echo -e "$out_line" | tee -a $TEMP_LOG
			fi

			check_ignore "$out_line" "$FILTER_LIST"
			if [ $? -eq 0 ]; then
			    echo -e "$out_line" >> $RESULT_FILE
			else
			    echo -e "$out_line" >> $IGNORE_FILE
			fi

			break
		    else
			sleep $CMD_WAIT
		    fi
		done
		break
		;;
	    *) 
		echo "Unknown command [$cmd]" | tee -a $TEMP_LOG
		;;
	esac

	if [ $cmd_fail -ne 0 ]; then
	    if [ "$TEST_MODE" = "single" ]; then
		echo "x" >> $TEMP_CMD_PIPE
		counter=0
		while [ 1 ]
		do
		    grep "fsl_player_deinit" $TEMP_LOG > /dev/null
		    if [ $? -eq 0 ]; then
		    	break
		    fi

		    GP_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
		    if [ -z "$GP_INFO" ]; then
			break
		    fi

		    counter=`expr $counter + 1`
		    if [ $counter -ge $CMD_EXIT_WAIT ]; then
		    	killall -9 $GPLAY > /dev/null 2>&1
		    	if [ $SHOW_CON_LOG -eq 0 ]; then
			    echo "exit timeout $CMD_EXIT_WAIT, force killed $GPLAY" >> $TEMP_LOG
		    	else
			    echo "exit timeout $CMD_EXIT_WAIT, force killed $GPLAY" | tee -a $TEMP_LOG
		    	fi
		    	break
	            else
		    	sleep $CMD_WAIT
		    fi
		done
	    fi

	    err_info=`echo -e "$err_info" | sed ':a ; N;s/\n/ | / ; t a ; ' | sed 's/\t/ /g' | sed -r 's/\x1B\[[0-9;]*[JKmsu]//g'`

	    reason=""

	    echo "$err_info" | grep -i "Segmentation fault" >/dev/null
	    if [ $? -eq 0 ]; then
                reason="Segmentation fault : "
		critical_fail=1
            fi

	    echo "$err_info" | grep "Aborted" >/dev/null
	    if [ $? -eq 0 ]; then
		reason="Aborted : "
		critical_fail=1
	    fi

	    echo "$err_info" | grep -i "Floating point exception" >/dev/null
	    if [ $? -eq 0 ]; then
                reason="Floating point exception : "
		critical_fail=1
            fi

	    echo "$err_info" | grep -i "CRITICAL" >/dev/null
	    if [ $? -eq 0 ]; then
		reason="CRITICAL : "
		critical_fail=1
	    fi

	    out_line="${line}\t[$cmd] failed\t$reason${err_info}"
	    if [ $SHOW_CON_LOG -eq 0 ]; then
		echo -e "$out_line" >> $TEMP_LOG
	    else
		echo -e "$out_line" | tee -a $TEMP_LOG
	    fi

	    check_ignore "$out_line" "$FILTER_LIST"
	    if [ $? -eq 0 ]; then
		echo -e "$out_line" >> $RESULT_FILE
	    else
		echo -e "$out_line" >> $IGNORE_FILE
	    fi

	    any_cmd_fail=1
	    if [ $TRY_REMAIN_CMD -eq 1 ]; then
		if [ $critical_fail -eq 1 ] || [ $play_fail -eq 1 ] || [ $stop_fail -eq 1 ] || [ $pause_fail -eq 1 ] || [ $exit_fail -eq 1 ]; then
		    if [ $SHOW_CON_LOG -eq 0 ]; then
			echo "Can't continue remaining commands" >> $TEMP_LOG
		    else
			echo "Can't continue remaining commands" | tee -a $TEMP_LOG
		    fi

		    break
		else
		    # check if gplay exit
		    grep "fsl_player_deinit|player_exit" $TEMP_LOG >/dev/null
		    if [ $? -eq 0 ]; then
			break
		    else
		        # try to restart the play for following commands
			echo "s" >> $TEMP_CMD_PIPE
			sleep $CMD_WAIT
			echo "p" >> $TEMP_CMD_PIPE
			check_state "Playing" $CMD_PLAY_TIMEOUT
			ret=$?
			if [ $ret -eq 0 ]; then
			    cat $TEMP_LOG >> $LOG_FILE
			    :> $TEMP_LOG
			    continue
			else
			    break
			fi
		    fi
		fi
	    else
		break
	    fi
	fi	
    done < $CMD_FILE
    
    if [ $any_cmd_fail -eq 0 ]; then
	pass=$(($pass+1))
	if [ $LOG_ERR_ONLY -eq 0 ]; then
	    cat $TEMP_LOG >> $LOG_FILE
	fi
	
	if [ $eos -eq 1 ]; then
	    echo ">>>>> EOS <<<<<" >> $LOG_FILE
	fi

	if [ $SHOW_CON_LOG -eq 0 ]; then
		echo -e "$line\tOK" >> $LOG_FILE
	else
		echo -e "$line\tOK" | tee -a $LOG_FILE
	fi
    else
	check_ignore "$out_line" "$FILTER_LIST"
	if [ $? -eq 0 ]; then
	    fail=$(($fail+1))
	else
	    filtered=$(($filtered+1))
	fi

	cat $TEMP_LOG >> $LOG_FILE
	if [ $eos -eq 1 ]; then
	    echo ">>>>> EOS <<<<<" >> $LOG_FILE
	fi
    fi

    if [ $CPU_MEM_STAT -eq 1 ]; then
	update_cpu_mem_usage
	echo -e "${line}\t`awk 'BEGIN{printf "%.1f",'"$cpu_usage"'/10}'`\t$mem_usage" >> $CPU_MEM_USAGE
    fi

done < $TEMP_FILE_LIST

if [ "$TEST_MODE" = "playlist" ]; then
    echo "x" >> $TEMP_CMD_PIPE
    counter=0
    while [ 1 ]
    do
	grep "fsl_player_deinit" $TEMP_LOG > /dev/null
	if [ $? -eq 0 ]; then
	    break
	fi

	# check if gplay still running
	GP_INFO=`ps $PS_OPT | grep -F "$GPLAY" | grep -vF "$BIN" | grep -v "grep"`
	if [ -z "$GP_INFO" ]; then
	    break
	fi

	counter=`expr $counter + 1`
	if [ $counter -ge $CMD_EXIT_WAIT ]; then
	    killall -9 $GPLAY > /dev/null 2>&1
	    if [ $SHOW_CON_LOG -eq 0 ]; then
		echo "playlist test mode exit timeout $CMD_EXIT_WAIT, force killed $GPLAY" >> $LOG_FILE
	    else
		echo "playlist test mode exit timeout $CMD_EXIT_WAIT, force killed $GPLAY" | tee -a $LOG_FILE
	    fi
	    break
	else
	    sleep $CMD_WAIT
	fi
    done
fi

rm $TEMP_CMD_PIPE -f
rm $TEMP_LOG_PIPE -f 
rm $TEMP_LOG -f
rm -f $BIN
if [ -f $DEFAULT_CMDS ]; then
    rm -f $DEFAULT_CMDS
fi

echo -e "\nTotal $line_cnt files tested, Pass : $pass, Failed : $fail, Ignored Failed: $filtered" | tee -a $LOG_FILE

if [ $CPU_MEM_STAT -eq 1 ]; then
    head -1 $CPU_MEM_USAGE > ${CPU_MEM_USAGE}.xls
    sed 1d $CPU_MEM_USAGE | sort -t$'\t' -k2 -nr >> ${CPU_MEM_USAGE}.xls
    chmod 777 ${CPU_MEM_USAGE}.xls
    rm $CPU_MEM_USAGE
fi

#if [ -n "$FILTER_LIST" ]; then
#    if [ $SHOW_CON_LOG -eq 0 ]; then
#	if [ -n "$PREFIX" ]; then
#	    $FILTER_SCRIPT -p $PREFIX $RESULT_FILE "${FILTER_LIST}" | tee -a $LOG_FILE
#	else
#	    $FILTER_SCRIPT $RESULT_FILE "${FILTER_LIST}" | tee -a $LOG_FILE
#	fi
#    else
#	if [ -n "$PREFIX" ]; then
#	    $FILTER_SCRIPT -p $PREFIX -v $RESULT_FILE "${FILTER_LIST}" | tee -a $LOG_FILE
#	else
#	    $FILTER_SCRIPT -v $RESULT_FILE "${FILTER_LIST}" | tee -a $LOG_FILE
#	fi
#    fi
#else
    cut -f1 $RESULT_FILE > ${RESULT_FILE%.*}.list
    sort -t$'\t' -k2 $RESULT_FILE > ${RESULT_FILE}.tmp
    mv ${RESULT_FILE}.tmp $RESULT_FILE
    chmod 777 $RESULT_FILE ${RESULT_FILE%.*}.list
    echo "Failed files report : $RESULT_FILE"
    echo "file ${RESULT_FILE%.*}.list generated for re-check. (use -l option)"
#fi

echo "Log file getnerated : $LOG_FILE"
echo ""
END_TIME=`date +%s`
DUR=$(( $END_TIME - $START_TIME ))
hour=`expr $DUR / 3600`
min=`expr $DUR % 3600`
min=`expr $min / 60`
sec=`expr $DUR % 60`
echo "Test finished @ [`date`], Spent [$hour:$min:$sec]" | tee -a $LOG_FILE
echo ""

# send email after testing done
# TODO: login to 10.192.241.72 and use sendmail to send out the mail
#       how to set sendmail to send external mail?
