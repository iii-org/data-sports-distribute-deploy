#!/usr/bin/env bash

bin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
project_dir="$(cd "$(dirname "$bin_dir")" && pwd)"

source "$project_dir"/scripts/traps.sh

set -E
trap trap_ctrlc INT
trap trap_traceback ERR
trap trap_exit EXIT

CLEAR_LINE="\r\033[2K"
CUSOR_UP="\033[A"
HIDE_CURSOR="\033[?25l"
SHOW_CURSOR="\033[?25h"

if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
  NOFORMAT='\033[0m'
  RED='\033[1;31m'
  GREEN='\033[1;32m'
  ORANGE='\033[0;33m'
  BLUE='\033[1;34m'
  PURPLE='\033[0;35m'
  CYAN='\033[1;36m'
  YELLOW='\033[1;33m'
  WHITE='\033[1;97m'
else
  NOFORMAT=''
  RED=''
  GREEN=''
  ORANGE=''
  BLUE=''
  PURPLE=''
  CYAN=''
  YELLOW=''
  WHITE=''
fi

msg() {
  echo >&2 -e "${1-}"
}

INFO() {
  msg "${GREEN}[INFO]${NOFORMAT} ${1}"
}

NOTICE() {
  msg "${CYAN}[NOTICE]${NOFORMAT} ${1}"
}

WARN() {
  msg "${ORANGE}[WARN]${NOFORMAT} ${1}"
}

ERROR() {
  msg "${RED}[ERROR]${NOFORMAT} ${1}" >&2
}

FAILED() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "${RED}[FAILED]${NOFORMAT} ${msg}" >&2
  exit "$code"
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

sudo_timeout_check() {
  local status
  # https://unix.stackexchange.com/q/692061
  status="$(sudo -n uptime 2>&1 | grep -c "load")"

  return "${status}"
}

get_distribution() {
  # Copy from https://get.docker.com/
  local lsb_dist=""
  # Every system that we officially support has /etc/os-release
  if [ -r /etc/os-release ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
  fi
  # Returning an empty string here should be alright since the
  # case statements don't act unless you provide an actual value
  echo "$lsb_dist" | tr '[:upper:]' '[:lower:]'
}

check_runas_root() {
  if [ "$(id -u)" == "0" ]; then
    ERROR "Please run this script as normal user, not root."
    exit 1
  fi
}

generate_random_string() {
  local length="$1"
  echo "$(
    tr </dev/urandom -dc '[:alnum:]' | head -c ${length}
    true
  )"
}

write_back_data() {
  local key="$1"
  local value="$2"
  local value_sensitive="${3:-false}"

  # Check if key is in .env file
  if ! grep -q "$key=" "${env_file:?}"; then
    INFO "$key not found in .env file, adding it"
    echo "$key=\"$value\"" >>"$env_file"
  fi

  # Check if value contains double quote
  if [[ "$value" == *\"* ]]; then
    # From " to \"
    value="${value//\"/\\\\\"}"
  fi

  # If value contain '\$', then escape it
  if [[ "$value" == *\\\$* ]]; then
    # From $ to \$
    value="${value//\$/\\\\\\\\\\$}"
  else
    # Escape backslash
    value="${value//\\/\\\\}"
    # Escape dollar sign
    value="${value//\$/\\\\\$}"
  fi

  # Escape back quote
  value="${value//\`/\\\`}"

  # Write back to .env file, replace the old key, using awk to escape special characters
  awk -v key="$key" -v value="$value" 'BEGIN { FS=OFS="=\"" }
    { for(i=3; i<=NF; i++)
      {
        $2 = $2"=\""$i
      }
    }
    $1 == key {
      $2 = value"\""
    }
    NF {
      if ($1 ~ /^#/) {
        NF = NF
      }
      else {
        NF = 2
      }
    } 1' "$env_file" >"$env_file.tmp"

  if [ "${value_sensitive}" = false ]; then
    INFO "${ORANGE}$key${NOFORMAT} set to ${BLUE}$value${NOFORMAT}"
  else
    INFO "${ORANGE}$key${NOFORMAT} set to ${BLUE}********${NOFORMAT}"
  fi

  # Replace the old file, we don't need the tmp file anymore
  mv "$env_file.tmp" "$env_file"
}
