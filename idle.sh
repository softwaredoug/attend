#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Start tracking total user idle time to a file
# Only counting any idle periods > $1
. "$SCRIPT_DIR"/log.sh

IDLE_TIME_FILE="/tmp/total_idle_time"

log "START BILLY IDLE"

total_idle=0
echo "$total_idle" > $IDLE_TIME_FILE
log "IDLE FILE INIT:"
log $(cat $IDLE_TIME_FILE)

check_frequency="$1"
while [[ -f $IDLE_TIME_FILE ]] ; do
  idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
  # Accumulate idle if more than sleep period
  if [ $(echo "$idle > $check_frequency" | bc) -eq 1 ]; then
    total_idle=$(echo "$total_idle + $idle" | bc)
  fi
  if [[ -f $IDLE_TIME_FILE ]]; then
    echo $total_idle > $IDLE_TIME_FILE
  fi

  log "idle -> $total_idle"
  sleep $check_frequency
done

log "END BILLY IDLE"
