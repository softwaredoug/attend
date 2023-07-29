#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Start tracking total user idle time to a file
# Only counting any idle periods > $1
. "$SCRIPT_DIR"/log_debug.sh

IDLE_TIME_FILE="/tmp/total_idle_time"

log "START BILLY IDLE"

total_idle=0
echo "$total_idle" > $IDLE_TIME_FILE
log "IDLE FILE INIT:"
log $(cat $IDLE_TIME_FILE)

check_frequency="$1"
last_idle=0
while [[ -f $IDLE_TIME_FILE ]] ; do
  idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
  # Accumulate idle if more than sleep period
  period=$(echo "$idle - $last_idle" | bc)
  idle_more_than_period=$(echo "$period > $check_frequency" | bc)
  log "idle enough? $idle_more_than_period -> $period > $check_frequency"
  if [[ $idle_more_than_period == "1" ]]; then
    total_idle=$(echo "$total_idle + $period" | bc)
    if [[ -f $IDLE_TIME_FILE ]]; then
      echo $total_idle > $IDLE_TIME_FILE
    fi
  fi

  log "idle -> $idle; last_idle -> $last_idle; period -> $period; total_idle -> $total_idle"
  last_idle=$idle
  sleep $check_frequency
done

log "END BILLY IDLE"
