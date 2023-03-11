#!/bin/bash

# Hostname to update
SEARCH_DOMAIN="3irobotix.net"

# Replacement IP address to assign
CONGATUDO_NEW_IP=${CONGATUDO_IP:-"192.168.2.2"}


# Update hostsfile with a new IP for the hostname
sed -E "s#^([a-zA-Z1-9.:]+[[:space:]]+)(.*)(${SEARCH_DOMAIN}[[:space:]].*)#${CONGATUDO_NEW_IP} \2\3#" /etc/hosts

