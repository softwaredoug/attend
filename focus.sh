#!/bin/bash

# These apps we can use the window name to get the front tab
# And use that to define the 'focus'
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



TOT_SCORE=0
MAX_SCORE=0
NUM_SWITCHES=0
WORK_BEGIN=$(gdate +"%s%3N")
WORK_BEGIN_TS=$(gdate +"%Y-%m-%dT%H:%M")
LAST_TIME=0
LAST_IDLE=0
TOT_IDLE=0
IDLE_PID=0

update_scores() {
  time=$(gdate +"%s%3N" )
  # calculate the time spent on the last focused app
  idle=$(cat /tmp/total_idle_time)
  this_idle=$(echo "$idle - $LAST_IDLE" | bc)
  let "time = $time - $LAST_TIME"
  if [ "$time" -gt "0" ]; then
    # Add 1.1^time to the score
    time=$(echo "$time - $this_idle" | bc)
    
    this_score=$(echo "1.1^($time / 1000)" | bc)
    TOT_SCORE=$(echo "$TOT_SCORE + 1.1^($time / 1000)" | bc)
    TOT_IDLE=$(echo "$TOT_IDLE + $this_idle" | bc)
    let "NUM_SWITCHES = $NUM_SWITCHES + 1"
    if [ $(echo "$this_score > $MAX_SCORE" | bc) -eq 1 ]; then
      MAX_SCORE=$this_score
    fi
    LAST_IDLE=$idle
  fi
}

track_focus() {
  # Spawn idle time tracker
  ./idle.sh 10 &
  IDLE_PID=$!

  # loop forever, sleep for 1 second
  while true; do
      sleep 0.1
      # get the focused app
      focus=$(osascript focusedapp.scpt 2> /dev/null)
      focus=$(focus_name "$focus")
      # if the focused app is not the same as the last focused app
      if [ "$focus" != "$lastfocus" ]; then
          # play unpleasant sound
          afplay /System/Library/Sounds/Funk.aiff &
          # if the last focused app is not empty
          if [ "$lastfocus" != "" ]; then
              # get the current time in milliseconds
              update_scores "$time"
          fi
          # set the last focused app to the current focused app
          lastfocus=$focus
          # set the last time to the current time
          LAST_TIME=$(gdate +"%s%3N")
      fi
  done
}

ctrl_c() {
  update_scores $time

  kill $IDLE_PID

  work_end=$(gdate +"%s%3N")
  session_length_secs=$(echo "($work_end - $WORK_BEGIN) / 1000" | bc)
  echo ""
  echo "Work session done!"
  # Write date and score to ~/.focus_scores
  # Check the highest score
  highest_avg=$(sort -k8 -n -r ~/.focus_scores 2> /dev/null | head -n 1 | awk '{print $8}')
  highest_max=$(sort -k9 -n -r ~/.focus_scores 2> /dev/null | head -n 1 | awk '{print $9}')
  # If the current score is higher than the highest score

  avg_score=$(echo "$TOT_SCORE / $NUM_SWITCHES" | bc -l)
  echo "You started working at $WORK_BEGIN_TS"
  echo "Work session length: $session_length_secs seconds"
  echo "----"
  echo "Average focus score: $avg_score"
  echo "Max focus score: $MAX_SCORE"
  echo "Num task switches: $NUM_SWITCHES"
  echo "Total idle time: $TOT_IDLE"

  echo "----"
  echo "Highest average score: $highest_avg"
  echo "Highest     max score: $highest_max"

  if [ ! -f ~/.focus_scores ]; then
    touch ~/.focus_scores
  else
    if [ $(echo "$avg_score > $highest_avg" | bc) -eq 1 ]; then
      echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉"
      echo "New high average score! -- $avg_score"
      afplay ./tada.mp3 &
    fi
    
    if [ $(echo "$MAX_SCORE > $highest_max" | bc) -eq 1 ]; then
      echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉"
      echo "New high max score! -- $MAX_SCORE"
      afplay ./tada.mp3 &
    fi
  fi
  echo "$(gdate +"%Y-%m-%dT%H:%M") $WORK_BEGIN_TS $work_end $session_length_secs $TOT_IDLE $NUM_SWITCHES $TOT_SCORE $avg_score $MAX_SCORE " >> ~/.focus_scores
  exit 0
}


# On Ctrl+C, print the score and exit
trap ctrl_c INT

track_focus
