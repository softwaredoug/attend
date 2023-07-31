#!/bin/bash
PROCESS_NAME="attend"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

idle_call() {
  "$SCRIPT_DIR"/idle.sh "$@"
}

focus_call() {
  focus=$(osascript "$SCRIPT_DIR"/focusedapp.scpt 2> /dev/null)
  echo "$focus"
}

afplay_call() {
  afplay "$@" &
}


GET_FOCUS=focus_call
SLEEP=sleep
AFPLAY=afplay_call
GDATE=gdate
IDLE=idle_call
CHROME_CLI=chrome-cli

if [[ -f 'idle_mock' ]]; then
  LOG_FILE="/tmp/attend_log.txt"
  OUTPUT_FILE="/tmp/attend_output.txt"
  PID_FILE="/tmp/attend_process.pid"

  IDLE='./idle_mock'
  GET_FOCUS="./focus_mock"
  SLEEP="./sleep_mock"
  AFPLAY="./afplay_mock"
  GDATE="./gdate_mock"
  CHROME_CLI="./chrome-cli_mock"
else
  LOG_FILE="$HOME/.attend_log.txt"
  OUTPUT_FILE="$HOME/.attend_worklog.txt"
  PID_FILE=$(echo $(getconf DARWIN_USER_TEMP_DIR)/attend_process.pid)
fi

TIMESTAMP_PATTERN="+%Y-%m-%dT%H:%M:%S"
MS_PATTERN="+%s%3N"
IDLE_TIME_FILE="/tmp/total_idle_time"

. "$SCRIPT_DIR"/utils.sh
. "$SCRIPT_DIR"/log.sh

log "LOG START"

#------------------------------
exit_attend() {
  rm -f $PID_FILE
  rm -f $IDLE_TIME_FILE
  exit 1
}

# These apps we can use the window name to get the front tab
# And use that to define the 'focus'
# Currently just clicking a link also changes title, which 
# probable shouldn't count as a focus change
app_tabs_change_focus() {
  app_name=$1
  log "Checking app:$app_name<"
  case $app_name in
    "Google Chrome")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

