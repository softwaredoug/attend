#!/usr/bin/env bash

OUTPUT_FILE="/tmp/attend_output.txt"
PID_FILE="/tmp/attend_process.pid"
LOG_FILE="/tmp/attend_log.txt"
IDLE_TIME_FILE="/tmp/total_idle_time"

. ./utils.sh

mock() {
  cp test/command_mock.sh $1_mock
}

clean_mock() {
  rm $1_mock
  rm -f ".last_$1_mock"_args

}

clean_fixtures() {
  for mock in ${MOCKS[@]}; do
    clean_mock $mock
  done
  rm -f $OUTPUT_FILE
  rm -f $PID_FILE
  rm -f $LOG_FILE
  return
}

MOCKS=('idle' 'focus' 'sleep' 'afplay' 'gdate' 'idle_sys')


fixtures() {
  for mock in ${MOCKS[@]}; do
    mock $mock
  done
  echo "0" > $IDLE_TIME_FILE
}

resp_on_call_count() {
  on_call_count=$1
  cmd=$2
  mock_script=$3
  echo 'if [ $call_count -eq '$on_call_count' ]; then ' >> $mock_script
  echo "  $cmd" >> $mock_script
  echo 'fi' >> $mock_script
}

wait_for_num_calls() {
  call_count=$1
  mock_script=$2
  mock_args_file=".last_$mock_script"_args
  while [[ $(num_lines $mock_args_file) -lt "$call_count" ]]; do
    sleep 0.01
  done
}

resp_on_call_count_gte() {
  on_call_count=$1
  cmd=$2
  mock_script=$3
  echo 'if [ $call_count -ge '$on_call_count' ]; then ' >> $mock_script
  echo "  $cmd" >> $mock_script
  echo 'fi' >> $mock_script
}

on_any_call() {
  cmd=$1
  mock_script=$2
  echo $cmd >> $mock_script
}

default_returns() {
  on_any_call 'echo "Terminal"' focus_mock
  on_any_call ' if [[ "$1" == "+%s%3N" ]]; then echo "1000"; fi' gdate_mock
  on_any_call ' if [[ "$1" == "+%Y-%m-%dT%H:%M:%S" ]]; then echo "2018-01-01T00:00"; fi' gdate_mock
  
  resp_on_call_count_gte 1 "echo "0" > $IDLE_TIME_FILE" idle_mock
}

poor_focus() {
  begin_focus=1000
  focus_incr=500
  resp_on_call_count 1 'if [[ "$1" == "+%s%3N" ]]; then echo "'$begin_focus'"; fi' gdate_mock
  on_any_call ' if [[ "$1" == "+%Y-%m-%dT%H:%M:%S" ]]; then echo "2018-01-01T00:00"; fi' gdate_mock
  resp_on_call_count_gte 2 ' if [[ "$1" == "+%s%3N" ]]; then let "next_focus = '$begin_focus' + ($call_count * '$focus_incr')"; echo "$next_focus"; fi' gdate_mock

  resp_on_call_count 1 'echo "Google Chrome || https://www.google.com/"' focus_mock
  resp_on_call_count 2 'echo "Terminal"' focus_mock
  resp_on_call_count 3 'echo "Google Chrome || https://www.google.com/"' focus_mock
  resp_on_call_count 4 'echo "Terminal"' focus_mock
  resp_on_call_count 5 'echo "Google Chrome || https://www.google.com/"' focus_mock
  resp_on_call_count 6 'echo "Terminal"' focus_mock
  
  resp_on_call_count_gte 1 "echo "0" > $IDLE_TIME_FILE" idle_mock
}

single_focus_at_length() {
  focus_ms=$(echo "$1 * 1000" | bc)
  begin_focus=1000
  end_focus=$(echo "$focus_ms + $begin_focus" | bc)
  end_run=$(echo "$end_focus + 1001" | bc)
  resp_on_call_count 1 'if [[ "$1" == "+%s%3N" ]]; then echo "'$begin_focus'"; fi' gdate_mock
  resp_on_call_count 2 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_focus'"; fi' gdate_mock
  resp_on_call_count 3 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_run'"; fi' gdate_mock
  on_any_call ' if [[ "$1" == "+%Y-%m-%dT%H:%M:%S" ]]; then echo "2018-01-01T00:00"; fi' gdate_mock
  resp_on_call_count_gte 4 ' if [[ "$1" == "+%s%3N" ]]; then echo "'$end_run'"; fi' gdate_mock

  resp_on_call_count 1 'echo "Google Chrome || https://www.google.com/"' focus_mock
  resp_on_call_count 2 'echo "Terminal"' focus_mock
  resp_on_call_count_gte 3 'echo "Youdontwannaknow"' focus_mock
  
  resp_on_call_count_gte 1 "echo "0" > $IDLE_TIME_FILE" idle_mock
}


