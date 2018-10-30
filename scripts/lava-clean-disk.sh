#!/bin/bash

LIMIT='88'

while [ 1 ]
do

	USED=`df -h / | grep \/ | xargs echo | cut -d ' ' -f 5 | cut -d % -f 1`

	if [ $USED -gt $LIMIT ]
	then
		ls -t -r -d /var/lib/lava/dispatcher/tmp/tmp* | head -2 | xargs sudo rm -rf
	else
		sleep 10
	fi
done
