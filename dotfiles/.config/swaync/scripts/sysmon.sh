#!/bin/bash
# CPU load
CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
# RAM usage
RAM=$(free | grep Mem | awk '{printf "%.0f%%", $3/$2 * 100.0}')
# Disk usage (root filesystem)
DISK=$(df -h / | awk 'NR==2 {print $5}')
echo "CPU: ${CPU} | RAM: ${RAM} | Disk: ${DISK}"