#!/usr/bin/env bash

set -euo pipefail

# Load common functions
base_dir="$(cd "$(dirname "$0")" && pwd)"
source "$base_dir"/scripts/common.sh

env_file="$base_dir"/.env

DOCKER_VERSION=""
DOCKER_COMPOSER=""
DOCKER_COMPOSE_VERSION=""

check_system_requirements() {
  local distro
  distro="$(get_distribution)"

  if [[ "$distro" != "ubuntu" && "$distro" != "debian" ]]; then
    ERROR "Unsupported Linux distribution: ${distro}, only support Ubuntu."
    exit 1
  fi
}

network_connectivity_check() {
  INFO "Checking network connectivity..."
  INFO "Checking ping..."
  if : >/dev/tcp/8.8.8.8/53; then
    echo 'PONG!'
  else
    echo 'Ping failed.'
    ERROR "Please check your network settings."
    exit 1
  fi

  INFO "Checking DNS..."
  if ping -c 1 -W 1 google.com &>/dev/null; then
    echo 'DNS resolved successfully.'
  else
    echo 'DNS resolve failed.'
    ERROR "Please check your DNS settings."
    exit 1
  fi
  INFO "Network connectivity check passed!"
}

get_docker_version() {
  if command_exists docker; then
    DOCKER_VERSION="$(docker version --format '{{.Server.Version}}')"
  else
    return 0
  fi

  if docker compose version &>/dev/null; then
    # Docker Compose version v2.19.1
    DOCKER_COMPOSER="docker compose"
    DOCKER_COMPOSE_VERSION="$(docker compose version | grep -oP '(?<=version )[^,]+')"
  elif docker-compose --version &>/dev/null; then
    # docker-compose version X.Y.Z, build <identifier>
    DOCKER_COMPOSER="docker-compose"
    DOCKER_COMPOSE_VERSION="$(docker-compose --version | grep -oP '(?<=version )[^,]+')"
  fi

  # If DOCKER_COMPOSER is empty, failed the script
  if [ -z "$DOCKER_COMPOSER" ]; then
    ERROR "CAN NOT detect docker compose command, please check your docker installation."
    exit 1
  fi
}

print_docker_version() {
  INFO "============= ${YELLOW}DOCKER INFO${NOFORMAT} ============="
  INFO "Docker version: ${GREEN}${DOCKER_VERSION}${NOFORMAT}"
  INFO "Docker compose version: ${GREEN}${DOCKER_COMPOSE_VERSION}${NOFORMAT}"
  INFO "Docker compose command: ${GREEN}${DOCKER_COMPOSER}${NOFORMAT}"
  INFO "======================================="
}

check_docker_exist_or_install() {
  if [ -z $DOCKER_VERSION ]; then
    WARN "Docker is not installed, auto install docker..."
    if sudo_timeout_check; then
      WARN "Please enter your sudo password to grant docker installation permission!"
      sudo -v
    fi
    "$base_dir"/scripts/install-docker.sh
  fi

  print_docker_version
}

load_env() {
  if [ ! -f "$env_file" ]; then
    cp "$base_dir"/.env.example "$env_file"
  fi

  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
}

