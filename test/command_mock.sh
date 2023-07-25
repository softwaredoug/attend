#!/usr/bin/env bash

# Get this filename
THIS_FILE=$(basename "$0")

# Jira test fixture

args_file=".last_$THIS_FILE"_args

# Make last args file for just this command
rm -f "ARGS FILE!! $args_file"
echo "$@" >> "$args_file"

# Useful for follow on mocks
call_count=$(wc -l < .last_"$THIS_FILE"_args)
