#!/bin/bash
IFS=$'\n'

SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`
#SCRIPTPATH='/Users/metermac/Documents/working/backup/bash'

OLDDATE=`date  --date="1 year ago" +"%Y%m%d"`
#OLDDATE="20190425"

#echo $SCRIPTPATH
#echo $OLDDATE
#exit

# load includes

echo loading includes...

FULLBACKUP=0
TARGET=`grep ^backup_to $SCRIPTPATH/config.txt | head -1 | awk '{$1 = ""; print $0}' | sed -e 's/^ *//g;s/ *$//g'`
INCLUDES=`grep ^include $SCRIPTPATH/files.txt | awk '{$1 = ""; print $0}' | sed -e 's/^ *//g;s/ *$//g' | awk '!a[$0]++'`

if [ "$1" ]; then

        # handle arguments
        echo handling arguments...

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
                                -f)
                                        FULLBACKUP=1
                                        CURRENTFLAG="NOARG"
                                        ;;
                                -t)
                                        CURRENTFLAG="TARGET"
                                        ;;
                                -s)
                                        CURRENTFLAG="SOURCE"
                                        ;;
                        esac
                elif [ "$mode" == "arg" ]; then
                        case $CURRENTFLAG in
                                NOARG)
                                        echo "the -f flag takes no arguments. exiting."
                                        exit
                                        ;;
                                TARGET)
                                        TARGET="$MYFIELD"
                                        ;;
                                SOURCE)
                                        INCLUDES="$MYFIELD"
                                        ;;
                        esac
                fi
        done
        IFS=$'\n'

fi

ENTIREINDEX0=""
if [ "$FULLBACKUP" == "0" ]; then

        echo downloading indices...

        # download a sorted list of indices
        # we want the oldest at the top and the newest at the bottom so that old files don't
        # hang around forever

        # copy text files rather than gzipped files
        #INDEXFILELIST=`find $TARGET/* -maxdepth 1 -type f 2>/dev/null | grep index.txt | sort -r`

        INDEXFILELIST=`find $TARGET/* -maxdepth 1 -type f 2>/dev/null | grep index.txt.gz$ | sort -r`
        if [ "$FULLBACKUP" == 0 ]; then
                for i in `echo -e "$INDEXFILELIST"`; do

                        CHECKDATE=`echo "$i" | awk -F"/" '{print $NF}' | awk -F"." '{print $1}' | rev | cut -c1- | rev`
                        #echo "$CHECKDATE"
                        #echo "$OLDDATE"

                        if [ "$OLDDATE" -lt "$CHECKDATE" ]; then
                                cp "$i" /tmp/lac/
                                INDEXFILENAME=`echo "$i" | awk -F"/" '{print $NF}'`

                                gunzip /tmp/lac/"$INDEXFILENAME" 2>/dev/null
                                INDEXFILENAME=`echo "$INDEXFILENAME" | rev | cut -c4- | rev`
                                INDEXFILE="/tmp/lac/$INDEXFILENAME"
                                #ls "$INDEXFILE"

                                if [ "$ENTIREINDEX0" ]; then
                                        ENTIREINDEX0=`echo -e "$ENTIREINDEX0""\n""\`cat $INDEXFILE\`"`
                                        #ENTIREINDEX0=`echo -e "$ENTIREINDEX0""\n""\`cat $i\`"`
                                else
                                        ENTIREINDEX0=`cat $INDEXFILE`
                                        #ENTIREINDEX0=`cat $i`
                                fi
                                rm "$INDEXFILE" 2>/dev/null
                        else
                                break
                        fi

                        # stop loading index files after reaching the last full backup
                        if [ "`echo \"$i\" | grep F$`" ]; then break; fi
                done
        fi

fi

# exclude index entries with prohibited characters
ENTIREINDEX=`echo -e "$ENTIREINDEX0" | grep . | egrep "\'|;|="`


# if there are no previous indices, force the current backup to be a full backup
if [ "$ENTIREINDEX" == "" ]; then
        FULLBACKUP="1"
fi


# generate backup directory from timestamp and backup type
MYDATE=`date +"%Y%m%d.%H%M%S"`
if [ "$FULLBACKUP" == "1" ]; then
        BACKUPDIR=`echo "$MYDATE"F`
else
        BACKUPDIR=`echo "$MYDATE"i`
fi



# load configuration file
echo loading configuration...

# save the config and import/exclude info in the log file
echo SOURCE: "$SOURCE" > /tmp/lac/"$BACKUPDIR".log
echo TARGET: "$TARGET" >> /tmp/lac/"$BACKUPDIR".log
echo -e "\n" >> /tmp/lac/"$BACKUPDIR".log
cat $SCRIPTPATH/config.txt >> /tmp/lac/"$BACKUPDIR".log
echo -e "\n" >> /tmp/lac/"$BACKUPDIR".log
cat $SCRIPTPATH/files.txt >> /tmp/lac/"$BACKUPDIR".log
echo -e "\n" >> /tmp/lac/"$BACKUPDIR".log

# load throttling setting
BANDWIDTH=`egrep ^bandwidth $SCRIPTPATH/config.txt | head -1 | awk '{print $2}'`

# get the minimum file size to back up
MINIMUM_BYTES=`egrep ^min_bytes $SCRIPTPATH/config.txt | head -1 | awk '{print $2}'`

# load compression settings
let "COMPRESS_MIN = `egrep ^compress_min_kb $SCRIPTPATH/config.txt | head -1 | awk '{print $2}'` * 8192"
let "COMPRESS_MAX = `egrep ^compress_max_kb $SCRIPTPATH/config.txt | head -1 | awk '{print $2}'` * 8192"
COMPRESS_TYPE_LIST=`egrep ^compress_type $SCRIPTPATH/config.txt | awk '{print $2}'`

# load noleaf setting
NOLEAFCHECK=`grep -i ^noleaf $SCRIPTPATH/config.txt | head -1 | awk '{print $2}' | tr "[:upper:]" "[:lower:]"`
if [ "$NOLEAFCHECK" == "true" ]; then
        NOLEAF="1"
else
        NOLEAF="0"
fi

# load exclude hidden files setting
EXCLUDE_HIDDEN_CHECK=`grep -i ^exclude_hidden $SCRIPTPATH/config.txt | head -1 | awk '{print $2}' | tr "[:upper:]" "[:lower:]"`
if [ "$EXCLUDE_HIDDEN_CHECK" == "true" ]; then
        EXCLUDE_HIDDEN="1"
else
        EXCLUDE_HIDDEN="0"
fi

# load both default and user-defined exclusions
EXCLUDE_PATHS0=`grep ^exclude_path $SCRIPTPATH/config.txt | awk '{$1 = ""; print $0}' | sed -e 's/^ *//g;s/ *$//g' | sort -u`
EXCLUDE_PATHS1=`grep ^exclude_path $SCRIPTPATH/files.txt | awk '{$1 = ""; print $0}' | sed -e 's/^ *//g;s/ *$//g' | sort -u`
EXCLUDE_PATHS=`echo -e "$EXCLUDE_PATHS0""\n""$EXCLUDE_PATHS1"`
EXCLUDED_PATHS_BARS=`echo -e "$EXCLUDE_PATHS" | tr '\n' '|' | rev | cut -c 2- | rev`

