#!/bin/bash

# Goals of this revision:

# Outstanding:
# Introduce script arguments.
# Use functions.
# Replace script stdin/stdout pipes with more secure methods (if possible).
# Add interactivity as an option.
# Append additional mount options to the final mount command.
# Add "while" loops to satisfy variables (partition number invalid, input file invalid, mountpoint invalid).
# Appropriate exit code with `mount` verification of existence of source in the mount table.
# Add usage information.

# Completed:
# Add interactivity by default for partitions inside images.

if [ -n "$1" ]; then
	FIRST_ARG=$1;
	readonly VM_IMAGE=$(/usr/bin/readlink --canonicalize "${FIRST_ARG}");
	if [ ! -e "${VM_IMAGE}" ]; then
		printf "File does not exist: \""${VM_IMAGE}"\"\n";
		exit 1;
	fi
else
	printf "No arguments specified.\n";
	exit 1;
fi


if [ -n "$2" ]; then
	SECOND_ARG=$2;
	readonly MOUNT_DESTINATION=$(/usr/bin/readlink --canonicalize "${SECOND_ARG}");
	if [ ! -e "${MOUNT_DESTINATION}" ]; then
		printf "Mount location does not exist: \""${MOUNT_DESTINATION}"\"\n";
		exit 1;
	fi
else
	printf "Not enough arguments.\n";
	exit 1;
fi

readonly FDISK_INFO=$(/sbin/fdisk --list --units=sectors --color=always "${VM_IMAGE}");
readonly FDISK_COLUMN_TITLES=$(tail -n +9 <<< "${FDISK_INFO}" | head -n 1);
readonly FDISK_AVAILABLE_PARTITIONS=$(tail -n +10 <<< "${FDISK_INFO}");
readonly MORE_THAN_ONE_PARTITION=$(tail -n +11 <<< "${FDISK_INFO}");
if [ -n "${FDISK_AVAILABLE_PARTITIONS}" ];
then
	if [ -n "${MORE_THAN_ONE_PARTITION}" ];
	then
		LINE_NUMBER=0;
		AVAILABLE_FORMATTING_SPACE='  ';
		printf "Please choose a partition:\n";
		printf "     ""${FDISK_COLUMN_TITLES}""\n";
		while read LINE;
		do
			((LINE_NUMBER++))
			# If you have ten or more partitions on one device or image, then you need to rethink your storage strategy.
			if [ "${LINE_NUMBER}" == 10 ];
			then
				AVAILABLE_FORMATTING_SPACE=' ';
			fi
			printf "("${LINE_NUMBER}")";
			printf "${AVAILABLE_FORMATTING_SPACE}";
			printf "${LINE}""\n";
		done <<< "${FDISK_AVAILABLE_PARTITIONS}";
		printf "\n";
		
		printf "Choose the partition you would like to mount [1-"${LINE_NUMBER}"]: ";
		read CHOSEN_PARTITION_NUMBER;
		
		while ! [[ "${CHOSEN_PARTITION_NUMBER}" =~ ^[0-9]+$ ]] || [ "${CHOSEN_PARTITION_NUMBER}" -eq 0 ] || [ ! "${CHOSEN_PARTITION_NUMBER}" -le "${LINE_NUMBER}" ];
		do
			printf "Requested partition number is out of range.\n";
			printf "\n";
			printf "Choose the partition you would like to mount [1-"${LINE_NUMBER}"]: ";
			read CHOSEN_PARTITION_NUMBER;
		done;
	else
		readonly CHOSEN_PARTITION_NUMBER=1;
		printf "Mounting the following partition:\n";
		printf "     ""${FDISK_COLUMN_TITLES}""\n";
		printf "     ""${FDISK_AVAILABLE_PARTITIONS}""\n";
	fi

	readonly CHOSEN_PARTITION=$(head -n "${CHOSEN_PARTITION_NUMBER}" <<< "${FDISK_AVAILABLE_PARTITIONS}" | tail -n 1);
	readonly SECTOR_SIZE=$(
		grep --extended-regexp "Sector size" <<< "${FDISK_INFO}" | sed --quiet --regexp-extended 's/^Sector\ssize\s\(logical\/physical\)\:\s([[:digit:]]+)\sbytes\s\/\s[[:digit:]]+\sbytes/\1/p';
	);
	readonly PARTITION_OFFSET="$(
		sed --quiet --regexp-extended "s/(..*)\s+([[:digit:]]+)\s+[[:digit:]]+\s+([[:digit:]]+)\s+..*$/,offset=\$\(\("${SECTOR_SIZE}"\*\2\)\),sizelimit=\$\(\("${SECTOR_SIZE}"\*\3\)\)/p" <<< "${CHOSEN_PARTITION}";
	)";
	if [ -n "${PARTITION_OFFSET}" ]; then
		printf "Offset required for this partition.\n\n";
	fi
else
	readonly PARTITION_OFFSET='';
fi;

readonly MOUNT_COMMAND="/bin/mount --type auto --options loop"${PARTITION_OFFSET}" --source \""${VM_IMAGE}"\" --target \""${MOUNT_DESTINATION}"\"";

printf "Running command:\n";
printf "${MOUNT_COMMAND}""\n";

eval "${MOUNT_COMMAND}";

