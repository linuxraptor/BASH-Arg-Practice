#!/bin/bash

if [ -n "$1" ]; then
	FIRST_ARG=$1;
	readonly VM_IMAGE=$(/usr/bin/readlink --canonicalize "${FIRST_ARG}");
	if [ ! -e "$VM_IMAGE" ]; then
		printf "File does not exist: \"$VM_IMAGE\"\n";
		exit 1;
	fi
else
	printf "No arguments specified.\n";
	exit 1;
fi


if [ -n "$2" ]; then
	SECOND_ARG=$2;
	readonly MOUNT_DESTINATION=$(/usr/bin/readlink --canonicalize "${SECOND_ARG}");
	if [ ! -e "$MOUNT_DESTINATION" ]; then
		printf "Mount location does not exist: \"$MOUNT_DESTINATION\"\n";
		exit 1;
	fi
else
	printf "Not enough arguments.\n";
	exit 1;
fi

readonly FDISK_INFO=$(/sbin/fdisk --list --units=sectors --color=always "${VM_IMAGE}");
printf "${FDISK_INFO}\n\n" | tail -n +9;
readonly PARTITION_OFFSET=$(
	printf "${FDISK_INFO}" | grep --extended-regexp "83 Linux|Sector size" | sed --quiet --regexp-extended 'N;s/^Sector\ssize\s\(logical\/physical\)\:\s([[:digit:]]+)\sbytes\s\/\s[[:digit:]]+\sbytes\n(..*)\s([[:digit:]]+)\s[[:digit:]]+\s[[:digit:]]+\s\s..*\s..\sLinux/\1\*\3/p';
);

if [[ $PARTITION_OFFSET -ne 0 ]]; then
	printf "Detected offset of first available linux partition: $PARTITION_OFFSET\n\n";
	readonly OFFSET_ARG=",offset=\$(($PARTITION_OFFSET))";
else
	readonly OFFSET_ARG="";
fi

readonly MOUNT_COMMAND="/bin/mount --type auto --options loop$OFFSET_ARG --source \"${VM_IMAGE}\" --target \"${MOUNT_DESTINATION}\"";

printf "Running command:\n";
printf "${MOUNT_COMMAND}\n";

eval ${MOUNT_COMMAND};

# Where does the offset come from?
# https://www.raspberrypi.org/forums/viewtopic.php?f=29&t=48811
# ~ $ fdisk -l 2015-11-21-raspbian-jessie.img
# says:
# Sector size (logical/physical): 512 bytes / 512 bytes
# Device                          Boot  Start     End Sectors  Size Id Type
# 2015-11-21-raspbian-jessie.img1        8192  131071  122880   60M  c W95 FAT32 (LBA)
# 2015-11-21-raspbian-jessie.img2      131072 7684095 7553024  3.6G 83 Linux

# We want to mount the second partition.
# Sector size is 512
# Second partition begins at sector 131072
# Offset = ( sector size * sectors )
# Offset = (    512      * 131072  )

