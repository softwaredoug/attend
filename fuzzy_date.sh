#!/bin/bash

# Function to get midnight timestamp of a date
midnight_timestamp() {
    local formatted_date="$1"
    local timestamp
    timestamp=$(gdate -d "$formatted_date" +%s)
    echo "$timestamp"
}


is_date_a_sunday() {
  local formatted_date="$1"
  local day_of_week
  day_of_week=$(gdate -d "$formatted_date" +%u)
  if [[ $day_of_week == "7" ]]; then
    echo "true"
  else
    echo "false"
  fi
}


this_monday_midnight() {
  # Monday before today
  midnight_timestamp "$(gdate -d "monday - 1 week" +%Y-%m-%d)"
}

last_monday_midnight() {
  midnight_timestamp "$(gdate -d "monday - 2 week" +%Y-%m-%d)"
}

today_midnight() {
  midnight_timestamp "$(gdate +%Y-%m-%d)"
}

yesterday_midnight() {
  midnight_timestamp "$(gdate -d "yesterday" +%Y-%m-%d)"
}

first_date_of_month() {
  midnight_timestamp "$(gdate -d "$(gdate +%Y-%m-01)" +%Y-%m-%d)"
}

first_sunday_at_before_year() {
  year="$1"
  if [[ $year == "" ]]; then
    year=$(gdate +%Y)
  fi
  date="$year-01-01"

  while [[ $(is_date_a_sunday "$date") == "false" ]]; do
    date=$(gdate -d "$date - 1 day" +%Y-%m-%d)
  done

  midnight_timestamp "$date"
}

fuzzy_date() {
  # Turn just about any natural language date into a unix timestamp
  # Usage: fuzzy_date "last week"
  # Usage: fuzzy_date "2023-01-01"

  local date_string="$1"

  # Get the beginning of any fuzzy argument, such as "tomorrow"
  #
  case "$date_string" in
    today)
      today_midnight
      ;;
    yesterday)
      yesterday_midnight
      ;;
    # Beginning of this current Monday
    week)
      this_monday_midnight
      ;;
    lastweek)
      last_monday_midnight
      ;;
    workyear)
      first_sunday_at_before_year
      ;;
    *)
      date -j -f "%Y-%m-%d" "$date_string" +%s
      ;;
  esac
}

fuzzy_date_range() {
  # Turn a fuzzy date range into a unix timestamp range
  # Usage: fuzzy_date_range "last week"
  # Usage: fuzzy_date_range "2023-01-01"

  local date_string="$1"

  if [[ $date_string == "" ]]; then
    date_string="today"
  fi

  begin=$(fuzzy_date "$date_string")
  case "$date_string" in
    today|yesterday)
      end="86400"  # 24 hours
      ;;
    # Beginning of this current Monday
    week|lastweek)
      # 24 hrs * 5 days
      end="432000"
      ;;
    workyear)
      # One year in seconds
      end="31536000"
      ;;
    *)
      local end_date="$2"
      end=$(fuzzy_date "$end_date")
      ;;
  esac
  echo "$begin $end"
}


# fuzzy_date_range "$@"
