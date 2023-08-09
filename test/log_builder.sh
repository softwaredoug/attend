#!/bin/zsh

INIT_DATE="2018-01-01T00:00:00"

GDATE_CMD="date"

if [[ $(uname) == "Darwin" ]]; then
  GDATE_CMD="gdate"
fi

log_line() {
  last_line="$1"

  start_date="$INIT_DATE"
  if [[ $last_line != "" ]]; then 
    start_date=$(echo $last_line | awk '{ print $2 }')
    start_date_unix=$($GDATE_CMD -u -d "$start_date" +"%s")
    start_date_unix=$(($start_date_unix + 2000))
    start_date=$($GDATE_CMD -u -d "@$start_date_unix" +"%Y-%m-%dT%H:%M:%S")
  fi

  start_date_unix=$($GDATE_CMD -u -d "$start_date" +"%s")
  end_date_unix=$(($start_date_unix + 1800))

  # Format again
  end_date=$($GDATE_CMD -u -d "@$end_date_unix" +"%Y-%m-%dT%H:%M:%S")
  end_date_unix_ms=$(($end_date_unix * 1000))

  session_len_secs=$(($end_date_unix - $start_date_unix))

  echo "$end_date $start_date $end_date_unix_ms $session_len_secs 100 6 100.0 0.36466196014857904311 0.87642818572655602893 My_longest_app sess_name"
  start_date=$($GDATE_CMD -u -d "@$start_date_unix" +"%Y-%m-%dT%H:%M:%S")
}

replace_nth_column_with() {
  line=$1
  value=$2
  n=$3
  echo $line | awk -v n=$n -v value=$value '{ $n = value; print }'
}

with_work_end_ts() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 1
}

with_work_begin_ts() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 2
}

with_session_length_secs() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 4
}

with_idle_time() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 5
}

with_num_switches() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 6
}

with_effective_secs() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 7
}

with_avg_score() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 8
}

with_max_score() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 9
}

with_max_app_no_ws() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 10
}

with_session_name_no_ws() {
  line=$1
  value=$2
  replace_nth_column_with "$line" "$value" 11
}
