#!/bin/bash

# Start tracking total user idle time to a file
# Only counting any idle periods > $1

echo "START BILLY IDLE" > /dev/tty

total_idle=0
echo "$total_idle" > /tmp/total_idle_time
echo "IDLE FILE INIT:" > /dev/tty
echo $(cat /tmp/total_idle_time) > /dev/tty

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

  echo "idle -> $total_idle" > /dev/tty
  sleep $check_frequency
done
