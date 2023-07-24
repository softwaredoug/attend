#!/bin/bash

# Start tracking total user idle time to a file
# Only counting any idle periods > $1

rm -f /tmp/total_idle_time

echo 0 > /tmp/total_idle_time

CONTINUE=1
terminate() {
  CONTINUE=0
}

trap terminate SIGTERM SIGINT

total_idle=0.0
check_frequency="$1"
while [ $CONTINUE -eq 1 ] ; do
  idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
  # Accumulate idle if more than sleep period
  if [ $(echo "$idle > $check_frequency" | bc) -eq 1 ]; then
    total_idle=$(echo "$total_idle + $idle" | bc)
  fi
  echo $total_idle > /tmp/total_idle_time
  sleep $check_frequency
done
