#!/bin/bash
IFS=$'\n'

#SCRIPT=`realpath $0`
#SCRIPTPATH=`dirname $SCRIPT`
SCRIPTPATH='/Users/metermac/Documents/working/backup/bash'

RESTOREDATE=`date +"%Y%m%d.%H%M%S"`
RESTOREDATE=`echo "$RESTOREDATE"`

# load throttling setting
BANDWIDTH=`egrep ^bandwidth $SCRIPTPATH/config.txt | head -1 | awk '{print $2}'`

# load defaults
SOURCE=`grep ^backup_to $SCRIPTPATH/config.txt | head -1 | awk '{$1 = ""; print $0}' | sed -e 's/^ *//g;s/ *$//g'`
TARGET=`grep ^restore_to $SCRIPTPATH/config.txt | head -1 | awk '{$1 = ""; print $0}' | sed -e 's/^ *//g;s/ *$//g'`
BACKUPFOLDER=""

# break down arguments
	# -s for source
	# -t for target
	# -r for restore date

IFS=$' '
for MYFIELD in "$@"; do
	CHECKFIRST=`echo $MYFIELD | cut -c1`
	if [ "$CHECKFIRST" == "-" ]; then
		mode="flag"
	else
		mode="arg"
	fi
	
	if [ "$mode" == "flag" ]; then
		case $MYFIELD in
			-s)
				CURRENTFLAG="SOURCE"
				;;
			-t)
				CURRENTFLAG="TARGET"
				;;
			-b)
				CURRENTFLAG="BACKUPFOLDER"
				;;
		esac
	elif [ "$mode" == "arg" ]; then
		case $CURRENTFLAG in
			SOURCE)
				SOURCE="$MYFIELD"
				;;
			TARGET)
				TARGET="$MYFIELD"
				;;
			BACKUPFOLDER)
				BACKUPFOLDER="$MYFIELD"
				;;
		esac
	fi
done
IFS=$'\n'

echo
echo SOURCE: "$SOURCE"
echo TARGET: "$TARGET"
echo BACKUPFOLDER: "$BACKUPFOLDER"
echo

if [ "$BACKUPFOLDER" == "" ] || [ -z "$BACKUPFOLDER" ]; then
	echo "no BACKUPFOLDER specified. exiting."
	exit 1
fi


# if backup folder doesn't exist, check archive; if not found, throw error and halt

#echo "$SOURCE/$BACKUPFOLDER/"
#echo "$SOURCE/archive/$BACKUPFOLDER/"
CHECKFOLDER=`file "$SOURCE/$BACKUPFOLDER/" | grep directory$`

if [ "$CHECKFOLDER" == "" ]; then
	CHECKFOLDER=`file "$SOURCE/archive/$BACKUPFOLDER/" | grep directory$`
	if [ "$CHECKFOLDER" == "" ]; then
		echo requested folder "$BACKUPFOLDER" not found. exiting.
		exit
	fi
fi

# save the config and import/exclude info in the log file
mkdir -p /tmp/lac 2>/dev/null
echo SOURCE: "$SOURCE" > /tmp/lac/restore_"$RESTOREDATE".log
echo TARGET: "$TARGET" >> /tmp/lac/restore_"$RESTOREDATE".log
echo BACKUPFOLDER: "$BACKUPFOLDER" >> /tmp/lac/restore_"$RESTOREDATE".log
echo -e "\n" >> /tmp/lac/restore_"$RESTOREDATE".log
cat $SCRIPTPATH/config.txt >> /tmp/lac/restore_"$RESTOREDATE".log
echo -e "\n" >> /tmp/lac/restore_"$RESTOREDATE".log
cat $SCRIPTPATH/files.txt >> /tmp/lac/restore_"$RESTOREDATE".log
echo -e "\n" >> /tmp/lac/restore_"$RESTOREDATE".log

# load the index for the specified backup

INDEXFILELIST="$SOURCE/$BACKUPFOLDER/$BACKUPFOLDER.index.txt.gz"
#echo $INDEXFILELIST

