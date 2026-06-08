#!/bin/bash
MEM_PCT=$(free | awk '/^Mem/ {printf "%.0f", $3/$2 * 100}')
if [ $MEM_PCT -gt 80 ]; then
  sync && echo 3 > /proc/sys/vm/drop_caches
  logger "WSL Watchdog: Cache limpo (${MEM_PCT}% usado)"
fi
docker system prune -f --volumes 2>/dev/null
