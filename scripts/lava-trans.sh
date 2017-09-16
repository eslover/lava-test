#!/bin/bash

if [ -z $1 ]
then
	echo "please specify source file!"
	exit 1
fi

if [ -z $2 ]
then
	echo "please specify target file!" 
	exit 2
fi

if [ -f $2 ]
then
	echo file $2 is existing, will try to remove it?
	rm -i $2
fi

echo "try to transform $1 to $2 with lava yaml format"

while read CMD; do
	x=`echo "$CMD" | cut -d ' ' -f 1`
	y=`echo "$CMD" | cut -d ' ' -f 2-`
	z=`echo $y | rev`
	# if dos format
	# p=`echo $z | cut -c 2- | rev`
	# else by default, Linux format
	p=`echo $z | cut -c 1- | rev`
	p=`echo ${p}  | sed "s/'/'\"'\"'/g"`

	echo '       ' - lava-test-case ${x}  --shell ./scripts/lava-vte.sh \'${p}\' >> $2 
done < "$1"