single_focus_all_idle() {
  focus_ms=$(echo "$1 * 1000" | bc)
  begin_focus=0
  end_focus=$(echo "$focus_ms + $begin_focus" | bc)
  end_run=$(echo "$end_focus + 1001" | bc)

  end_focus_secs=$(echo "$end_focus / 1000" | bc)
  end_run_secs=$(echo "$end_run / 1000" | bc)

  resp_on_call_count 1 'if [[ "$1" == "+%s%3N" ]]; then echo "'$begin_focus'"; fi' gdate_mock
  resp_on_call_count 2 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_focus'"; fi' gdate_mock
  resp_on_call_count 2 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_focus_secs'" > '$IDLE_TIME_FILE'; fi' gdate_mock
  resp_on_call_count 3 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_run'"; fi' gdate_mock
  resp_on_call_count 3 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_focus_secs'" > '$IDLE_TIME_FILE'; fi' gdate_mock
  on_any_call ' if [[ "$1" == "+%Y-%m-%dT%H:%M:%S" ]]; then echo "2018-01-01T00:00"; fi' gdate_mock
  resp_on_call_count_gte 4 ' if [[ "$1" == "+%s%3N" ]]; then echo "'$end_run'"; fi' gdate_mock

  resp_on_call_count 1 'echo "Google Chrome || https://www.google.com/"' focus_mock
  resp_on_call_count 2 'echo "Terminal"' focus_mock
  resp_on_call_count_gte 3 'echo "Youdontwannaknow"' focus_mock
 
  resp_on_call_count_gte 1 "echo "0" > $IDLE_TIME_FILE" idle_mock
}


two_apps_focused_at_length() {
  focus_ms=$(echo "$1 * 1000" | bc)
  begin_focus=1000
  end_focus=$(echo "$begin_focus + $focus_ms" | bc)
  end_focus2=$(echo "$begin_focus + (2 * $focus_ms)" | bc)
  end_run=$(echo "$end_focus2 + 1001" | bc)

  resp_on_call_count 1 'if [[ "$1" == "+%s%3N" ]]; then echo "'$begin_focus'"; fi' gdate_mock
  resp_on_call_count 2 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_focus'"; fi' gdate_mock
  resp_on_call_count 3 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_focus2'"; fi' gdate_mock
  resp_on_call_count 4 'if [[ "$1" == "+%s%3N" ]]; then echo "'$end_run'"; fi' gdate_mock
  on_any_call ' if [[ "$1" == "+%Y-%m-%dT%H:%M:%S" ]]; then echo "2018-01-01T00:00"; fi' gdate_mock
  resp_on_call_count_gte 5 ' if [[ "$1" == "+%s%3N" ]]; then echo "'$end_run'"; fi' gdate_mock

  resp_on_call_count 1 'echo "Google Chrome || https://www.google.com/"' focus_mock
  resp_on_call_count 2 'echo "Terminal"' focus_mock
  resp_on_call_count_gte 3 'echo "Youdontwannaknow"' focus_mock
  
  resp_on_call_count_gte 1 "echo "0" > $IDLE_TIME_FILE" idle_mock
}


get_stat() {
  stat=$1
  line=$(cat $OUTPUT_FILE | grep "^$1")
  [[ $line =~ ^$1:\ (.*)$ ]] && echo "${BASH_REMATCH[1]}"
}

clean_number() {
  number=$1
  number=$(echo $number | sed 's/,//g')

  # Add 0 if begins with .
  if [[ $number =~ ^\.[0-9]+ ]]; then
    number=$(echo "0$number")
  fi
  echo $number
}

check_gt() {
  first=$(clean_number "$1")
  second=$(clean_number "$2")
  if [[ $(echo "$first > $second" |bc -l) == 1 ]]; then
    return 0
  else
    return 1
  fi
}

