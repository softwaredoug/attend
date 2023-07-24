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



track_focus() {

  # loop forever, sleep for 1 second
  while true; do
      sleep 0.1
      # get the focused app
      focus=$(osascript focusedapp.scpt)
      focus=$(focus_name "$focus")
      # if the focused app is not the same as the last focused app
      if [ "$focus" != "$lastfocus" ]; then
          # play unpleasant sound
          afplay /System/Library/Sounds/Funk.aiff & 
          # if the last focused app is not empty
          if [ "$lastfocus" != "" ]; then
              # get the current time in milliseconds
              time=$(gdate +"%s%3N" )
              # calculate the time spent on the last focused app
              let "time = $time - $lasttime"
              # if the time spent is greater than 0
              if [ "$time" -gt "0" ]; then
                  # print the time spent on the last focused app
                  echo "$lastfocus $time"
              fi
          fi
          # set the last focused app to the current focused app
          lastfocus=$focus
          # set the last time to the current time
          lasttime=$(gdate +"%s%3N")
      fi
  done
}

track_focus
