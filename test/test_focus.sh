#!/usr/bin/env bash

OUTPUT_FILE="/tmp/focus_output.txt"
PID_FILE="/tmp/focus_process.pid"
LOG_FILE="/tmp/focus_log.txt"

mock() {
  cp test/command_mock.sh $1_mock
}

clean_mock() {
  rm $1_mock
  rm -f ".last_$1_mock"_args
}

MOCKS=('idle' 'focus' 'sleep' 'afplay' 'gdate')


fixtures() {
  for mock in ${MOCKS[@]}; do
    mock $mock
  done

  # Some default returns
  echo "echo 'Google Chrome'" >> focus_mock
  echo ' if [[ "$1" == "+%s%3N" ]]; then echo "1000"; fi' >> gdate_mock
  echo ' if [[ "$1" == "%Y-%m-%dT%H:%M" ]]; then echo "2018-01-01T00:00"; fi' >> gdate_mock
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


test_focus_produces_output() {
  ./focus.sh start
  sleep 0.1
  ./focus.sh stop
  if [[ -f $OUTPUT_FILE ]]; then
    return 0
  else
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
