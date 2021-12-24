#!/usr/bin/env bash

##################
# FIRST EDIT THESE TWO VARIABLES TO MATCH YOUR NETWORK DEVICES
# Then, at the bottom of this file, make a torrent client startup command that makes sense.
VPN_IFACE="tun0"
LOCAL_IFACE="eth0"
##################

ROUTING_TABLE_EXIT_CODE="$(ip route show table FROM_VPN >/dev/null 2>&1; echo $?)"
ROUTING_TABLE_CONTENTS="$(ip route show table FROM_VPN 2>/dev/null)"
if [[ "${ROUTING_TABLE_EXIT_CODE}" -ne 0 ]] || [[ -z "${ROUTING_TABLE_CONTENTS}" ]]; then
  IP_ROUTES="$(ip route show)"

  # Route looks like:
  # 0.0.0.0/1 via 172.16.0.1 dev tun0
  VPN_GATEWAY="$(sed -ne 's/^0\.0\.0\.0\/1\ via\ \([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\ dev\ '"${VPN_IFACE}"'\s.*$/\1/p' <<< "${IP_ROUTES}")"
  printf "VPN internal gateway: %s\n" "${VPN_GATEWAY}"

  LAN_GATEWAY="$(sed -ne 's/^default\ via\ \([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\ dev\ '"${LOCAL_IFACE}"'\s.*$/\1/p' <<< "${IP_ROUTES}")"
  printf "LAN internal gateway: %s\n" "${LAN_GATEWAY}"

  VPN_IFACE_INFO="$(ip address list "${VPN_IFACE}")"
  VPN_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)\/?[[:digit:]]?[[:digit:]]?\s.*/\1/p' <<< "${VPN_IFACE_INFO}")"
  printf "VPN internal IP: %s\n" "${VPN_IFACE_ADDR}"

  LOCAL_IFACE_INFO="$(ip address list "${LOCAL_IFACE}")"
  LOCAL_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)\/?[[:digit:]]?[[:digit:]]?\s.*/\1/p' <<< "${LOCAL_IFACE_INFO}")"
  printf "Local internal IP: %s\n" "${LOCAL_IFACE_ADDR}"

  # Check if IP addresses are accessible.
  if [[ -z "${VPN_IFACE_ADDR}" || -z "${LOCAL_IFACE_ADDR}" ]]; then
    printf "\nSomething is wrong...\n"
    printf "An IP address is missing or cannot be parsed.\n"
    printf "Both VPN and LAN IP addresses are required for these routing rules.\n"
    printf "Possible causes:\n"
    printf " - The VPN connection is not initialized.\n"
    printf " - An interface name is misconfigured at the top of this script.\n"
    printf " - There is a networking error.\n"
    printf " - Command syntax has changed for the 'ip' utility used by this script.\n"
    printf "\n"
    printf "Start by diagnosing with these commands:\n"
    printf "ip route show\n"
    printf "ip address list\n"
    exit 1
  fi

  # Check if routing gateways are known.
  if [[ -z "${VPN_GATEWAY}" || -z "${LAN_GATEWAY}" ]]; then
    printf "\nCannot find info for VPN or LAN gateways.\n"
    printf "Try restarting your local interface with something like:\n"
    printf "sudo systemctl restart networking\n"
    printf "or, if that does not work:\n"
    printf "sudo /etc/init.d/networking restart\n"
    exit 1
  fi
  
    printf "\nInitializing routes:\n"
  # Checking if routing table names are registered.
  # http://linux-ip.net/html/tools-ip-route.html
  if [[ "$(grep FROM_LAN /etc/iproute2/rt_tables >/dev/null 2>&1; echo $?)" -ne 0 ]]; then
    $(echo "10 FROM_LAN" >> /etc/iproute2/rt_tables)
  fi
  if [[ "$(grep FROM_VPN /etc/iproute2/rt_tables >/dev/null 2>&1; echo $?)" -ne 0 ]]; then
    $(echo "20 FROM_VPN" >> /etc/iproute2/rt_tables)
  fi
  # Build separate routing tables for local and remote traffic.
  NEW_ROUTING_TABLE="ip route del default;"
  NEW_ROUTING_TABLE+="ip route add default via "${VPN_GATEWAY}" dev "${VPN_IFACE}";"
  CURRENT_ROUTING_TABLES=$(ip rule list | awk '/lookup/ {print $NF}')
  if [[ $(grep FROM_ <<<"${CURRENT_ROUTING_TABLES}") ]]; then
    NEW_ROUTING_TABLE+="ip rule delete table FROM_LAN;"
    NEW_ROUTING_TABLE+="ip rule delete table FROM_VPN;"
  fi
  NEW_ROUTING_TABLE+="ip rule add from "${LOCAL_IFACE_ADDR}" table FROM_LAN;"
  NEW_ROUTING_TABLE+="ip rule add from "${VPN_IFACE_ADDR}" table FROM_VPN;"
  # Recreate routes as part of the remote routing tables.
  # I have tried "ip route change", but I always get "no such file" error.
  NEW_ROUTING_TABLE+="ip route del 0.0.0.0/1 via "${VPN_GATEWAY}" dev "${VPN_IFACE}";"
  NEW_ROUTING_TABLE+="ip route add 0.0.0.0/1 via "${VPN_GATEWAY}" dev "${VPN_IFACE}" table FROM_VPN;"
  NEW_ROUTING_TABLE+="ip route del 128.0.0.0/1 via "${VPN_GATEWAY}" dev "${VPN_IFACE}";"
  NEW_ROUTING_TABLE+="ip route add 128.0.0.0/1 via "${VPN_GATEWAY}" dev "${VPN_IFACE}" table FROM_VPN;"
  OLDIFS=${IFS}; IFS=$';'
  for ROUTE in ${NEW_ROUTING_TABLE}; do
    printf "\n${ROUTE}; "
    eval "${ROUTE}"
  done
  IFS=${OLDIFS}
  printf "\n"

else
   printf "Routing tables for this task already seem to exist.\n"
   printf "Making this script robust enough to check their validity is too much work. :-)\n"
   printf "Try restarting your local interface with something like:\n"
   printf "sudo systemctl restart networking\n"
   printf "or, if that does not work:\n"
   printf "sudo /etc/init.d/networking restart\n"
   printf "\nThen: make sure your VPN is running, and re-run this script.\n"
  exit 1

fi

# Review the information on the screen and ensure it makes sense.
sleep 7

##################
# Start torrent client by specifying the VPN and local IP addresses:
# rtorrent -b "${VPN_IFACE_ADDR}"
# Start deluge similarly:
# deluged --port=58846 --interface="${VPN_IFACE_ADDR}" --ui-interface="${LOCAL_IFACE_ADDR}"
# You probably also want to specify "--logfile=" somewhere so you can see if it has errors.
# If you have a lesser-privilged torrent user for your client, you can start that using sudo -u <USER> <COMMAND>:
# sudo -u my-deluge-user deluged --port=...
# sudo -u my-rtorrent-user rtorrent -b ...
# Good luck.
##################
