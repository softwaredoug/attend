#!/bin/bash

# Start tracking total user idle time to a file
# Only counting any idle periods > $1
. log.sh

log "START BILLY IDLE"

total_idle=0
echo "$total_idle" > /tmp/total_idle_time
log "IDLE FILE INIT:"
log $(cat /tmp/total_idle_time)

check_frequency="$1"
while [[ -f /tmp/total_idle_time ]] ; do
  idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
  # Accumulate idle if more than sleep period
  if [ $(echo "$idle > $check_frequency" | bc) -eq 1 ]; then
    total_idle=$(echo "$total_idle + $idle" | bc)
  fi
  if [[ -f /tmp/total_idle_time ]]; then
    echo $total_idle > /tmp/total_idle_time
  fi

  log "idle -> $total_idle"
  sleep $check_frequency
done
