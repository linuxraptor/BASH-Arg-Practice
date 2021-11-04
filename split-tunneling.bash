#!/usr/bin/env bash

##################
# FIRST EDIT THESE TWO VARIABLES TO MATCH YOUR NETWORK DEVICES
# Then, at the bottom of this file, make a deluge startup command that makes sense.
VPN_IFACE="tun0"
LOCAL_IFACE="eth0"
##################

ROUTING_TABLE_EXIT_CODE="$(ip route show table FROM_VPN >/dev/null 2>&1; echo $?)"
ROUTING_TABLE_CONTENTS="$(ip route show table FROM_VPN 2>/dev/null)"
if [[ "${ROUTING_TABLE_EXIT_CODE}" -eq 0 ]] && [[ ! -z "${ROUTING_TABLE_CONTENTS}" ]];
  then
  printf "Routing table already initialized.\n"
  VPN_IFACE_INFO="$(ip address list "${VPN_IFACE}")"
  VPN_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)\/[[:digit:]]+\sbrd.*/\1/p' <<< "${VPN_IFACE_INFO}")"
  printf "VPN internal IP: %s\n" "${VPN_IFACE_ADDR}"
  LOCAL_IFACE_INFO="$(ip address list "${LOCAL_IFACE}")"
  LOCAL_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)\/[[:digit:]]+\sbrd.*/\1/p' <<< "${LOCAL_IFACE_INFO}")"
  printf "Local internal IP: %s\n" "${LOCAL_IFACE_ADDR}"
else
  IP_ROUTES="$(ip route show)"

  # Route looks like:
  # 0.0.0.0/1 via 172.16.0.1 dev tun0
  VPN_GATEWAY="$(sed -ne 's/^0\.0\.0\.0\/1\ via\ \([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\ dev\ '"${VPN_IFACE}"'\ $/\1/p' <<< "${IP_ROUTES}")"
  printf "VPN internal gateway: %s\n" "${VPN_GATEWAY}"

  LAN_GATEWAY="$(sed -ne 's/^default\ via\ \([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\ dev\ '"${LOCAL_IFACE}"'\ \ metric\ 4\ $/\1/p' <<< "${IP_ROUTES}")"
  printf "LAN internal gateway: %s\n" "${LAN_GATEWAY}"

  VPN_IFACE_INFO="$(ip address list "${VPN_IFACE}")"
  VPN_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)\/[[:digit:]]+\sbrd.*/\1/p' <<< "${VPN_IFACE_INFO}")"
  printf "VPN internal IP: %s\n" "${VPN_IFACE_ADDR}"

  LOCAL_IFACE_INFO="$(ip address list "${LOCAL_IFACE}")"
  LOCAL_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+)\/[[:digit:]]+\sbrd.*/\1/p' <<< "${LOCAL_IFACE_INFO}")"
  printf "Local internal IP: %s\n" "${LOCAL_IFACE_ADDR}"

  printf "\nInitializing routes:\n"
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
fi

##################
# Start torrent client by specifying the VPN and local IP addresses:
# deluged --port=58846 --interface="${VPN_IFACE_ADDR}" --ui-interface="${LOCAL_IFACE_ADDR}"
# rtorrent -b "${VPN_IFACE_ADDR}"
# You probably also want to specify "--logfile=" somewhere so you can see if it has errors.
# If you have a lesser-privilged torrent user for deluged, you can start that using sudo -u <USER> <COMMAND>:
# sudo -u my-deluge-user deluged --port=...
# Good luck.
##################