EXCLUDE_NAMES0=`grep ^exclude_name $SCRIPTPATH/config.txt | awk '{print $2}'`
EXCLUDE_NAMES1=`grep ^exclude_name $SCRIPTPATH/files.txt | awk '{print $2}'`
EXCLUDE_NAMES=`echo -e "$EXCLUDE_NAMES0""\n""$EXCLUDE_NAMES1" | awk '{print "/"$0}'`
EXCLUDED_NAMES_BARS=`echo -e "$EXCLUDE_NAMES" | tr '\n' '|' | rev | cut -c 4- | rev`

EXCLUDE_TYPES0=`grep ^exclude_type $SCRIPTPATH/config.txt | awk '{print $2}' | sort -u`
EXCLUDE_TYPES1=`grep ^exclude_type $SCRIPTPATH/files.txt | awk '{print $2}' | sort -u`
EXCLUDE_TYPES=`echo -e "$EXCLUDE_TYPES0""\n""$EXCLUDE_TYPES1"`
EXCLUDED_TYPES_BARS=`echo -e "$EXCLUDE_TYPES" | tr '\n' '|' | rev | cut -c 2- | rev`

PROHIBITED=",|;|'|="

# find all included files
# remove duplicate entries and empty lines
echo finding all included files...
ls `echo -e "$INCLUDES" | xargs` &>/dev/null
if [ "$NOLEAF" == 1 ]; then
        FIND_ALL_FILES=`find \`echo -e "$INCLUDES" | xargs\` -type f -noleaf 2>/dev/null | awk '!a[$0]++' | grep .`
