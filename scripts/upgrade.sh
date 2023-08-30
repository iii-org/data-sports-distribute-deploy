#!/usr/bin/env bash

set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)" # Base directory of this script
PROJECT_DIR="$(dirname "$BASEDIR")"      # Default project directory
USERNAME="$(whoami)"                     # Get current username
GITHUB_NAME="data-sports-distribute-deploy"                                                                        # Default github project name
BRANCH="master"                                                                              # Default branch
TAR_DOWNLOAD_URL="https://github.com/iii-org/$GITHUB_NAME/archive/refs/heads/$BRANCH.tar.gz" # Default tar download url

if [[ ! -f "$BASEDIR/common.sh" ]]; then
  echo "Please use git clone to download the project."
  echo "$BASEDIR/common.sh not found, exiting..."
  exit 1
fi

source "$BASEDIR/common.sh"

done_script() {
  cd "${PROJECT_DIR}" || FAILED "Failed to change directory to ${PROJECT_DIR}"

  if docker compose version &>/dev/null; then
    docker compose pull
    docker compose up \
      --remove-orphans \
      --detach
  elif docker-compose --version &>/dev/null; then
    docker-compose pull
    docker-compose up \
      --remove-orphans \
      --detach
  fi
  docker image prune -f
}

update_via_git() {
  cd "${PROJECT_DIR}" || FAILED "Failed to change directory to ${PROJECT_DIR}"

  INFO "⬇️ Updating git remotes..."
  git remote update >/dev/null 2>&1

  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse '@{u}')

  if [ "$LOCAL" = "$REMOTE" ]; then
    INFO "✅ Already up-to-date, skipping..."
    exit 0
  else
    INFO "⬇️ Pulling latest changes..."
    git pull

    done_script
  fi
}

update_via_tar() {
  cd "${PROJECT_DIR}" || FAILED "Failed to change directory to ${PROJECT_DIR}"
  # We need go to the parent directory of the project directory
  # So we can copy the files to the project directory
  cd ..

  INFO "⬇️ Downloading latest release..."
  wget -q -O release.tar.gz "$TAR_DOWNLOAD_URL"

  INFO "🗃️ Extracting files..."
  tar -xzf release.tar.gz

  INFO "📝 Copying files..."
  cp -rT "$GITHUB_NAME-$BRANCH"/ "$PROJECT_DIR"

  INFO "🗑️ Cleaning up..."
  rm -rf "$GITHUB_NAME-$BRANCH"
  rm release.tar.gz

  done_script
}

if [[ ! -f "$PROJECT_DIR"/.env ]]; then
  ERROR "First, must execute setup.sh script."
  exit 1
fi

if [[ ! "$(id -u)" -eq 0 ]]; then
  INFO "Changing permission of all files to current USERNAME (prevent permission issues)"
  INFO "Current USERNAME: $USERNAME"
  sudo chown -R "$USERNAME":"$USERNAME" "$PROJECT_DIR"
fi

# WARNING: This script will **REPLACED** while upgrading, please put any custom script before this line.
# Check if .git exists
if [ ! -d "${PROJECT_DIR}"/.git ]; then
  update_via_tar
else
  update_via_git
fi
