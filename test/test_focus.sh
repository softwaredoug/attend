#!/usr/bin/env bash

OUTPUT_FILE="/tmp/focus_output.txt"
PID_FILE="/tmp/focus_process.pid"
LOG_FILE="/tmp/focus_log.txt"
IDLE_TIME_FILE="/tmp/total_idle_time"

mock() {
  cp test/command_mock.sh $1_mock
  rm -f ".last_$1_mock"_args
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

MOCKS=('idle' 'focus' 'sleep' 'afplay' 'gdate')


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


test_focus_produces_output() {
  default_returns

  ./focus.sh start
  sleep 1
  ./focus.sh stop
  if [[ -f $OUTPUT_FILE ]]; then
    return 0
  else
    return 1
  fi
}

test_focus_long_focus_scores_near_actual_time() {
  single_focus_at_length 3000
  ./focus.sh start
  sleep 1
  ./focus.sh stop
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

test_focus_tracks_longest_app() {
  single_focus_at_length 3000
  ./focus.sh start
  sleep 1
  ./focus.sh stop
  longest_app=$(get_stat "Most focused app")
  echo "longest_app: $longest_app"
  if [[ $longest_app != "Google Chrome || https://www.google.com/" ]]; then
    return 1
  fi
}

test_focus_short_focus_scores_a_lot_less_than_time() {
  single_focus_at_length 1
  ./focus.sh start
  ./focus.sh stop
  max_score=$(get_stat "Max focus score")
  check_lt "$max_score" "1"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

test_focus_output_missing_log() {
  single_focus_at_length 3000
  ./focus.sh start
  ./focus.sh stop
  cat $OUTPUT_FILE | grep -q "LOG START"
  success=$?
  if [[ $success -eq 0 ]]; then
    return 1
  fi
}

test_detects_new_high_score_on_empty_log() {
  single_focus_at_length 3000
  ./focus.sh start
  ./focus.sh stop
  cat $OUTPUT_FILE | grep -q "New high max score"
  return $?
}

test_detects_new_high_score() {
  # last two values avg, max
  echo "2023-07-25T15:40:54 1690314060763 6 124.2428 4 1.45864784059431617247 0.36466196014857904311 0.87642818572655602893" > $LOG_FILE
  single_focus_at_length 3000
  ./focus.sh start
  ./focus.sh stop
  cat $OUTPUT_FILE | grep -q "New high max score"
  return $?
}

test_appends_to_existing_log() {
  # last two values avg, max
  echo "2023-07-25T15:40:54 1690314060763 6 124.2428 4 1.45864784059431617247 0.36466196014857904311 0.87642818572655602893" > $LOG_FILE
  single_focus_at_length 3000
  ./focus.sh start
  ./focus.sh stop
  wc -l $LOG_FILE | grep -q "2"
  return $?
}

test_doesnt_detect_high_if_not_higher() {
  # last two values avg, max
  echo "2023-07-25T15:40:54 1690314060763 6 124.2428 4 1.45864784059431617247 0.36466196014857904311 0.87642818572655602893" > $LOG_FILE
  cat $LOG_FILE
  single_focus_at_length 1
  ./focus.sh start
  ./focus.sh stop
  cat $OUTPUT_FILE | grep -vq "New high max score"
  if [[ $? -ne 0 ]]; then
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

if [ $# -gt 0 ]; then
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
