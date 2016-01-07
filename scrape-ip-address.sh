#!/bin/bash

# Not that it matters, but apparently, most website got wise and started blocking the curl user agent string.

# TEMPFILE NECESSARY. Even small websites will overflow an array and break the subshell.

TEMPFILE="/tmp/website-ip-query.html";
# Should add a test to create tempfile here.
readonly INTERFACE="tun0";

readonly IP_CHECKING_WEBSITE_ARRAY=('https://www.iplocation.net/find-ip-address' 'http://www.ipchicken.com/' 'http://mxtoolbox.com/WhatIsMyIP/' 'https://www.privateinternetaccess.com/pages/whats-my-ip/' 'http://whatsmyip.net/');
printf "Website array:\n";
printf "%s\n" "${IP_CHECKING_WEBSITE_ARRAY[@]}";
printf "\nBeginning IP checking loop:\n"
for IP_CHECKING_WEBSITE in "${IP_CHECKING_WEBSITE_ARRAY[@]}";
do
	printf "%s :\n" "${IP_CHECKING_WEBSITE}";
	IP_WEBSITE_RESULT=$(curl --interface "${INTERFACE}" -m 600 -s "${IP_CHECKING_WEBSITE}" 2>/dev/null -o "${TEMPFILE}");
	if [[ -e "${TEMPFILE}" ]] && [[ -n $(cat "${TEMPFILE}") ]];
	then
		while read -r LINE;
		do
			 POTENTIAL_IP_ADDRESS=$(sed -n 's/\([[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\).*$/\n\1/p' <<< "${LINE}");
			 POTENTIAL_IP_ADDRESS=$(tail -n 1 <<< "${POTENTIAL_IP_ADDRESS}");

			if [[ "${POTENTIAL_IP_ADDRESS}" ]];
			then
				IP_ADDRESS="${POTENTIAL_IP_ADDRESS}";
				printf "%s\n" "${IP_ADDRESS}";
				# Variable dump for debugging.
				#cat <<- EOF
				#"${LINE}"
				#EOF
				break;
			fi

		done < "${TEMPFILE}"
	else
		printf "No response received.\n";
		# Should have the ability to error if all attempts had no response.
	fi
	if [[ -e "${TEMPFILE}" ]];
	then
		rm "${TEMPFILE}";
	fi;
done