else
        FIND_ALL_FILES=`find \`echo -e "$INCLUDES" | xargs\` -type f 2>/dev/null | awk '!a[$0]++' | grep .`
fi

echo original number of files: `echo -e "$FIND_ALL_FILES" | wc -l` | tee -a /tmp/lac/"$BACKUPDIR".log
echo excluded paths: $EXCLUDED_PATHS_BARS | tee -a /tmp/lac/"$BACKUPDIR".log
echo excluded names: $EXCLUDED_NAMES_BARS | tee -a /tmp/lac/"$BACKUPDIR".log
echo excluded types: $EXCLUDED_TYPES_BARS | tee -a /tmp/lac/"$BACKUPDIR".log
echo prohibited characters: "$PROHIBITED" | tee -a /tmp/lac/"$BACKUPDIR".log

# notify the user that filenames with prohibited characters will be skipped
#PROHIBITED_FILES=`echo -e "$FIND_ALL_FILES" | egrep "$PROHIBITED"`
#if [ "$PROHIBITED_FILES" ]; then
#        echo these file names have prohibited characters and won\'t be backed up: | tee -a /tmp/lac/"$BACKUPDIR".log
#        echo "$PROHIBITED_FILES" | tee -a /tmp/lac/"$BACKUPDIR".log
#	nop=1
#fi

# exclude filenames with prohibited characters
FIND_ALL_FILES=`echo -e "$FIND_ALL_FILES" | egrep -v ",|;|'|="`

# exclude hidden files
if [ "$EXCLUDE_HIDDEN" == "1" ]; then
        FIND_ALL_FILES=`echo -e "$FIND_ALL_FILES" | egrep -v "/\."`
fi

#echo -e "$FIND_ALL_FILES" | wc -l

# exclude unwanted paths and file names
FIND_ALL_FILES=`echo -e "$FIND_ALL_FILES" | egrep -v "^$EXCLUDED_PATHS_BARS|$EXCLUDED_NAMES_BARS$" | grep .`

echo number of files after applying exclusions: `echo -e "$FIND_ALL_FILES" | wc -l` | tee -a /tmp/lac/"$BACKUPDIR".log


