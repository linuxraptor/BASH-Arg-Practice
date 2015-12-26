#!/bin/bash

# Alright, let's hope the HTML this page spits out isnt too horrendous,
# cuz this shit is BASIC.

# Not that it matters, but apparently, most website got wise and started blocking
# the curl user agent string and I REALLY don't feel like spoofing right now.

# TEMPFILE NECESSARY. Even small websites will overflow an array and break the subshell.

TEMPFILE="/tmp/website-ip-query.html";
# Should add a test to create tempfile here.
readonly INTERFACE="tun0";
#readonly IP_CHECKING_WEBSITE="https://www.iplocation.net/find-ip-address";
#readonly IP_CHECKING_WEBSITE="http://www.ipchicken.com/";
#readonly IP_CHECKING_WEBSITE="http://mxtoolbox.com/WhatIsMyIP/";
#readonly IP_CHECKING_WEBSITE="https://www.privateinternetaccess.com/pages/whats-my-ip/";
readonly IP_CHECKING_WEBSITE="http://whatsmyip.net/";

IP_WEBSITE_RESULT=`curl --interface "${INTERFACE}" -m 600 -s "${IP_CHECKING_WEBSITE}" 2>/dev/null -o "${TEMPFILE}"`;
if [[ -n `cat "${TEMPFILE}"` ]];
then
	while read LINE;
	do
		 POTENTIAL_IP_ADDRESS=`sed -n 's/[^[:digit:]]*.*\([[:digit:]]\{3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\).*$/\1/p' <<< "${LINE}"`;
		if [[ "${POTENTIAL_IP_ADDRESS}" ]];
		then
			readonly IP_ADDRESS="${POTENTIAL_IP_ADDRESS}";
			printf "IP address found: \"""${IP_ADDRESS}""\"\n";
		
			# Variable dump for debugging.
			#cat <<- EOF
			#"${LINE}"
			#EOF

			break;
		fi
	done < "${TEMPFILE}"

	# To be completely honest, I only wrote this part beacuse seeing the output
	# is just too much fun. Prints all IP addresses it can find on the page. Hilarious.
	
	#readonly ALL_IP_ADDRESSES=`sed -n 's/[^[:digit:]]*.*\([[:digit:]]\{3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\).*$/\1/p' "${TEMPFILE}"`;
	#printf "All IP addresses in result:\n""${ALL_IP_ADDRESSES}""\n";

else
	printf "No response received.\n";
	exit 1;
fi
rm "${TEMPFILE}";