# load any indices called by the files within those indices

mkdir -p /tmp/lac 2>/dev/null
rm /tmp/lac/* 2>/dev/null
cp "$INDEXFILELIST" /tmp/lac/
gunzip /tmp/lac/$BACKUPFOLDER.index.txt.gz 2>/dev/null
INDEXCONTENT=`cat /tmp/lac/$BACKUPFOLDER.index.txt`
ALLFILES=`echo -e "$INDEXCONTENT"`
rm /tmp/lac/* 2>/dev/null

echo -e "$ALLFILES"
#exit

# pull entries that have checksums

RESTOREFILES=""
#for ENTRY in `echo -e "$ALLFILES" | awk 'BEGIN  { FPAT = "([^ ]+)|(\"[^\"]+\")" } 2 !~ /./ { print $0}'`; do
for ENTRY in `echo -e "$ALLFILES" | awk -F"," '2 !~ /"/ { print $0}'`; do
	#NONDDFILE=`echo "$SOURCE"/$ENTRY | awk '{$1 = ""; $2 = ""; $3 = ""; $4 = ""; $5 = ""; print $0}' | sed 's/\/\//\//g'`
	NONDDFILE=`echo "$SOURCE"/$ENTRY | awk -F"," '{print $6}' | tr -d '"' | sed 's/\/\//\//g'`

	# check for compression
	#COMPRESSCHECK=`echo "$ENTRY" | awk '{print $3}'`
	COMPRESSCHECK=`echo "$ENTRY" | awk -F"," '{print $3}'`
	if [ "$COMPRESSCHECK" == "1" ]; then
		NONDDFILE=`echo "$NONDDFILE".gz`
	fi
	
	#file "$NONDDFILE"
	
	if [ "`file \"$NONDDFILE\" | grep such`" ]; then
		#echo skipping missing file: `echo $ENTRY | awk '{$1 = ""; $2 = ""; $3 = ""; $4 = ""; $5 = ""; print $0}' | sed 's/\/\//\//g'`
		echo skipping missing file: `echo $ENTRY | awk -F"," '{print $6}' | sed 's/\/\//\//g'`
	else
		RESTOREFILES=`echo -e "$RESTOREFILES""\n""$ENTRY"`
	fi
done

# pull deduped entries

#for ENTRY in `echo -e "$ALLFILES" | awk 'BEGIN  { FPAT = "([^ ]+)|(\"[^\"]+\")" } 2 ~ /./ { print $0}'`; do
for ENTRY in `echo -e "$ALLFILES" | awk -F"," '2 ~ /"/ { print $0}'`; do

	#echo ENTRY: "$ENTRY"
	#DEDUPENTRY0=`echo "$ENTRY" | awk -F"\"" '{print $2}' | tr -d '"' | sed 's/ /\\ /g'`
	DEDUPENTRY0=`echo "$ENTRY" | awk -F"," '{print $2}' | tr -d '"' | sed 's/ /\\ /g'`
	DEDUPENTRY=`echo "$SOURCE"/"$DEDUPENTRY0" | sed 's/\/\//\//g'`
	
	# if any are missing, check the archive indices
	ARCHIVEPATH=`echo "$SOURCE"/archive/"$DEDUPENTRY0" | sed 's/\/\//\//g'`
	#echo ARCHIVEPATH: "$ARCHIVEPATH"

	# check for compression
	#COMPRESSCHECK=`echo "$ENTRY" | awk 'BEGIN  { FPAT = "([^ ]+)|(\"[^\"]+\")" } 2 ~ /./ { print $3}'`
	COMPRESSCHECK=`echo "$ENTRY" | awk -F"," '2 ~ /./ { print $3}'`
	if [ "$COMPRESSCHECK" == "1" ]; then
		COMPRESSED="1"
		DEDUPENTRY=`echo "$DEDUPENTRY".gz`
		ARCHIVEPATH=`echo "$ARCHIVEPATH".gz`
	else
		COMPRESSED="0"
	fi
	
	CHECKPATH=`file "$DEDUPENTRY" | grep such`
	
	if [ "$CHECKPATH" ]; then
	
		CHECKPATH=`file "$ARCHIVEPATH" | grep such`
		
		#echo CHECKPATH "$CHECKPATH"
		
		if [ "$CHECKPATH" ]; then
			#echo skipping missing file: `echo $ENTRY | awk '{$1 = ""; $2 = ""; $3 = ""; $4 = ""; $5 = ""; print $0}'`
			echo skipping missing file: `echo $ENTRY | awk -F"," '{print $6}'`
		else
			# build new entry based on archive location
			#NEWENTRY=`echo "$ENTRY" | awk -v ARCHIVEPATH=$ARCHIVEPATH 'BEGIN  { FPAT = "([^ ]+)|(\"[^\"]+\")" } {$2=ARCHIVEPATH; print $0}'`
			NEWENTRY=`echo "$ENTRY" | awk -F"," -v ARCHIVEPATH=$ARCHIVEPATH '{$2=ARCHIVEPATH; print $0}'`
			RESTOREFILES=`echo -e "$RESTOREFILES""\n""$NEWENTRY"`
		fi
		
	else
		RESTOREFILES=`echo -e "$RESTOREFILES""\n""$ENTRY"`
	fi
	
done

# remove leading newline
RESTOREFILES=`echo -e "$RESTOREFILES" | grep .`

#echo -e RESTOREFILES: "$RESTOREFILES"

####################################
# restore each file in $RESTOREFILES
####################################

for i in `echo -e "$RESTOREFILES"`; do

	echo "$i"
	
	#RSYNC_SRC=`echo "$i" | awk 'BEGIN  { FPAT = "([^ ]+)|(\"[^\"]+\")" } {print $2}'`
	RSYNC_SRC=`echo "$i" | awk -F"," '{print $2}'`
	RSYNC_SRC=`echo "$SOURCE"/"$RSYNC_SRC" | sed 's/\/\//\//g'`
	
	#RSYNC_DEST=`echo "$i" | awk 'BEGIN  { FPAT = "([^ ]+)|(\"[^\"]+\")" } {$1 = ""; $2 = ""; $3 = ""; $4 = ""; $5 = ""; print $0}'`
	RSYNC_DEST=`echo "$i" | awk -F"," '{print $6}'`
	RSYNC_DEST=`echo "$TARGET"/"$RSYNC_DEST" | sed 's/\/\//\//g'`
	
	#FILETYPE=`echo "$i" | awk 'BEGIN  { FPAT = "([^ ]+)|(\"[^\"]+\")" } {print $5}'`
	FILETYPE=`echo "$i" | awk -F"," '{print $5}'`
	
	# create empty files without transfering anything
	
	if [ "$FILETYPE" == "inode/x-empty" ]; then
		TOUCHPATH=`dirname "$RSYNC_DEST"`
		mkdir -p "$TOUCHPATH"
		touch "$RSYNC_DEST"
	#else
	
	
		# if the file is a duplicate of a file that has already been copied
		
			# try to hard link deduped files
			
			# if that fails, try to soft link deduped files
			
			# if that fails, make local copies of deduped files
	
		# else
	
			# transfer file, throttle bandwidth
			#rsync -a -P -4 -E -v --executability --bwlimit=$BANDWIDTH "$RSYNC_SRC" "$RSYNC_DEST" | egrep -v "^sent|^total|^building|consider" | grep . >> /tmp/lac/restore_"$RESTOREDATE".log 2>&1
			
		# fi
		
	fi
	

done

exit

# save restore transaction log

gzip /tmp/lac/restore_"$RESTOREDATE".log && rsync -4 /tmp/lac/restore_"$RESTOREDATE".log.gz "$TARGET"  | egrep -v "^sent|^total|^building|consider"
rm /tmp/lac/restore_"$RESTOREDATE".log.gz 2>/dev/null




