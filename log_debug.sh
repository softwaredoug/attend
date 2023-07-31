#!/bin/bash


echo "LOGGING ENABLED"

log() {
  echo "$1" > /dev/tty
}


warn() {
  local calling_line_info=$(caller 0)
  local calling_line=${calling_line_info% *}
  log "🚨 WARNING -- "
  log "    at line $calling_line"
  log "    error: $err_check"
  log ""
  log "    message: $1"
}
