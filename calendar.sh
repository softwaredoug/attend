#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "$SCRIPT_DIR"/fuzzy_date.sh


empty_box=" "
light_shade="░"
med_shade="▒"
dark_shade="▓"
full_box="█"


intensity_from_percentage() {
  local percentage="$1"
  local intensity
  if [[ $percentage -eq 0 ]]; then
    intensity="$empty_box"
  elif [[ $percentage -lt 25 ]]; then
    intensity="$light_shade"
  elif [[ $percentage -lt 50 ]]; then
    intensity="$med_shade"
  elif [[ $percentage -lt 75 ]]; then
    intensity="$dark_shade"
  else
    intensity="$full_box"
  fi
  echo "$intensity"
}


calendar() {
  start_ts=$(fuzzy_date_range "workyear" | awk '{print $1}')
  range_end=$(fuzzy_date_range "workyear" | awk '{print $2}')
  range_end=$((range_end + start_ts))


  intensities=("${@}")
  begin_data_ts="$1"
  # Subtract 7 days from begin_ts
  begin_display_ts=$((begin_data_ts - 604800))
  now=$(date +%s)
  idx=1
  first_line=true


  # Iterate every day of year up to range_end
  while [[ $start_ts -lt $range_end ]]; do
    # Get day of week
    day_of_week=$(gdate -d "@$start_ts" +%u)
    day_of_month=$(gdate -d "@$start_ts" +%d)
    name_of_month=$(gdate -d "@$start_ts" +%B)
    name_of_month_short=$(gdate -d "@$start_ts" +%b)
    start_ts=$((start_ts + 86400))

    if [[ $start_ts -lt $begin_display_ts ]]; then
      continue
    fi

    if [[ $start_ts -gt $now ]]; then
      break
    fi

    # Header
    if [[ $first_line == true ]]; then
      first_line=false
      echo "    Su Mo Tu We Th Fr Sa"
      echo -n "$name_of_month_short"
    fi


    # Wrap on Sunday
    if [[ $day_of_week == "7" ]]; then
      echo ""
      echo -n $day_of_month
      echo -n "  "
    fi

    # Wrap on first of month
    if [[ "$day_of_month" == "01" ]]; then
      # three spaces per day of week
      echo ""
      echo -n "$name_of_month_short"
      echo ""
      echo -n "01  "
      for i in {1..6}; do
        if [[ $i -gt $day_of_week ]]; then
          break
        fi
        echo -n "   "
      done

    fi

    intensity=" "
    if [[ $start_ts -ge $begin_data_ts ]]; then
      intensity=$(intensity_from_percentage "${intensities[$idx]}")
      idx=$((idx + 1))
    fi
    echo -n "$intensity$intensity$intensity"
  done
  echo

  # Get day of week
  # day_of_week=$(gdate -d "$start_ts" +%u)

  # Get day of month
  # day_of_month=$(gdate -d "$start_ts" +%d)
}


# calendar "${@}"