# loop through INCLUDES list to generate index of files
NEWINDEX=''
RESTOREINDEX_ARRAY=()
RESTOREINDEX=''
for INCLUDE in `echo -e "$INCLUDES"`; do

	echo generating list of files for: "$INCLUDE"

	MYMASK=`echo "\`dirname \"$INCLUDE\"\`"/`

	ALLFILES=`echo -e "$FIND_ALL_FILES" | grep ^"$INCLUDE" | sort`
	

	echo -n "    "generating entries...

	NEWINDEX_ARRAY=()
	
	for MYFILE in `echo -e "$ALLFILES"`; do

                # place file paths in double quotes
                FILEPATH=`echo -e \""$MYFILE"\"`

		echo -n .
		

		FILESIZE=`ls -l "$MYFILE" 2>/dev/null | awk '{print $5}'`

		# exclude files that are below the minimum file size
		if [ "$FILESIZE" -gt "$MINIMUM_BYTES" ]; then
	

			FILETYPE=`file -i -h -p "$MYFILE" 2>/dev/null | grep -vi 'no summary info' | awk -F";" '{print $1}' | awk -F":" '{print $2}' | sed -e 's/^ *//g;s/ *$//g'`
                        # detect and replace application/octet-stream values with something informative
                        if [ "$FILETYPE" == "application/octet-stream" ]; then
                              FILETYPE=`file -h -p "$MYFILE" | awk -F":" '{print $2}' | awk '{print $1"_"$2}' | sed 's:_*$::'`
                        fi

			# check for excluded filetypes

			FILETYPE=`echo "$FILETYPE" | egrep -v "$EXCLUDED_TYPES_BARS"`
	
			# only handle permitted filetypes
			if [ "$FILETYPE" ]; then

				#echo here i am

				CHECKSUM="0"
				#CHECKSUM=`sha1sum "$MYFILE"`

				# begin with a base assumption of "not compressed"
				COMPRESSED="0"

				# construct new index entry
				NEWINDEXENTRY=`echo "$BACKUPDIR","$CHECKSUM","$COMPRESSED","$FILESIZE","$FILETYPE","$FILEPATH"`

				# create index of files to back up; ignore empty directories
				if [ "$FILETYPE" != 'inode/directory' ] && [ "$NEWINDEXENTRY" ]; then

					#echo "$NEWINDEXENTRY"
					NEWINDEX_ARRAY+=( "$NEWINDEXENTRY" )

					#if [ "$NEWINDEX" ]; then
					#	NEWINDEX=`echo -e "$NEWINDEX""\n""$NEWINDEXENTRY"`
					#else
					#	NEWINDEX=$NEWINDEXENTRY
					#fi
					#echo -n ,
				fi

			fi	# if [ "$FILETYPE" ]

		fi	# if [ "$FILESIZE" < "$MINIMUM_BYTES" ]
		
	done	# for MYFILE in "$ALLFILES"

	NEWINDEX=`for ROW in ${NEWINDEX_ARRAY[@]}; do echo "$ROW"; done`

	#echo
	#echo -e "$NEWINDEX"
	#echo
	#echo ${NEWINDEX_ARRAY[@]}

	#exit 


	#NEWINDEX=`echo -e "$NEWINDEX" | grep .`
	
	# create backup directories

	echo
	echo -n "    "creating directories...

	DIRLIST2=`dirname \`echo -e "$ALLFILES"\` | awk '$0 !~ last "/" {print last} {last=$0} END {print last}' | grep . | sort -u`

	i=""
	CREATEDIR=""
	for i in `echo -e "$DIRLIST2"`; do
		MAN=`echo "$i" | sed 's|'$MYMASK'||g'`
		CREATEDIR=`echo "$TARGET"/"$BACKUPDIR"/"$MAN" | sed 's/\/\//\//g'`
		mkdir -p "$CREATEDIR"
		echo -n .
	done

	#exit

	echo
	echo backing up files for $INCLUDE
	echo

	####################################
	# back up files
	# exclude files without checksums
	# transfer files before checksums expire
	####################################

	for i in `echo -e "$NEWINDEX" | awk '!a[$0]++'`; do


		COL2=`echo "$i" | awk -F"," '$2 ~ /"/' | awk -F"," '{ print $2 }'`

		if [ "$COL2" ]; then
			nop=1
		else

			# set rsync source
			FILETOCOPY0=`echo "$i" | awk -F"," '{print $6}' | tr -d '"'`

			if [ "$FILETOCOPY0" ]; then


				# handle de-duping features, based on files that have successfully transferred

				CHECKSUM=`sha1sum "$FILETOCOPY0"`
				COMPRESSED=`echo "$i" | awk -F"," '{print $3}'`
				FILESIZE=`echo "$i" | awk -F"," '{print $4}'`
				FILETYPE=`echo "$i" | awk -F"," '{print $5}'`
				FILEPATH=`echo "$i" | awk -F"," '{print $6}'`

       		                # if the new checksum belongs to a file in the current backup, replace the checksum with a quoted link to its path

                	        #NEWCHECKSUMS=`echo -e "$RESTOREINDEX" | awk -F"," -v CHECKSUM=$CHECKSUM  '$2 == CHECKSUM {print $0}' | head -1`
				#NEWCHECKSUMS=`echo -e "$RESTOREINDEX" | awk -F"," -v CHECKSUM=$CHECKSUM '{if ($2 == CHECKSUM) {print $0; exit;}}'`
				NEWCHECKSUMS=`{ for ROW in ${RESTOREINDEX_ARRAY[@]}; do echo $ROW; done; } | awk -F"," -v CHECKSUM=$CHECKSUM '{if ($2 == CHECKSUM) {print $0; exit;}}'`

                        	OLDCHECKSUMS=""

                        	if [ "$FULLBACKUP" == "0" ]; then

                                	#OLDCHECKSUMS=`echo -e "$ENTIREINDEX" | awk -F"," -v CHECKSUM=$CHECKSUM  '$2 == CHECKSUM {print $0}' | head -1`
					OLDCHECKSUMS=`echo -e "$ENTIREINDEX" | awk -F"," -v CHECKSUM=$CHECKSUM '{if ($2 == CHECKSUM) {print $0; exit;}}'`
                                	if [ "$OLDCHECKSUMS" ]; then

						COMPRESSED=`echo "$OLDCHECKSUMS" | awk -F"," '{print $3}'`

                                        	# if the new checksum belongs to a previously backed up file, replace the checksum with a quoted link to its path (preferrably a more recent match)

                                        	CHECKSUM0=`echo -e "$OLDCHECKSUMS" | awk -F"," '{print $1}'`
                                        	CHECKSUM1=`echo -e "$OLDCHECKSUMS" | awk -F"," '{print $6}' | tr -d '"' | sed -e 's/^ *//g;s/ *$//g' | sed 's|'$MYMASK'||g' | sed 's/\/\//\//g' | sed 's/\/\//\//g'`
                                        	CHECKSUM=`echo \"$CHECKSUM0"/"$CHECKSUM1\"`

                                	fi

				elif [ "$NEWCHECKSUMS" ]; then
					COMPRESSED=`echo "$NEWCHECKSUMS" | awk -F"," '{print $3}'`

                                        CHECKSUM=`echo -e "$NEWCHECKSUMS" | awk -F"," '{print $6}' | tr -d '"' | sed -e 's/^ *//g;s/ *$//g' | sed 's|'$MYMASK'||g'`
                                        CHECKSUM=`echo \"$CHECKSUM\"`


                        	fi	# if [ "$FULLBACKUP" == "0" ]


				if [ "$OLDCHECKSUMS" == "" ] && [ "$NEWCHECKSUMS" == "" ]; then

                                	# put compression code here to ensure that it doesn't interfere with deduping
                                	for COMPRESS_TYPE in `echo -e "$COMPRESS_TYPE_LIST"`; do
                                        	if [ "$FILETYPE" == "$COMPRESS_TYPE" ] && [ "$COMPRESS_MIN" -le "$FILESIZE" ] && [ "$COMPRESS_MAX" -ge "$FILESIZE" ]; then
                                                	COMPRESSED="1"
                                                	break
                                        	fi
                                	done


					RESTOREINDEXENTRY=`echo "$BACKUPDIR","$CHECKSUM","$COMPRESSED","$FILESIZE","$FILETYPE","$FILEPATH"` 


					FILETOCOPY=`echo -e "/""$FILETOCOPY0" | sed 's/\/\//\//g'`

					RSYNC_SRC=$FILETOCOPY

					# set rsync destination
					TARGETFILE0=`echo -e "$FILETOCOPY" | sed 's|'$MYMASK'||g'`
					TARGETFILE=`echo "$TARGET"/"$BACKUPDIR"/"$TARGETFILE0" | sed 's/\/\//\//g'`
					RSYNC_DEST=$TARGETFILE


					# if file is compressible, create compressed copy
					COMPRESSCHECK=`echo "$i" | awk -F"," '{print $3}' | sort -u`
					if [ "$COMPRESSCHECK" == "1" ]; then
				
						FILENAME=`echo -e "$FILETOCOPY" | awk -F"/" '{print $NF}'`
						gzip --best -k -c "$FILETOCOPY" > /tmp/lac/"$FILENAME".gz
				
						# if compression succeeds, set FILETOCOPY to the new filename
						if [ "$?" == 0 ]; then
							RSYNC_SRC="/tmp/lac/$FILENAME.gz"
							RSYNC_DEST="$TARGETFILE.gz"
						fi
					
					fi

					# transfer file, throttle bandwidth
					rsync -a -P -4 -E -s -W -v --executability --safe-links --bwlimit=$BANDWIDTH "$RSYNC_SRC" "$RSYNC_DEST" 2>&1 | egrep -v "^sent|^total|^building|consider|sending" | grep . | tee -a /tmp/lac/"$BACKUPDIR".log

					#echo rsync "$RSYNC_SRC" "$RSYNC_DEST"

					# clean up any compressed files we've created
					if [ "$COMPRESSCHECK" == "1" ]; then
							rm -rf /tmp/lac/$FILENAME.gz 2>/dev/null
					fi


				else

					echo skipping duplicate file "$FILEPATH"...

					RESTOREINDEXENTRY=`echo "$BACKUPDIR","$CHECKSUM","$COMPRESSED","$FILESIZE","$FILETYPE","$FILEPATH"`

				fi	# if [ "$NEWCHECKSUMS" == "" ] && [ "$OLDCHECKSUMS" == "" ]

				# update RESTOREINDEX iff the transfer completed
				ERROR_CODE=$?
				if [ "$ERROR_CODE" -ne 0 ]; then
					echo failed to transfer this: 
					echo "$i"
				else

					RESTOREINDEX_ARRAY+=("$RESTOREINDEXENTRY")

					#if [ "$RESTOREINDEX" ]; then
					#	RESTOREINDEX=`echo -e "$RESTOREINDEX""\n""$RESTOREINDEXENTRY"`
					#else
					#	RESTOREINDEX=$RESTOREINDEXENTRY
					#fi

				fi	# if [ "$ERROR_CODE" -ne 0 ]
			
			fi	# if [ "$FILETOCOPY0" ]
		
		fi	# if [ "$COL2" ]
		
	done	# for i in `echo -e "$NEWINDEX" | awk '!a[$0]++'`

	# update index file as we go
	#if [ "$NEWINDEX" ]; then
	#	echo -e "$NEWINDEX" >> "$TARGET"/"$BACKUPDIR"/"$BACKUPDIR".index.txt
	#	NEWINDEX=""
	#fi

