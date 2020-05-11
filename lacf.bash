#!/bin/bash

FILETYPE=`file -i -h -p "$1" | awk -F";" '{print $1}' | awk -F":" 'BEGIN { FPAT = "([^ ]+)|(\"[^\"]+\")" }{print $2}' | sed -e 's/^ *//g;s/ *$//g'`

# detect and replace application/octet-stream values with something informative
if [ "$FILETYPE" == "application/octet-stream" ]; then
	FILETYPE=`file -h -p "$1" | awk -F":" '{print $2}' | awk '{print $1"_"$2}' | sed 's:_*$::'`
fi

echo $FILETYPE