check_environs() {
  local need_reload=false

  port_validator() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]]; then
      if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        ERROR "Port number must be between 1 and 65535."
        return 1
      fi
    else
      ERROR "Port number must be a number."
      return 1
    fi
  }

  password_validator() {
    local password="$1"
    if [ ${#password} -lt 8 ]; then
      ERROR "Password must be at least 8 characters."
      return 1
    fi
  }

  string_validator() {
    local string="$1"
    if [ ${#string} -lt 2 ]; then
      ERROR "String must be at least 2 characters."
      return 1
    fi
  }

  ask_port() {
    local port_name="$1"
    local default_port="$2"
    local port

    while true; do
      read -rp "Please enter ${port_name} port [${default_port}]: " port
      if [ -z "$port" ]; then
        port="$default_port"
      fi
      if port_validator "$port"; then
        break
      fi
    done
    echo "$port"
  }

  ask_password() {
    local password_name="$1"
    local default_password
    default_password="$(generate_random_string 20)"
    local password

    while true; do
      read -rp "Please enter ${password_name} password (default: random string): " password
      if [ -z "$password" ]; then
        password="$default_password"
      fi
      if password_validator "$password"; then
        break
      fi
    done
    echo "$password"
  }

  ask_string() {
    local string_name="$1"
    local default_string="$2"
    local string

    while true; do
      read -rp "Please enter ${string_name} [${default_string}]: " string
      if [ -z "$string" ]; then
        string="$default_string"
      fi
      if string_validator "$string"; then
        break
      fi
    done
    echo "$string"
  }

  if [ -z "${SPORT_DB_PORT:-}" ]; then
    SPORT_DB_PORT="$(ask_port "database" "5432")"
    write_back_data "SPORT_DB_PORT" "$SPORT_DB_PORT"
    need_reload=true
  else
    if ! port_validator "$SPORT_DB_PORT"; then
      SPORT_DB_PORT="$(ask_port "database" "5432")"
      write_back_data "SPORT_DB_PORT" "$SPORT_DB_PORT"
      need_reload=true
    fi
  fi

  if [ -z "${POSTGRES_PASSWORD:-}" ]; then
    POSTGRES_PASSWORD="$(ask_password "database")"
    write_back_data "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD" true
    need_reload=true
  else
    if ! password_validator "$POSTGRES_PASSWORD"; then
      POSTGRES_PASSWORD="$(ask_password "database")"
      write_back_data "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD" true
      need_reload=true
    fi
  fi

  # Mongo
  if [ -z "${MONGO_PORT:-}" ]; then
    MONGO_PORT="$(ask_port "mongo" "27017")"
    write_back_data "MONGO_PORT" "$MONGO_PORT"
    need_reload=true
  else
    if ! port_validator "$MONGO_PORT"; then
      MONGO_PORT="$(ask_port "mongo" "27017")"
      write_back_data "MONGO_PORT" "$MONGO_PORT"
      need_reload=true
    fi
  fi

  if [ -z "${MONGO_ROOT:-}" ]; then
    MONGO_ROOT="$(ask_string "mongo root" "mongouser")"
    write_back_data "MONGO_ROOT" "$MONGO_ROOT"
    need_reload=true
  else
    if ! string_validator "$MONGO_ROOT"; then
      MONGO_ROOT="$(ask_string "mongo root" "mongouser")"
      write_back_data "MONGO_ROOT" "$MONGO_ROOT"
      need_reload=true
    fi
  fi

  if [ -z "${MONGO_PASSWORD:-}" ]; then
    MONGO_PASSWORD="$(ask_password "mongo")"
    write_back_data "MONGO_PASSWORD" "$MONGO_PASSWORD" true
    need_reload=true
  else
    if ! password_validator "$MONGO_PASSWORD"; then
      MONGO_PASSWORD="$(ask_password "mongo")"
      write_back_data "MONGO_PASSWORD" "$MONGO_PASSWORD" true
      need_reload=true
    fi
  fi

  # Login service
  if [ -z "${SPORT_PORT:-}" ]; then
    SPORT_PORT="$(ask_port "login" "10009")"
    write_back_data "SPORT_PORT" "$SPORT_PORT"
    need_reload=true
  else
    if ! port_validator "$SPORT_PORT"; then
      SPORT_PORT="$(ask_port "login" "10009")"
      write_back_data "SPORT_PORT" "$SPORT_PORT"
      need_reload=true
    fi
  fi

  if [ -z "${INIT_ADMIN:-}" ]; then
    INIT_ADMIN="$(ask_string "login account" "admin")"
    write_back_data "INIT_ADMIN" "$INIT_ADMIN"
    need_reload=true
  else
    if ! string_validator "$INIT_ADMIN"; then
      INIT_ADMIN="$(ask_string "login account" "admin")"
      write_back_data "INIT_ADMIN" "$INIT_ADMIN"
      need_reload=true
    fi
  fi

  if [ -z "${INIT_ADMIN_PASSWORD:-}" ]; then
    INIT_ADMIN_PASSWORD="$(ask_password "login")"
    write_back_data "INIT_ADMIN_PASSWORD" "$INIT_ADMIN_PASSWORD" true
    need_reload=true
  else
    if ! password_validator "$INIT_ADMIN_PASSWORD"; then
      INIT_ADMIN_PASSWORD="$(ask_password "login")"
      write_back_data "INIT_ADMIN_PASSWORD" "$INIT_ADMIN_PASSWORD" true
      need_reload=true
    fi
  fi

  if $need_reload; then
    INFO "Reloading environs..."
    load_env
  fi
}

print_environs() {
  INFO "============== ${YELLOW}ENV INFO${NOFORMAT} ==============="
  INFO "Database port: ${GREEN}${SPORT_DB_PORT}${NOFORMAT}"
  INFO "Database password: ${GREEN}${POSTGRES_PASSWORD}${NOFORMAT}"

  INFO "Mongo DB port: ${GREEN}${MONGO_PORT}${NOFORMAT}"
  INFO "Mongo DB user: ${GREEN}${MONGO_ROOT}${NOFORMAT}"
  INFO "Mongo DB password: ${GREEN}${MONGO_PASSWORD}${NOFORMAT}"

  INFO "Login port: ${GREEN}${SPORT_PORT}${NOFORMAT}"
  INFO "Login account: ${GREEN}${INIT_ADMIN}${NOFORMAT}"
  INFO "Login password: ${GREEN}${INIT_ADMIN_PASSWORD}${NOFORMAT}"

  INFO "Debug use url: ${GREEN}${MASTER_URL}${NOFORMAT}"
  INFO "======================================="
}

redis_check() {
  INFO "Redis requirements check..."

  # Check vm.overcommit_memory is enabled
  if [ "$(sudo sysctl -n vm.overcommit_memory)" -ne 1 ]; then
    INFO "vm.overcommit_memory is enabled"
    INFO "Executing command to set vm.overcommit_memory to 1..."
    sudo sysctl -w vm.overcommit_memory=1

    INFO "Persisting vm.overcommit_memory to ${PURPLE}/etc/sysctl.d/99-redis.conf${NOFORMAT}"
    echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.d/99-redis.conf
  fi

  INFO "Redis requirements check finished!"
}

start_service() {
  if sudo_timeout_check; then
    INFO "We need sudo permission to check requirements, please enter your sudo password!"
    sudo -v
  fi
  redis_check

  INFO "Starting services..."

  $DOCKER_COMPOSER up -d
}

post_message() {
  INFO "Service started!"
  INFO "You can visit ${GREEN}http://localhost:${SPORT_PORT}${NOFORMAT} to login"
  INFO "Default account: ${GREEN}${INIT_ADMIN}${NOFORMAT}"
  INFO "Default password: ${GREEN}${INIT_ADMIN_PASSWORD}${NOFORMAT}"
}

main() {
  check_runas_root
  check_system_requirements
  network_connectivity_check
  get_docker_version
  check_docker_exist_or_install
  load_env
  check_environs
  print_environs
  start_service
  post_message
}

main "$@"
