#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "$SCRIPT_DIR"/fuzzy_date.sh
. "$SCRIPT_DIR"/utils.sh

GDATE_CMD="date"

if [[ $(uname) == "Darwin" ]]; then
  GDATE_CMD="gdate"
fi

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
#  - begin_unix -> unix timestamp of first value
#  remainder of args a list of percentage values to display
calendar() {
  start_unix=$(fuzzy_date_range "workyear" | awk '{print $1}')
  range_end=$(fuzzy_date_range "workyear" | awk '{print $2}')
  range_end=$((range_end + start_unix))


  intensities=("${@}")
  begin_data_unix="$1"
  # Round begin data to beginning of day
  begin_data_unix=$((begin_data_unix - (begin_data_unix % 86400)))
  # Subtract 7 days from begin_unix
  begin_display_unix=$((begin_data_unix - 604800))
  now=$(date +%s)
  idx=1
  first_line=true


  # Iterate every day of year up to range_end
  while [[ $start_unix -lt $range_end ]]; do
    # Get day of week
    start_unix=$((start_unix + 86400))

    if [[ $start_unix -lt $begin_display_unix ]]; then
      continue
    fi

    if [[ $start_unix -gt $now ]]; then
      break
    fi
    
    day_of_week=$($GDATE_CMD -d "@$start_unix" +%u)
    day_of_month=$($GDATE_CMD -d "@$start_unix" +%d)
    name_of_month=$($GDATE_CMD -d "@$start_unix" +%B)
    name_of_month_short=$($GDATE_CMD -d "@$start_unix" +%b)

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
    # echo "start_unix: $start_unix"
    # echo "begin_data_unix: $begin_data_unix"
    if [[ $start_unix -ge $begin_data_unix ]]; then
      intensity=$(intensity_from_percentage "${intensities[$idx]}")
      idx=$((idx + 1))
    fi
    echo -n "$intensity$intensity$intensity"
    if [[ $idx -ge ${#intensities[@]} ]]; then
      break
    fi
  done
  echo
}


# calendar "${@}"