check_lt() {
  first=$(clean_number "$1")
  second=$(clean_number "$2")
  if [[ $(echo "$first < $second" |bc -l) == 1 ]]; then
    return 0
  else
    return 1
  fi
}


test_attend_produces_output() {
  default_returns

  ./attend.sh start
  ./attend.sh stop
  if [[ -f $OUTPUT_FILE ]]; then
    return 0
  else
    return 1
  fi
}

test_attend_keeps_output() {
  default_returns

  ./attend.sh start
  ./attend.sh stop
  wc_first=$(cat $OUTPUT_FILE | wc -l)
  ./attend.sh start
  ./attend.sh stop
  wc_second=$(cat $OUTPUT_FILE | wc -l)
  if [[ $wc_first -lt $wc_second ]]; then
    return 0
  else
    return 1
  fi
}

test_attend_long_focus_scores_near_actual_time() {
  single_focus_at_length 3000
  ./attend.sh start
  ./attend.sh stop
  max_score=$(get_stat "Max focus score")
  check_gt $max_score 2900
  if [[ $? -ne 0 ]]; then
    echo "gt max_score: $max_score > 2900"
    return 1
  fi
  check_lt $max_score 3100
  if [[ $? -ne 0 ]]; then
    echo "lt max_score: $max_score < 3100"
    return 1
  fi
}

test_attend_long_focus_all_idle() {
  single_focus_all_idle 3000
  ./attend.sh start
  sleep 1
  ./attend.sh stop
  max_score=$(get_stat "Max focus score")

  if ! approx $max_score 0 0.3; then
    echo "max_score: $max_score != 0"
    return 1
  fi
}

test_attend_two_long_focus_scores_near_actual_time() {
  two_apps_focused_at_length 3000
  expected_score=6000
  ./attend.sh start
  ./attend.sh stop
  max_score=$(get_stat "Max focus score")
  check_gt $max_score $(echo "$expected_score - 100" | bc)
  if [[ $? -ne 0 ]]; then
    echo "gt max_score: $max_score > 2900"
    return 1
  fi
  check_lt $max_score $(echo "$expected_score + 100" | bc)
  if [[ $? -ne 0 ]]; then
    echo "lt max_score: $max_score < 3100"
    return 1
  fi
}

test_attend_two_long_focus_scores_near_full_percentage() {
  two_apps_focused_at_length 3000
  expected_percentage_gt=99.5
  ./attend.sh start
  ./attend.sh stop
  percentage=$(get_stat "Effective focus %")
  check_gt $percentage $expected_percentage_gt
  return $?
}

test_attend_tracks_longest_app() {
  single_focus_at_length 3000
  ./attend.sh start
  ./attend.sh stop
  longest_app=$(get_stat "Most focused app")
  echo "longest_app: $longest_app"
  if [[ $longest_app != "Google Chrome || https://www.google.com/ " ]]; then
    return 1
  fi
}

