#!/usr/bin/env bash

trap_exit() {
  local return_value=$?

  if [ "$return_value" -eq 130 ]; then
    # Catch SIGINT (Ctrl+C) by trap_ctrlc
    exit 130
  elif [ "$return_value" -eq 21 ]; then
    # Catch exit 21 by usage
    exit 21
  elif [ "$return_value" -eq 0 ]; then
    NOTICE "Script executed successfully"
  else
    exit "$return_value"
  fi
}

collect_system_info() {
  log_file="${1:?}"

  echo "================= System Information =================" >>"$log_file"
  echo "Date: $(date -u +"%Y-%m-%d %H:%M:%S") (UTC)" >>"$log_file"
  echo "Hostname: $(hostname)" >>"$log_file"
  echo "Kernel: $(uname -a)" >>"$log_file"
  echo "Current user: $(whoami)" >>"$log_file"
  echo "PWD: $PWD" >>"$log_file"
  echo "Shell: $SHELL" >>"$log_file"

  echo "=== Docker info ===" >>"$log_file"
  if command -v docker >/dev/null 2>&1; then
    echo "Docker version: $(docker version -f '{{.Server.Version}}')" >>"$log_file"

    echo "Docker security options:" >>"$log_file"
    docker info -f '{{.SecurityOptions}}' >>"$log_file"

    if docker compose version &>/dev/null; then
      echo "Docker compose command: docker compose" >>"$log_file"
      echo "Docker compose version: $(docker compose version | grep -oP '(?<=version )[^,]+')" >>"$log_file"
    elif docker-compose --version &>/dev/null; then
      echo "Docker compose command: docker-compose" >>"$log_file"
      echo "Docker compose version: $(docker-compose --version | grep -oP '(?<=version )[^,]+')" >>"$log_file"
    else
      echo "Docker compose command: NOT FOUND" >>"$log_file"
    fi
  else
    echo "Docker: NOT FOUND" >>"$log_file"
    echo "Docker compose command: NOT FOUND" >>"$log_file"
  fi

  echo "======================================================" >>"$log_file"
  echo "" >>"$log_file"
  echo "================== /etc/os-release ===================" >>"$log_file"
  cat /etc/os-release >>"$log_file"
  echo "======================================================" >>"$log_file"
  echo "" >>"$log_file"
  echo "====================== Variables =====================" >>"$log_file"
  ulimit -a >>"$log_file"
  echo "======================================================" >>"$log_file"
  env | sort >>"$log_file"
  echo "======================================================" >>"$log_file"
  (
    set -o posix
    set
  ) >>"$log_file"
  echo "======================================================" >>"$log_file"
  echo "" >>"$log_file"
  echo "============= System memory and CPU info =============" >>"$log_file"
  echo "Architecture: $(uname -m)" >>"$log_file"
  echo "Bits: $(getconf LONG_BIT)" >>"$log_file"
  echo "CPU(s): $(nproc)" >>"$log_file"
  echo "Model name: $(cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d ":" -f2 | xargs)" >>"$log_file"
  free -h >>"$log_file"
  echo "======================================================" >>"$log_file"
}

trap_traceback() {
  local return_value=$?

  if [[ ! $- =~ "e" ]]; then
    return
  fi

  local log_file
  log_file="$(mktemp -t XXXXXXXXXX.log)"

  collect_system_info "$log_file"
  echo "" >>"$log_file"
  echo "=================== Error message ====================" >>"$log_file"

  # Check if .git exists
  if [ -d "${project_dir:?}"/.git ]; then
    echo "Git commit hash: $(git describe --always --dirty)" >>"$log_file"
    ERROR "Git commit ID: ${WHITE}$(git describe --always --dirty)${NOFORMAT}"
  fi

  # Modified from https://gist.github.com/Asher256/4c68119705ffa11adb7446f297a7beae
  set +o xtrace
  local bash_command=${BASH_COMMAND}
  ERROR "In ${BASH_SOURCE[1]}:${BASH_LINENO[0]}"
  echo "In ${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >>"$log_file"
  ERROR "\\t${WHITE}${bash_command}${NOFORMAT} exited with status $return_value"
  echo "   Command: ${bash_command}" >>"$log_file"
  echo "   Exit code: ${return_value}" >>"$log_file"
  echo "" >>"$log_file"

  if [ ${#FUNCNAME[@]} -gt 2 ]; then
    # Print out the stack trace described by $function_stack
    ERROR "Traceback of ${BASH_SOURCE[1]} (most recent call last):"
    echo "Traceback of ${BASH_SOURCE[1]} (most recent call last):" >>"$log_file"
    for ((i = 0; i < ${#FUNCNAME[@]} - 1; i++)); do
      local funcname="${FUNCNAME[$i]}"
      [ "$i" -eq "0" ] && funcname=$bash_command
      ERROR "  ${BASH_SOURCE[$i + 1]}:${BASH_LINENO[$i]}\\t$funcname"
      echo -e "  ${BASH_SOURCE[$i + 1]}:${BASH_LINENO[$i]}\t$funcname" >>"$log_file"
    done
    echo "" >>"$log_file"
  fi

  ERROR "======================================================"
  ERROR "Full log generated at ${ORANGE}${log_file}${NOFORMAT}"
  ERROR "Please attach the log file when reporting the issue."
}

trap_ctrlc() {
  NOTICE "Script interrupted by Ctrl+C (SIGINT)"
  exit 130
}
