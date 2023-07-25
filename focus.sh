#!/bin/bash

idle_call() {
  ./idle.sh "$@"
}

focus_call() {
    focus=$(osascript focusedapp.scpt 2> /dev/null)
    focus=$(focus_name "$focus")
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

if [[ -f 'idle_mock' ]]; then
  LOG_FILE="/tmp/focus_log.txt"
  OUTPUT_FILE="/tmp/focus_output.txt"
  PID_FILE="/tmp/focus_process.pid"

  TEST_MODE=1
  IDLE='./idle_mock'
  GET_FOCUS="./focus_mock"
  SLEEP="./sleep_mock"
  AFPLAY="./afplay_mock"
  GDATE="./gdate_mock"
else
  LOG_FILE='./focus_log.txt'
  PID_FILE=$(echo $(getconf DARWIN_USER_TEMP_DIR)/focus_process.pid)
  OUTPUT_FILE=$(echo $(getconf DARWIN_USER_TEMP_DIR)/focus_output.txt)
fi

TIMESTAMP_PATTERN="+%Y-%m-%dT%H:%M:%S"
MS_PATTERN="+%s%3N"

#------------------------------

# These apps we can use the window name to get the front tab
# And use that to define the 'focus'
# Currently just clicking a link also changes title, which 
# probable shouldn't count as a focus change
app_tabs_change_focus() {
  app_name=$1
  case $app_name in
    "Google Chrome")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


focus_name() {
  window_title=$1

  # Get whats before and after ||
  app_name=${window_title%||*}
  app_name=$(echo $app_name | xargs)
  title=${window_title#*||}

  app_tabs_change_focus "$app_name"
  if [ $? -eq 0 ]; then
    echo "$window_title"
    return 0
  fi

  echo "$app_name"
  return 0
}


# Global state for this
# session
TOT_SCORE=0
MAX_SCORE=0
NUM_SWITCHES=1
LAST_TIME=0
LAST_IDLE=0
TOT_IDLE=0
IDLE_PID=0
MAX_APP=""

output() {
  echo "$1" >> $OUTPUT_FILE
}

log() {
  output "$1"
}
log "LOG START"

scoring_function() {
  time=$1
  # Focus at focus_full seconds treats seconds as full time focus
  focus_full=360
  focus_mid=$(echo "$focus_full / 2" | bc)
  power=$(echo "-(0.005 * ($time - $focus_mid) )" | bc)
  # Logistic function for time multiple
  slope=$(echo "1 / (e($power) + 1)" | bc -l)

  # score is effective seconds
  score=$(echo "$time * $slope" | bc -l)
  echo "$score"
}

update_scores() {
  time=$($GDATE $MS_PATTERN )
  # calculate the time spent on the last focused app
  idle=$(cat /tmp/total_idle_time)
  this_idle=$(echo "$idle - $LAST_IDLE" | bc)
  let "time_diff = $time - $LAST_TIME"
  if [ "$time_diff" -gt "0" ]; then
    time_no_idle=$(echo "$time_diff - $this_idle" | bc)
    time_diff_secs=$(echo "$time_no_idle / 1000" | bc)
    this_score=$(scoring_function "$time_diff_secs")

    TOT_SCORE=$(echo "$TOT_SCORE + $this_score" | bc)
    TOT_IDLE=$(echo "$TOT_IDLE + $this_idle" | bc)
    let "NUM_SWITCHES = $NUM_SWITCHES + 1"
    if [ $(echo "$this_score > $MAX_SCORE" | bc) -eq 1 ]; then
      MAX_SCORE=$this_score
      MAX_APP=$1
    fi
    LAST_IDLE=$idle
    LAST_TIME=$time
  fi
}

report() {
  work_begin="$1"
  work_begin_ts="$2"
  work_end=$($GDATE $MS_PATTERN)
  word_end_ts=$($GDATE $TIMESTAMP_PATTERN)
  
  kill $IDLE_PID 2> /dev/null

  # rm -f  $OUTPUT_FILE
  # touch $OUTPUT_FILE

  session_length_secs=$(echo "($work_end - $work_begin) / 1000" | bc)
  output ""
  output "Work session done!"
  # Write date and score to ~/.focus_scores
  # Check the highest score
  highest_avg=$(sort -k8 -n -r ~/.focus_scores 2> /dev/null | head -n 1 | awk '{print $8}')
  highest_max=$(sort -k9 -n -r ~/.focus_scores 2> /dev/null | head -n 1 | awk '{print $9}')
  # If the current score is higher than the highest score

  avg_score=$(echo "$TOT_SCORE / $NUM_SWITCHES" | bc -l)
  output "You started working at $work_begin_ts"
  output "Work session length: $session_length_secs seconds"
  output "----"
  output "Average focus score: $avg_score"
  output "Max focus score: $MAX_SCORE"
  output "Most focused app: $MAX_APP"
  output "Num task switches: $NUM_SWITCHES"
  output "Total idle time: $TOT_IDLE"

  output "----"
  output "Highest average score: $highest_avg"
  output "Highest     max score: $highest_max"

  if [ ! -f ~/.focus_scores ]; then
    touch ~/.focus_scores
  else
    if [ $(echo "$avg_score > $highest_avg" | bc) -eq 1 ]; then
      output "🎉🎉🎉🎉🎉🎉🎉🎉🎉"
      output "New high average score! -- $avg_score"
      $AFPLAY ./tada.mp3
    fi
    
    if [ $(echo "$MAX_SCORE > $highest_max" | bc) -eq 1 ]; then
      output "🎉🎉🎉🎉🎉🎉🎉🎉🎉"
      output "New high max score! -- $MAX_SCORE"
      $AFPLAY ./tada.mp3
    fi
  fi
  echo "$work_end_ts $work_begin_ts $work_end $session_length_secs $TOT_IDLE $NUM_SWITCHES $TOT_SCORE $avg_score $MAX_SCORE " >> $LOG_FILE
  exit 0
}


track_focus() {
  # Spawn idle time tracker
  $IDLE 10 &
  IDLE_PID=$!

  work_begin=$($GDATE $MS_PATTERN)
  work_begin_ts=$($GDATE $TIMESTAMP_PATTERN)
  LAST_TIME=$work_begin

  lastfocus=$($GET_FOCUS)
  output "Work session started at $work_begin_ts -- $work_begin -- $lastfocus"

  # loop forever, sleep for 1 second
  while [[ -f $PID_FILE ]] ; do
      $SLEEP 0.1
      # get the focused app
      focus=$($GET_FOCUS)
      log "FOCUS -- $focus"
      # if the focused app is not the same as the last focused app
      if [ "$focus" != "$lastfocus" ]; then
          log "FOCUS SWITCH $lastfocus -> $focus"
          # play unpleasant sound
          $AFPLAY /System/Library/Sounds/Funk.aiff
          # if the last focused app is not empty
          if [ "$lastfocus" != "" ]; then
              # get the current time in milliseconds
              update_scores "$lastfocus"
          fi
          # set the last focused app to the current focused app
          lastfocus=$focus
      fi
  done
  focus=$($GET_FOCUS)
  update_scores "$lastfocus"
  report "$work_begin" "$work_begin_ts"
}

wait_for_process() {
  num_processes=$(ps | grep "$pid.*focus" | grep -v grep | wc -l)
  while [ "$num_processes" -ge "1" ]; do
    $SLEEP 1
    num_processes=$(ps | grep "$pid.*focus" | grep -v grep | wc -l)
  done
}

# On Ctrl+C, print the score and exit

if [[ "$1" == "start" ]]; then
  if [[ -f $PID_FILE ]]; then
    echo "Focus already running"
    exit 1
  fi
  touch $PID_FILE
  track_focus & 
  pid=$!
  echo "$pid" > $PID_FILE
elif [[ "$1" == "stop" ]]; then
  if [[ -f $PID_FILE ]]; then
    pid=$(cat $PID_FILE)
    echo "Stopping focus at pid $pid"
    rm $PID_FILE
    wait_for_process $pid
    echo "Process stopped"
    cat $OUTPUT_FILE
  else
    echo "No focus process running"
    exit 1
  fi
else
  echo "Usage: focus [start|stop]"
  exit 1
fi