done		# for INCLUDE in `echo -e "$INCLUDES"`

#exit

echo transferring index and log files...

# transfer index file
#if [ "`echo -e \"$RESTOREINDEX\" | grep .`" ]; then
if [ "`echo ${RESTOREINDEX_ARRAY[0]}`" ]; then
	{ for i in ${RESTOREINDEX_ARRAY[@]}; do echo $i; done; } > /tmp/lac/"$BACKUPDIR"".index.txt"
	#echo -e "$RESTOREINDEX"  > /tmp/lac/"$BACKUPDIR"".index.txt"
	gzip /tmp/lac/"$BACKUPDIR"".index.txt"
	RSYNC_SRC="/tmp/lac/$BACKUPDIR.index.txt.gz"
	RSYNC_DEST="$TARGET/$BACKUPDIR/"
	rsync -h -P -4 "$RSYNC_SRC" "$RSYNC_DEST" | egrep -v "^sent|^total|^building|consider|^sending" && rm /tmp/lac/$BACKUPDIR".index.txt.gz"  | tee -a /tmp/lac/"$BACKUPDIR".log 2>&1

	# compress and upload the backup log

	gzip /tmp/lac/"$BACKUPDIR".log && rsync -4 /tmp/lac/"$BACKUPDIR".log.gz "$TARGET/$BACKUPDIR/"  | egrep -v "^sent|^total|^building|consider"
	rm /tmp/lac/"$BACKUPDIR".log.gz 2>/dev/null
else
	echo nothing to transfer
fi

exit
