#!/bin/bash
#
# Accumulate a total idle time to the user
#
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Start tracking total user idle time to a file
# Only counting any idle periods > $1
. "$SCRIPT_DIR"/log_debug.sh
. "$SCRIPT_DIR"/utils.sh


idle_sys() {
  idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
  echo $idle
}
IDLE_SYS=idle_sys
SLEEP=sleep

if [[ -f 'idle_sys_mock' ]]; then
  log "USING MOCK"
  IDLE_SYS="./idle_sys_mock"
  SLEEP="./sleep_mock"
fi

IDLE_TIME_FILE="/tmp/total_idle_time"

idle_counter() {
  # Accumulates idle after every sleep if 
  # the idle period is greater than the check_frequency

  log "START BILLY IDLE"

  total_idle=0
  echo "$total_idle" > $IDLE_TIME_FILE
  log "IDLE FILE INIT:"
  log $(cat $IDLE_TIME_FILE)

  check_frequency="$1"
  last_idle=0
  while [[ -f $IDLE_TIME_FILE ]] ; do
    idle=$($IDLE_SYS)
    # Accumulate idle if more than sleep period
    if check "$idle >= $check_frequency"; then
      period=$(compute "$idle - $last_idle")
      if check "$period < 0"; then
        period=$idle
      fi
      total_idle=$(compute "$total_idle + $period")
      if [[ -f $IDLE_TIME_FILE ]]; then
        echo $total_idle > $IDLE_TIME_FILE
      fi
      last_idle=$idle
    fi

    log "idle -> $idle; last_idle -> $last_idle; period -> $period; total_idle -> $total_idle; check_frequency -> $check_frequency"
    $SLEEP $check_frequency
  done

  log "END BILLY IDLE"

} 

idle_counter "$1"
