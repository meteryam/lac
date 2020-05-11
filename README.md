# lac

lac version 0.80a

lac is a backup script that uses rsync to copy files from one directory to another.  The motivating use case is copying files from a local source to a remote destination that has been mounted as a network volume.  It's designed to run in CentOS, but with varying levels of effortit could be adapted to run in other Unix-like operating systems.

status:

lac is currently in alpha development.  This means that its feature set is still in flux, and errors abound.  Use it at your own risk.

what it does:

- throttles transmission speeds
- compresses files by type (as detected by the script lacf.bash, which leverages the file command), and within user-defined size limits
- applies file-level dedup to minimize copies
- excludes user-defined file types, file names, directory paths and files below a user-defined limit
- supports both full and incremental backups

what it doesn't do:

- doesn't transfer files with names containing commas, semicolons, equal signs or single quotes
- doesn't combine small files
- doesn't restore original permissions of deduped or empty files

future plans:

- restoration of files and directories within restores
- restoration of original posix permissions of deduped and empty files
- safe deletion of backups


utilities and syntax:

lac:
	lac.bash -f	# full backup
	lac.bash -s source -t target	# can optionally specify source and target options via command line

files.txt
	exclude_name	/path/to/file
	exclude_path	/path/to/directory
	exclude_type	string
	include		/path/to/something	
	
config.txt
	backup_to		/path/to/target
	bandwidth		integer	# measured in kbps
	compress_min_kb		integer
	compress_max_kb		integer
	compress_type		string
	exclude_hidden		true/false # whether to exclude hidden files
	min_bytes		integer	# minimum bytes to back up
	noleaf			true/false # sets find's noleaf option for search optimization; see man find
	


lacf:
	lacf.bash file	# tells you the file type to specify in files.txt

fix_files:
	fix_files.bash /path	# renames all directories and names with commas and single quotes in the supplied path; could be destructive

lacr:
	lacr.bash -s source -t target -r restore.date # can optionally specify source and target options via command line

config.txt
	backup_to		/path/to/source
	restore_to		/path/to/target

Note that "backup_to" serves as the default target for backups and the default source for restores. This is intentional.



