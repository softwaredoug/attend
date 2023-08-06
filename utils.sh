#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "$SCRIPT_DIR"/log.sh

compute() {
  echo "$@" | bc -l
  if [ $? -ne 0 ]; then
    local calling_line_info=$(caller 0)
    local calling_line=${calling_line_info% *}
    log "🚨 Error computing $@"
    log "    at line $calling_line"
  fi
}

check() {
  # Perform boolean check
  # ie bc for a > b
  # Capture stderr to check for errors
  err_check=$(echo "$@" | bc 2>&1)
  err_len=${#err_check}
  # if err_check longer than 0, then there was an error
  if [[ "$err_len" -gt "4" ]]; then
    local calling_line_info=$(caller 0)
    local calling_line=${calling_line_info% *}
    log "🚨 Error checking $@"
    log "    at line $calling_line"
    log "    error: $err_check"
  fi
  check=$(echo "$@" | bc)
  if [[ "$check" -eq "1" ]]; then
    return 0
  fi
  return 1
}

approx() {
  value=$1
  expected_value=$2
  delta=$3
  if [[ $delta == "" ]]; then
    delta=0.05
  fi

  if check "$value >= $expected_value - $delta"; then
    if check "$value <= $expected_value + $delta"; then
      return 0
    fi
  fi
  return 1
}

assert() {
  if check "$1"; then
    return
  else
    local calling_line_info=$(caller 0)
    local calling_line=${calling_line_info% *}
    log "🚨 Assertion failed $@"
    log "    at line $calling_line"
    log "    $2"
    exit_attend
  fi
}

wait_for_process() {
  pid=$1
  name=$2
  num_processes=$(ps | grep "$pid.*$name" | grep -v grep | wc -l)
  while [ "$num_processes" -ge "1" ]; do
    sleep 0.1
    which_processes=$(ps | grep "$pid.*$name" | grep -v grep)
    num_processes=$(ps | grep "$pid.*$name" | grep -v grep | wc -l)
  done
}

trim() {
    local var=$1
    var="${var#"${var%%[![:space:]]*}"}"   # Remove leading whitespace
    var="${var%"${var##*[![:space:]]}"}"   # Remove trailing whitespace
    echo -n "$var"
}

num_lines() {
  if [[ -f "$1" ]]; then
    file_wc=$(cat "$1" | wc -l)
    echo $(trim "$file_wc")
  else
    echo 0
  fi
}

confirm() {
    read -r -p "${1:-Are you sure? [Y/n]} " response
    case "$response" in
        [yY][eE][sS]|[yY]|"")
            true  # Return true (0) if "Yes" or empty input
            ;;
        [nN][oO]|[nN])
            false  # Return false (1) if "No"
            ;;
        *)
            # Invalid input; prompt again
            echo "Invalid input. Please enter Y or N."
            confirm "$1"
            ;;
    esac
}

duration_arg_to_mins() {
  time_arg="$1"

  if [[ "$time_arg" == "" ]]; then
    echo "Please specify a time"
    return 1
  fi

  # Duration ends with h, m, or s
  if [[ "$time_arg" =~ ^[0-9]+[hms]$ ]]; then
    # Strip off the last character
    value=${time_arg%?}
    units="${time_arg: -1}"

    if [[ "$units" == "h" ]]; then
      compute "$value * 60"
      return
    elif [[ "$units" == "s" ]]; then
      compute "$value / 60"
      return
    else
      echo $value
      return 
    fi
  # Otherwise its a number...
  elif [[ "$time_arg" =~ ^[0-9]+$ ]]; then
    echo "$time_arg"
    return
  # Otherwise its invalid
  else
    echo "Please specify a valid time"
    return 1
  fi
}

to_int() {
  # Remove period and after from string using parameter subst.
  # ie 1.5 -> 1
  trunced=${1%%.*}
  # If trunked empty, give 0 as .2 -> ""
  if [[ "$trunced" == "" ]]; then
    trunced=0
  fi
  echo "$trunced"
}
