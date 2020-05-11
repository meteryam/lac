#!/bin/bash
IFS=$'\n'

# this script will remove commas, semicolons and single quotes from filenames

INCLUDES=`grep ^include files.txt | awk '{ $1 = ""; print $0 }' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'`
#INCLUDES='/mnt/usb/jessica'

#echo -e "$INCLUDES"

# clean up directories

EXCLUDED_FILES=""
for i in `echo -e "$INCLUDES"`; do
	ls "$i" &>/dev/null
	FINDFILES=`find "$i" -type d | egrep ",|;|'"`
	if [ "$EXCLUDED_FILES" ]; then
		EXCLUDED_FILES=`echo -e "$EXCLUDED_FILES""\n""$FINDFILES"`
	else
		EXCLUDED_FILES=$FINDFILES
	fi
done

#echo -e "$EXCLUDED_FILES" | sed "s/'//g" | sed 's/,//g' | sed 's/;//g' | egrep ",|;|'"

for i in `echo -e "$EXCLUDED_FILES" | sort -u`; do
	newi=`echo "$i" | sed "s/'//g" | sed 's/,//g' | sed 's/;//g'`
	#echo mv "$i" "$newi"
	mv -v "$i" "$newi" 2>&1
	#exit
done

#exit

# clean up files

EXCLUDED_FILES=""
FINDFILES=""
for i in `echo -e "$INCLUDES"`; do
        ls "$i" &>/dev/null
        FINDFILES=`find "$i" -type f | egrep ",|;|'"`
        if [ "$EXCLUDED_FILES" ]; then
                EXCLUDED_FILES=`echo -e "$EXCLUDED_FILES""\n""$FINDFILES"`
        else
                EXCLUDED_FILES=$FINDFILES
        fi
done

#echo -e "$EXCLUDED_FILES" | sed "s/'//g" | sed 's/,//g' | sed 's/;//g' | egrep ",|;|'"

for i in `echo -e "$EXCLUDED_FILES" | sort -u`; do
        newi=`echo "$i" | sed "s/'//g" | sed 's/,//g' | sed 's/;//g'`
        #echo mv "$i" "$newi"
        mv -v "$i" "$newi" 2>&1
        #exit
done
