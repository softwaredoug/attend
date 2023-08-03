#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "$SCRIPT_DIR"/fuzzy_date.sh
. "$SCRIPT_DIR"/utils.sh


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

legend() {
  max_time="$1"

  twenty_fifth=$(to_int $(compute "0.25 * $max_time"))
  fiftieth=$(to_int $(compute "0.5 * $max_time"))
  seventy_fifth=$(to_int $(compute "0.75 * $max_time"))

  echo "Legend (mins)"
  echo "  no data"
  echo "$light_shade 0-$twenty_fifth mins"
  echo "$med_shade $twenty_fifth-$fiftieth mins"
  echo "$dark_shade $fiftieth-$seventy_fifth mins"
  echo "$full_box $seventy_fifth-$max_time mins"
  echo "$full_box > $max_time mins"
}


#
# Display a vertical calendar 
# of intensities per day
# arguments are
#  - begin_ts -> unix timestamp of first value
#  remainder of args a list of percentage values to display
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
    start_ts=$((start_ts + 86400))

    if [[ $start_ts -lt $begin_display_ts ]]; then
      continue
    fi

    if [[ $start_ts -gt $now ]]; then
      break
    fi
    
    day_of_week=$(gdate -d "@$start_ts" +%u)
    day_of_month=$(gdate -d "@$start_ts" +%d)
    name_of_month=$(gdate -d "@$start_ts" +%B)
    name_of_month_short=$(gdate -d "@$start_ts" +%b)

    # Header
    if [[ $first_line == true ]]; then
      echo ""
      echo "       Su Mo Tu We Th Fr Sa"
      echo -n "$name_of_month_short $day_of_month"
    fi


    # Wrap on Sunday
    if [[ $day_of_week == "7" ]]; then
      echo ""
      echo -n "    $day_of_month"
      echo -n " "
    fi
    first_line=false

    # Wrap on first of month
    if [[ "$day_of_month" == "01" ]]; then
      # three spaces per day of week
      echo ""
      echo ""
      echo "       Su Mo Tu We Th Fr Sa"
      echo -n "$name_of_month_short 01 "
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
}


# calendar "${@}"
