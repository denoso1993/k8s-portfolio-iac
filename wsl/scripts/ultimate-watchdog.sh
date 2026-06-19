#!/bin/bash
# Ultimate watchdog - calls ensure-everything.sh every 30s
# Runs as a simple background process, no systemd dependency

while true; do
    bash /home/administrator/k8s-portfolio-iac/wsl/scripts/ensure-everything.sh 2>/dev/null
    sleep 30
done