test_attend_short_focus_scores_a_lot_less_than_time() {
  single_focus_at_length 1
  ./attend.sh start
  wait_for_num_calls 4 "gdate_mock"
  ./attend.sh stop
  max_score=$(get_stat "Max focus score")
  check_lt "$max_score" "1"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

test_attend_output_missing_log() {
  single_focus_at_length 3000
  ./attend.sh start
  wait_for_num_calls 4 "gdate_mock"
  ./attend.sh stop
  cat $OUTPUT_FILE | grep -q "LOG START"
  success=$?
  if [[ $success -eq 0 ]]; then
    return 1
  fi
}

test_detects_new_high_score_on_empty_log() {
  single_focus_at_length 3000
  ./attend.sh start
  wait_for_num_calls 4 "gdate_mock"
  ./attend.sh stop
  cat $OUTPUT_FILE | grep -q "New high max score"
  return $?
}

test_detects_new_high_score() {
  # last two values avg, max
  echo "2023-07-25T15:40:54 2023-07-25T15:40:54 1690314060763 6 1 124.2428 4 1.45864784059431617247 0.36466196014857904311 0.87642818572655602893 My_longest_app" > $LOG_FILE
  cat $LOG_FILE
  single_focus_at_length 3000
  ./attend.sh start
  wait_for_num_calls 4 "gdate_mock"
  ./attend.sh stop
  cat $OUTPUT_FILE | grep -q "New high max score"
  return $?
}

test_detects_new_high_ratios() {
  this_session_length_secs=1200.0
  this_session_length_mins=$(echo "$this_session_length_secs / 60.0" | bc)
  this_idle_time=100.0
  this_effective_secs=100.0
  echo "2023-07-25T15:40:54 2023-07-25T15:40:54 1690314060763 6 $this_session_length_secs $this_idle_time $this_effective_secs 0.36466196014857904311 0.87642818572655602893 My_longest_app" > $LOG_FILE

  new_session_length_secs=3000
  new_session_length_mins=$(echo "$new_session_length_secs / 60.0" | bc)
  single_focus_at_length $new_session_length_secs
  ./attend.sh start
  wait_for_num_calls 4 "gdate_mock"
  ./attend.sh stop
  reporting_minutes=(5 10 20 30 45 60 90 120)
  for min_length in "${reporting_minutes[@]}"; do
    if [[ $new_session_length_mins -ge $min_length ]]; then
      echo "Check for high score... for $min_length"
      cat $OUTPUT_FILE | grep -q " New high score for $min_length min session! -- $work_ratio"
      success=$?
    else
      cat $OUTPUT_FILE | grep -q " New high score for $min_length min session! -- $work_ratio"
      found=$?
      [[ "$found" != 0 ]]
      success=$?
    fi
    echo "success: $success"
    if [[ $success -ne 0 ]]; then
      echo "failed for $min_length"
      return 1
    fi
  done
}

test_does_not_detect_high_ratios() {
  echo "2023-07-25T15:40:54 2023-07-25T15:40:54 1690314060763 1210.0 6 1200.0 100.0 100.0 0.36466196014857904311 0.87642818572655602893 app sess_name" > $LOG_FILE
  echo "2018-01-01T00:00 2018-01-01T15:40:54 3002001 3001 0 2 3000.99875332642988461642 1500.49937666321494230821 3000.99875332642988461642 an_app sess_name" >> $LOG_FILE

  poor_focus
  ./attend.sh start
  wait_for_num_calls 3 "gdate_mock"
  ./attend.sh stop
  reporting_minutes=(5 10 20 30 45 60 90 120)
  for min_length in "${reporting_minutes[@]}"; do
    # no records should be set
    cat $OUTPUT_FILE | grep -q " New high score for $min_length min session! -- $work_ratio"
    found=$?
    [[ "$found" != 0 ]]
    success=$?
    echo "success: $success"
    if [[ $success -ne 0 ]]; then
      echo "failed for $min_length"
      return 1
    fi
  done
  cat $LOG_FILE > test_log.txt
}

test_appends_to_existing_log() {
  # last two values avg, max
  echo "2023-07-25T15:40:54 1690314060763 6 124.2428 4 1.45864784059431617247 0.36466196014857904311 0.87642818572655602893 app sess_name" > $LOG_FILE
  single_focus_at_length 3000
  ./attend.sh start
  ./attend.sh stop
  wc -l $LOG_FILE | grep -q "2"
  return $?
}

test_prints_work_session_name() {
  single_focus_at_length 3000
  ./attend.sh start "my task to do the thing"
  ./attend.sh stop
  cat $OUTPUT_FILE | grep -q "my task"
  return $?
}

test_logging_disabled() {
  single_focus_at_length 3000
  ./attend.sh stop | grep -q "LOGGING ENABLED"
  if [[ $? -ne 1 ]]; then
    return 1
  fi
}

test_logs_work_session_name() {
  single_focus_at_length 3000
  ./attend.sh start "my task to do the thing"
  ./attend.sh stop
  cat $LOG_FILE | grep -q "my_task"
  return $?
}

test_logs_max_app_name() {
  single_focus_at_length 3000
  ./attend.sh start
  ./attend.sh stop
  cat $LOG_FILE | grep -q "Google_Chrome"
  return $?
}

test_doesnt_detect_high_if_not_higher() {
  # last two values avg, max
  echo "2023-07-25T15:40:54 1690314060763 6 124.2428 4 1.45864784059431617247 0.36466196014857904311 0.87642818572655602893 app sess_name" > $LOG_FILE
  cat $LOG_FILE
  single_focus_at_length 1
  ./attend.sh start
  wait_for_num_calls 3 "gdate_mock"
  ./attend.sh stop
  cat $OUTPUT_FILE | grep -vq "New high max score"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

test_idle() {
  resp_on_call_count 1 'echo "1"' idle_sys_mock
  resp_on_call_count 2 'echo "2"' idle_sys_mock
  resp_on_call_count_gte 3 'echo "3"' idle_sys_mock

  ./idle.sh 1 &
  IDLE_PID=$!
  wait_for_num_calls 4 "idle_sys_mock"
  idle_time=$(cat $IDLE_TIME_FILE)
  rm $IDLE_TIME_FILE
  wait_for_process $IDLE_PID

  if ! approx "$idle_time" 3.0; then
    echo "idle time was $idle_time"
    return 1
  fi
}

test_idle_ignores_less_than_check_freq() {
  resp_on_call_count 1 'echo "0.5"' idle_sys_mock
  resp_on_call_count 2 'echo "0.4"' idle_sys_mock
  resp_on_call_count_gte 3 'echo "0.4"' idle_sys_mock

  ./idle.sh 1 &
  IDLE_PID=$!
  wait_for_num_calls 4 "idle_sys_mock"
  idle_time=$(cat $IDLE_TIME_FILE)
  rm $IDLE_TIME_FILE
  wait_for_process $IDLE_PID

  if ! approx "$idle_time" 0.0; then
    echo "idle time was $idle_time"
    return 1
  fi
}

test_idle_accumulates_only_idles_above_check_freq() {
  resp_on_call_count 1 'echo "0.5"' idle_sys_mock
  resp_on_call_count 2 'echo "1.1"' idle_sys_mock
  resp_on_call_count_gte 3 'echo "0.4"' idle_sys_mock

  ./idle.sh 1 &
  IDLE_PID=$!
  wait_for_num_calls 4 "idle_sys_mock"
  idle_time=$(cat $IDLE_TIME_FILE)
  rm $IDLE_TIME_FILE
  wait_for_process $IDLE_PID

  if ! approx "$idle_time" 1.1; then
    echo "idle time was $idle_time"
    return 1
  fi
}

test_idle_accumulates_but_resets() {
  resp_on_call_count 1 'echo "1.1"' idle_sys_mock
  resp_on_call_count 2 'echo "2.1"' idle_sys_mock
  resp_on_call_count 3 'echo "3.1"' idle_sys_mock
  resp_on_call_count 4 'echo "0.0"' idle_sys_mock
  resp_on_call_count 5 'echo "1.1"' idle_sys_mock
  resp_on_call_count 6 'echo "2.1"' idle_sys_mock
  resp_on_call_count 7 'echo "3.1"' idle_sys_mock
  resp_on_call_count_gte 8 'echo "0.0"' idle_sys_mock

  ./idle.sh 1 &
  IDLE_PID=$!
  wait_for_num_calls 9 "idle_sys_mock"
  idle_time=$(cat $IDLE_TIME_FILE)
  rm $IDLE_TIME_FILE
  wait_for_process $IDLE_PID

  if ! approx "$idle_time" 6.2; then
    echo "idle time was $idle_time"
    return 1
  fi
}

###########################################
# Run all functions that start with "test_"
functions=$(declare -F | grep "^declare -f test_")
TESTS=()
while read -r line; do
    function_name=${line#"declare -f "}
    TESTS+=("$function_name")
done <<< "$functions"

length=${#1}
last_character=${1:length-1:1}

# if $1 ends with *, get all tests that start with prefix
if [[ "$last_character" == "*" ]]; then
  trimmed=${1%?}
  NEW_TESTS=()
  for test in ${TESTS[@]}; do
    if [[ $test == $trimmed* ]]; then
      NEW_TESTS+=("$test")
    fi
  done
  echo "running only tests: ${NEW_TESTS[@]}"
  TESTS=("${NEW_TESTS[@]}")
elif [ $# -gt 0 ]; then
  TESTS=("$@")
fi

for test in ${TESTS[@]}; do
  fixtures
  $test
  success=$?
  clean_fixtures
  if [ $success -ne 0 ]; then
    echo "$test failed"
    echo "❌ $test"
    echo "DONE... cleaning up"
    exit 1
  fi
  echo "✅ $test"
done
