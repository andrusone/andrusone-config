#!/bin/bash

# check-nics.sh — Check link status for all network interfaces

for iface in /sys/class/net/*; do
  iface_name=$(basename "$iface")
  echo -n "$iface_name: "
  ethtool "$iface_name" | grep "Link detected"
done
