#!/usr/bin/env bash

# Disclaimers:
# 1. This script assumes extremely simple host networking, like a purpose-built
#    container or VM. It queries routing table main for setup.
# 2. This script uses regex, which can be fragile.
# 3. This script does not use a "kill switch". Its configuration is not robust
#    against VPN connection resets.
# 4. This script only supports IPv4.
# 5. Split tunneling is one of the least secure VPN strategies due to the
#    possibility of leakage.

# Requirements:
# 1. This script must be run after wg-quick has setup the wireguard interface
# 2. The wg-quick config must configured with the following:
#    a. Address
#    b. DNS
#    c. Endpoint
#    d. Table = off  # This disables wg-quick routes
#    e. AllowedIPs is ignored and can be anything.

# Goals:
# 1. This script will not automatically detect your local network interface.
# 2. This script will not automatically detect your wireguard interface.
# 3. This decision is intentional.

##################
# EDIT THESE TWO VARIABLES TO MATCH YOUR NETWORK DEVICES.
VPN_IFACE="wg0"
LOCAL_IFACE="eth0"
##################

ROUTES="$(ip route show table all)"

# Route looks like:
# 0.0.0.0/1 via 172.16.0.1 dev tun0
# "head -n 1" is used liberally to avoid failures with existing duplicate routes.
LAN_GATEWAY="$(sed -ne 's/^default\ via\ \([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\ dev\ '"${LOCAL_IFACE}"'\s.*$/\1/p' <<<"${ROUTES}" | head -n 1)"
printf "LAN internal gateway: %s\n" "${LAN_GATEWAY}"

VPN_IFACE_INFO="$(ip address list "${VPN_IFACE}")"
VPN_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\/?[0-9]?[0-9]?\s.*/\1/p' <<<"${VPN_IFACE_INFO}" | head -n 1)"
printf "VPN internal IP: %s\n" "${VPN_IFACE_ADDR}"

LOCAL_IFACE_INFO="$(ip address list "${LOCAL_IFACE}")"
LOCAL_IFACE_ADDR="$(sed -n -r 'N;s/^.*inet\s([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\/?[0-9]?[0-9]?\s.*/\1/p' <<<"${LOCAL_IFACE_INFO}" | head -n 1)"
printf "Local internal IP: %s\n" "${LOCAL_IFACE_ADDR}"

# Endpoint declaration looks like:
# Endpoint = 111.222.33.44:51820
WG_ENDPOINT="$(wg showconf ${VPN_IFACE} | grep Endpoint | awk '{print $NF}' | awk -F: '{print $1}')"
printf "Wireguard endpoint: %s\n" "${WG_ENDPOINT}"

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
# This requires the user's $LOCAL_IFACE to be accurate.
if [[ -z "${LAN_GATEWAY}" ]]; then
  printf "\nCannot find info for LAN gateway.\n"
  printf "Try restarting your local interface with something like:\n"
  printf "sudo systemctl restart networking\n"
  printf "or:\n"
  printf "sudo /etc/init.d/networking restart\n"
  exit 1
fi

# Check for known wireguard endpoint.
# This requires the user's $VPN_IFACE to be accurate.
if [[ -z ${WG_ENDPOINT} ]]; then
  printf "\nUnable to determine the Wireguard endpoint.\n"
  printf "Is wireguard running?\n"
  printf "Use 'wg showconf' to inspect the current Wireguard state.\n"
  exit 1
fi

printf "\nModifying routes:"