tab_name() {
  which $CHROME_CLI > /dev/null
  if [ $? -eq 0 ]; then
    # Get host name
    tab_name=$(OUTPUT_FORMAT='json' $CHROME_CLI info | jq '.url' | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    log "tab_name:$tab_name"
    echo "$tab_name"
    return 0
  else
    log "chrome-cli not found"
    return 1
  fi 
}


focus_name() {
  window_title=$($GET_FOCUS)
  log "Window Title:$window_title"

  # Get whats before and after ||
  app_name=${window_title%||*}
  app_name=$(echo $app_name | xargs)
  title=${window_title#*||}

  app_tabs_change_focus "$app_name"
  if [ $? -eq 0 ]; then
    tab_name=$(tab_name)
    if [ $? -eq 0 ]; then
      echo "$app_name || $tab_name"
    else
      echo "$window_title"
    fi
  else
    echo "$app_name"
  fi

}


# Global state for this
# session
TOT_SCORE=0
MAX_SCORE=0
NUM_SWITCHES=0
LAST_TIME=0
LAST_IDLE=0
TOT_IDLE=0
IDLE_PID=0
NUM_LINES=0
MAX_APP=""

output() {
  if [[ ! -f $OUTPUT_FILE ]]; then
    touch $OUTPUT_FILE
  fi
  echo "$1" >> $OUTPUT_FILE
  let "NUM_LINES = $NUM_LINES + 1"  
}


# Compute effective seconds
scoring_function() {
  time=$1
  # Focus at focus_full seconds treats seconds as full time focus
  focus_full=360
  focus_mid=$(compute "$focus_full / 2")
  power=$(compute "-(0.005 * ($time - $focus_mid) )")
  # Logistic function for time multiple
  slope=$(compute "1 / (e($power) + 1)")

  # score is effective seconds
  score=$(compute "$time * $slope")
  echo "$score"
}

update_scores() {
  time=$($GDATE $MS_PATTERN )
  last_focus="$1"
  work_begin="$2"
  # calculate the time spent on the last focused app
  idle=$(cat $IDLE_TIME_FILE)
  this_idle=$(compute "$idle - $LAST_IDLE")
  this_idle_ms=$(compute "$this_idle * 1000")
  session_time_secs=$(compute "$time - $work_begin")
  let "time_diff = $time - $LAST_TIME"
  time_no_idle=$(compute "$time_diff - $this_idle_ms")
  time_diff_secs=$(compute "$time_no_idle / 1000")
  log "Update Scores:"
  log "LAST_TIME-$LAST_TIME time:$time time_diff:$time_diff"
  log "    IDLES-idle:$idle this_idle:$this_idle"
  log "     TIME_DIFF:$time_diff"
  log "       IDLE_MS:$this_idle_ms"
  log "  TIME_NO_IDLE:$time_no_idle"
  log "  TIME_DIFF_SE:$time_diff_secs"
  if [ "$time_diff" -gt "0" ]; then
   
    this_score=$(scoring_function "$time_diff_secs")

    TOT_SCORE=$(compute "$TOT_SCORE + $this_score")
    TOT_IDLE=$(compute "$TOT_IDLE + $this_idle")
    session_time_secs_no_idle=$(compute "$session_time_secs - $TOT_IDLE")
 
    assert "$this_score <= $time_diff_secs"
    assert "$TOT_SCORE <= $session_time_secs"
    assert "$TOT_SCORE <= $session_time_secs_no_idle"

    if check "$this_score > $MAX_SCORE"; then
      MAX_SCORE=$this_score
      MAX_APP=$1
    fi
    log ">> update_scores: $last_focus time:$time score:$this_score tot_score:$TOT_SCORE idle:$idle last_idle:$LAST_IDLE tot_idle:$TOT_IDLE this_idle:$this_idle time_diff:$time_diff time_diff_secs:$time_diff_secs num_switches:$NUM_SWITCHES"
    LAST_IDLE=$idle
    LAST_TIME=$time
  fi
}

output_log_line() {
  work_begin="$1"
  work_begin_ts="$2"
  session_name="$3"
  work_end=$($GDATE $MS_PATTERN)
  work_end_ts=$($GDATE $TIMESTAMP_PATTERN)
  
  log "Append to log file -- $LOG_FILE"
  if [[ ! -f $LOG_FILE ]]; then
    touch $LOG_FILE
  fi
  
  session_length_secs=$(compute "($work_end - $work_begin) / 1000")
  if check "$session_length_secs == 0"; then
    session_length_secs=1
  fi
  session_length_no_idle=$(compute "$session_length_secs - $TOT_IDLE")
  num_apps_used=$(compute "$NUM_SWITCHES + 1")
  avg_score=$(compute "$TOT_SCORE / $num_apps_used")
  MAX_SCORE=$(printf "%.2f" $MAX_SCORE)
  TOT_SCORE=$(printf "%.2f" $TOT_SCORE)
  
  session_name_no_ws=$(echo "$session_name" | tr -s '[:space:]' '_')
  max_app_no_ws=$(echo "$MAX_APP" | tr -s '[:space:]' '_')

  if [[ "$session_name_no_ws" == "" ]]; then
    session_name_no_ws="Unnamed_Session"
  fi
  if [[ "$session_name_no_ws" == "_" ]]; then
    session_name_no_ws="Unnamed_Session"
  fi

  echo "$work_end_ts $work_begin_ts $work_end $session_length_secs $TOT_IDLE $NUM_SWITCHES $TOT_SCORE $avg_score $MAX_SCORE $max_app_no_ws $session_name_no_ws" >> $LOG_FILE

}


report() {
  line="$@"

  read ln_work_end_ts ln_work_begin_ts ln_work_end ln_session_length_secs ln_TOT_IDLE ln_NUM_SWITCHES ln_TOT_SCORE ln_avg_score ln_MAX_SCORE ln_max_app_no_ws ln_session_name_no_ws <<< $line

  # Replace underscores with spaces
  ln_max_app=$(echo "$ln_max_app_no_ws" | tr '_' ' ')
  ln_session_name=$(echo "$ln_session_name_no_ws" | tr '_' ' ')

  output ""
  output "----------------------------------------"
  output "Work session:"
  if [[ "$ln_session_name_no_ws" != "" ]]; then
    output "  $ln_session_name"
  fi
  output "----"
  # Check the highest score
  highest_avg=$(sort -k7 -n -r $LOG_FILE 2> /dev/null | head -n 1 | awk '{print $7}')
  highest_max=$(sort -k8 -n -r $LOG_FILE 2> /dev/null | head -n 1 | awk '{print $8}')
  # If the current score is higher than the highest score

  ln_session_length_no_idle=$(compute "$ln_session_length_secs - $ln_TOT_IDLE")
  log ">>> TOT_SCORE: $ln_TOT_SCORE"
  log ">>> TOT_IDLE: $ln_TOT_IDLE"
  log ">>> session_length_secs: $ln_session_length_secs"
  log ">>> session_length_no_idle: $ln_session_length_no_idle"
  log ">>> just ratio: $(compute "$ln_TOT_SCORE / $ln_session_length_no_idle")"
  work_percentage=$(compute "100 * ($ln_TOT_SCORE / $ln_session_length_no_idle)")
  work_percentage=$(printf "%.2f" $work_percentage)
  ln_session_length_mins=$(compute "$ln_session_length_secs / 60.0")
  ln_session_length_mins=$(printf "%.2f" $ln_session_length_mins)
  ln_session_length_no_idle_mins=$(compute "$ln_session_length_no_idle / 60.0")
  ln_session_length_no_idle_mins=$(printf "%.2f" $ln_session_length_no_idle_mins)
  output "You started working at $ln_work_begin_ts"
  output "Session lasted mins: $ln_session_length_mins"
  TOT_IDLE_MINS=$(compute "$ln_TOT_IDLE / 60.0")
  TOT_IDLE_MINS=$(printf "%.2f" $TOT_IDLE_MINS)
  output "Idle mins: $TOT_IDLE_MINS"
  
  assert "$work_percentage <= 100.0"
  assert "$work_percentage >= 0.0" 

  reporting_minutes=(5 10 20 30 45 60 90 120)
  max_percentages=(0 0 0 0 0 0 0 0)

  # Compute records for each reporting minute segment from the past work sessions
  if [[ -f "$LOG_FILE" ]]; then
    # Loop lines in LOG_FILE to compute work_percentage per line
    while IFS= read -r this_line; do
      # Get the work ratio
      log "checking line: $this_line"
      this_work_begin_ts=$(echo $this_line | awk '{print $2}')
      if [[ "$this_work_begin_ts" == "$ln_work_begin_ts" ]]; then
        log "Skipping identical line $this_line"
        continue
      fi
      this_session_length_secs=$(echo $this_line | awk '{print $4}')
      this_idle_time=$(echo $this_line | awk '{print $5}')
      # Get the session length
      this_session_length_no_idle=$(compute "$this_session_length_secs - $this_idle_time")
      this_score=$(echo $this_line | awk '{print $7}')
      this_percentage=$(compute "100 * ($this_score / $this_session_length_no_idle)")
      this_session_length_mins=$(compute "$this_session_length_secs / 60.0")

      # Loop through reporting_minutes
      idx=0
      for min_length in "${reporting_minutes[@]}"; do
        if check "$this_session_length_mins >= $min_length"; then
          log "this_session_length_mins: $this_session_length_mins min_length: $min_length"
          if check "$this_percentage > ${max_percentages[$idx]}"; then
            max_percentages[$idx]=$this_percentage
          fi
          assert "$this_percentage <= 100.0"
          assert "$this_percentage >= 0.0" 
        fi
        idx=$((idx+1))
      done
    done < $LOG_FILE
  else
    log "No attend log file found at $LOG_FILE"
  fi
  tada=0
  idx=0
  for min_length in "${reporting_minutes[@]}"; do
    if check "$ln_session_length_mins >= $min_length"; then
      if check "$work_percentage > ${max_percentages[$idx]}"; then
        output " 🎉🎉🎉🎉🎉🎉🎉🎉🎉"
        output " New high perc. for $min_length min session! -- $(printf %.2f $work_percentage)%"
        tada=1
      fi
    fi
    idx=$((idx+1))
  done

  output "----"
  output "Effective focus %: $work_percentage"
  total_effective_mins=$(compute "$ln_TOT_SCORE / 60.0")
  total_effective_mins=$(printf "%.2f" $total_effective_mins)
  output "Total effective mins: $total_effective_mins"

  output "Num task switches: $ln_NUM_SWITCHES"

  max_score_mins=$(compute "$ln_MAX_SCORE / 60.0")
  max_score_mins=$(printf "%.2f" $max_score_mins)

  output "----"
  output "Most focused app: $ln_max_app"
  output "Focused mins: $max_score_mins"
  output "----------------------------------------"

  if [ ! -f $LOG_FILE ]; then
    touch $LOG_FILE
  fi
  
  if [[ "$tada" == "1" ]]; then
    $AFPLAY "$SCRIPT_DIR"/tada.mp3
  fi
  
  session_name_no_ws=$(echo "$ln_session_name" | tr -s '[:space:]' '_')
  max_app_no_ws=$(echo "$ln_MAX_APP" | tr -s '[:space:]' '_')

  log "work_end_ts:$ln_work_end_ts work_begin_ts:$ln_work_begin_ts work_end:$ln_work_end"
  tail -n $NUM_LINES $OUTPUT_FILE
  log "REPORT DONE... quitting"
  exit 0
}


track_focus() {
  session_name="$1"
  log "TRACK FOCUS STARTING"
  rm -f $IDLE_TIME_FILE
  
  # Spawn idle time tracker
  $IDLE 10 &
  IDLE_PID=$!

  work_begin=$($GDATE $MS_PATTERN)
  work_begin_ts=$($GDATE $TIMESTAMP_PATTERN)
  LAST_TIME=$work_begin
  while [[ ! -f $IDLE_TIME_FILE ]] ; do
    log "WAITING ON IDLE (child)"
    $SLEEP 0.1
  done
  LAST_IDLE=$(cat $IDLE_TIME_FILE)
  log "IDLE READY! $LAST_IDLE"

  lastfocus=$(focus_name)
  log "Work session started at $work_begin_ts -- $work_begin -- $lastfocus"

  # loop forever, sleep for 1 second
  while [[ -f $PID_FILE ]] ; do
      $SLEEP 0.1
      # get the focused app
      focus=$(focus_name)
      # if the focused app is not the same as the last focused app
      if [ "$focus" != "$lastfocus" ]; then
          log "FOCUS SWITCH $lastfocus -> $focus"
          # play unpleasant sound
          $AFPLAY /System/Library/Sounds/Funk.aiff
          # if the last focused app is not empty
          # get the current time in milliseconds
          if [ "$lastfocus" != "" ]; then
            update_scores "$lastfocus" "$work_begin"
            let "NUM_SWITCHES = $NUM_SWITCHES + 1"
          else
            warn "Not updating focus switch because last_focus is empty"
          fi
          # set the last focused app to the current focused app
          lastfocus=$focus
      fi
  done
  log "track_focus main loop DONE"
  focus=$(focus_name)
  
  update_scores "$lastfocus" "$work_begin"
  
  log "killing idle process at $IDLE_PID"
  rm -f $IDLE_TIME_FILE
  wait_for_process $IDLE_PID 'idle'
  log "idle killed"
  
  output_log_line "$work_begin" "$work_begin_ts" "$session_name"
  last_line=$(tail -n 1 $LOG_FILE)
  report "$last_line"
}

# On Ctrl+C, print the score and exit


start() {
  if [[ -f $PID_FILE ]]; then
    echo "Focus already running"
    exit 1
  fi
  touch $PID_FILE
  session_name="$2"
  if [[ "$session_name" == "" ]]; then
    session_name="Unnamed Work Session"
  fi
  track_focus "$2" & 
  pid=$!
  echo "$pid" > $PID_FILE
  while [[ ! -f $IDLE_TIME_FILE ]] ; do
    echo "Waiting on attend to start..."
    $SLEEP 0.1
  done
}

stop() {
  if [[ -f $PID_FILE ]]; then
    pid=$(cat $PID_FILE)
    echo "Stopping attend at pid $pid"
    rm $PID_FILE
    wait_for_process "$pid" $PROCESS_NAME
    echo "Process stopped"
  else
    echo "No attend process running"
    exit 1
  fi
}

help() {
  echo "Usage: attend [start|stop]"
  echo ""
  echo "  start: start tracking your focus"
  echo "  start \"Session Name\": start tracking your focus with a custom session name"
  echo "  stop: stop your work session"
  return 1
}

reset() {
  if [[ -f $PID_FILE ]]; then
    echo "Please exit the current session before resetting with:"
    echo ""
    echo "  attend stop"
    return 1
  fi
  # Confirm we want to reset
  confirm "Resetting will delete all your work logs. Are you sure you want to reset?" || return 1
  echo ""
  echo "Resetting attend..."
  rm -f $OUTPUT_FILE
  rm -f $LOG_FILE
  echo "Done"
}

if [[ "$1" == "start" ]]; then
  start "$@"
elif [[ "$1" == "stop" ]]; then
  stop "$@"
elif [[ "$1" == "reset" ]]; then
  reset "$@"
else
  help
fi