up() {
  # Checking if routing table names are registered.
  # http://linux-ip.net/html/tools-ip-route.html
  if [[ "$(grep FROM_LAN /etc/iproute2/rt_tables >/dev/null 2>&1; printf $?)" -ne 0 ]]; then
    eval "$(printf "10 FROM_LAN\n" >> /etc/iproute2/rt_tables)"
  fi
  if [[ "$(grep FROM_VPN /etc/iproute2/rt_tables >/dev/null 2>&1; printf $?)" -ne 0 ]]; then
    eval "$(printf "20 FROM_VPN\n" >> /etc/iproute2/rt_tables)"
  fi
  # Build separate routing tables for local and remote traffic.
  # FYI, there is an extra space at the end of the `ip route` output.
  DEFAULT_ROUTE="$(ip route show default table main)"
  if [[ -z "${DEFAULT_ROUTE}" ]]; then
    printf "Unable to determine default route. Exiting.\n"
    exit 1
  fi
  NEW_ROUTING_TABLE=()
  NEW_ROUTING_TABLE+=("ip route del ${DEFAULT_ROUTE}")
  NEW_ROUTING_TABLE+=("ip route add ${DEFAULT_ROUTE} table FROM_LAN")
  NEW_ROUTING_TABLE+=("ip route add default via ${VPN_IFACE_ADDR} dev ${VPN_IFACE} table main")
  NAMESERVER="$(grep nameserver /etc/resolv.conf | awk '{print $NF}')"
  NEW_ROUTING_TABLE+=("ip route add ${NAMESERVER} via ${VPN_IFACE_ADDR} dev ${VPN_IFACE} table FROM_VPN")
  NEW_ROUTING_TABLE+=("ip route add ${WG_ENDPOINT} via ${LAN_GATEWAY} dev ${LOCAL_IFACE} table main")
  CURRENT_ROUTING_TABLES=$(ip rule list | awk '/lookup/ {print $NF}')
  if [[ $(grep -q FROM_LAN <<<"${CURRENT_ROUTING_TABLES}"; echo $?) -eq 0 ]]; then
    NEW_ROUTING_TABLE+=("ip rule delete table FROM_LAN")
  fi
  if [[ $(grep -q FROM_VPN <<<"${CURRENT_ROUTING_TABLES}"; echo $?) -eq 0 ]]; then
    NEW_ROUTING_TABLE+=("ip rule delete table FROM_VPN")
  fi
  NEW_ROUTING_TABLE+=("ip rule add from ${LOCAL_IFACE_ADDR} table FROM_LAN")
  NEW_ROUTING_TABLE+=("ip rule add from ${VPN_IFACE_ADDR} table FROM_VPN")
  NEW_ROUTING_TABLE+=("iptables -I OUTPUT -s ${VPN_IFACE_ADDR} ! -o ${VPN_IFACE} -j DROP")
  apply_routes "${NEW_ROUTING_TABLE[@]}"
}

down() {
  # Specifying a table for "ip route" only works if the table is still valid.
  DEFAULT_LAN_ROUTE="$(ip route show table all | grep "default via" | grep "table FROM_LAN" | head -n 1)"
  # Need to strip the "table FROM_LAN" from a line like this:
  # default via 192.168.1.1 dev eth0 table FROM_LAN proto dhcp src 192.168.1.69 metric 9
  RESET_DEFAULT_ROUTE="${DEFAULT_LAN_ROUTE/ table FROM_LAN}"
  if [[ -z "${RESET_DEFAULT_ROUTE}" ]]; then
    printf "Unable to determine original default route.\n"
    printf "Consider resetting network daemons to restore it.\n"
  fi
  RESET_ROUTING_TABLE=()
  RESET_ROUTING_TABLE+=("ip route del ${DEFAULT_LAN_ROUTE}")
  RESET_ROUTING_TABLE+=("ip route add ${RESET_DEFAULT_ROUTE}")
  RESET_ROUTING_TABLE+=("ip rule delete table FROM_VPN")
  RESET_ROUTING_TABLE+=("ip rule delete table FROM_LAN")
  RESET_ROUTING_TABLE+=("ip route del ${WG_ENDPOINT} via ${LAN_GATEWAY} dev ${LOCAL_IFACE} table main")
  RESET_ROUTING_TABLE+=("iptables -D OUTPUT -s ${VPN_IFACE_ADDR} ! -o ${VPN_IFACE} -j DROP")
  apply_routes "${RESET_ROUTING_TABLE[@]}"
}

apply_routes() {
  # Print each command and run it.
  for ROUTE in "$@"; do
    printf '\n%s;' "${ROUTE}"
    eval "${ROUTE}"
  done
  printf "\n"
}

case "$1" in
  "up")
    up
    ;;
  "down")
    down
    ;;
  *)
    printf "Must specify a command: [up,down]\n"
    printf "Exiting.\n"
    exit 1
    ;;
esac
