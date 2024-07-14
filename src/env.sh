#!/bin/sh -e
#
# docker-env 0.1.3
#
# Copyright 2024 logisparte inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PROJECT_NAME="$(basename "$PWD")"
export IMAGE_NAME="$PROJECT_NAME-dev"
if [ -n "$DOCKER_ENV_REGISTRY" ]; then
  export IMAGE_NAME="$DOCKER_ENV_REGISTRY/$IMAGE_NAME"
fi

PROJECT_DOCKER_DIRECTORY="$PWD/docker"
PROJECT_COMPOSE_FILE="$PROJECT_DOCKER_DIRECTORY/compose.yaml"
USER_DIRECTORY="$HOME/.config/docker-env"
USER_COMPOSE_FILE="$USER_DIRECTORY/compose.yaml"
USER_HOST_DIRECTORY="$USER_DIRECTORY/host"
USER_HOST_COMPOSE_ENV_FILE="$USER_HOST_DIRECTORY/.env"
USER_HOST_PASSWD_FILE="$USER_HOST_DIRECTORY/passwd"
USER_HOST_GROUP_FILE="$USER_HOST_DIRECTORY/group"
USER_HOST_SUDOER_FILE="$USER_HOST_DIRECTORY/sudoer"

_help() {
  {
    echo
    echo "Usage: $0 COMMAND [OPTIONS] [ARGS...]"
    echo
    echo "Encapsulate your project's development environment inside a Docker container"
    echo
    echo "Commands:"
    echo "  init|Prepare user host files and build dev image"
    echo "  build|Build dev image"
    echo "  up|Create and start a persistent dev container"
    echo "  down|Stop and remove the dev container"
    echo "  exec|Execute a command in the running dev container"
    echo "  shell|Open an interactive shell in the running dev container"
    echo "  tag [TAG]|Tag the dev image"
    echo "  pull [TAG]|Pull the dev image from the \$DOCKER_ENV_REGISTRY"
    echo "  push [TAG]|Push the dev image to the \$DOCKER_ENV_REGISTRY"
    echo
    echo "init options:"
    echo "  -f, --force|Recreate user host files, even if they already exist"
    echo
    echo \
      "For more help on how to use docker-env, head to https://github.com/logisparte/docker-env"
  } | awk -F "|" '{printf "%-18s %s\n", $1, $2}'
}

# To use docker compose with project's compose file, host files and optional user customizations
_compose() {
  if [ -f "$USER_COMPOSE_FILE" ]; then
    set -- --file "$USER_COMPOSE_FILE" "$@"
  fi

  docker compose \
    --project-name "$PROJECT_NAME" \
    --env-file "$USER_HOST_COMPOSE_ENV_FILE" \
    --file "$PROJECT_COMPOSE_FILE" \
      "$@"
}

# Prepare host files to map host user into container
_init() {
  OPTION="$1"
  case "$OPTION" in
    -f | --force)
      true
      ;;

    *)
      [ -d "$USER_HOST_DIRECTORY" ] && return 0
      ;;
  esac

  # Clear docker host directory
  rm -rf "$USER_HOST_DIRECTORY"
  mkdir -p "$USER_HOST_DIRECTORY"

  # Ensure user IDs
  HOST_USER="$(id -un)"
  HOST_UID="$(id -u)"
  HOST_GID="$(id -g)"

  # /etc/passwd file
  {
    echo "root:x:0:0:root:/root:/bin/sh"
    if [ "$HOST_UID" != "0" ]; then
      echo "$HOST_USER::$HOST_UID:$HOST_GID:$HOST_USER:$HOME:${SHELL:-/bin/sh}"
    fi
  } > "$USER_HOST_PASSWD_FILE"

  # /etc/group file
  echo "$HOST_USER:x:$HOST_GID:" > "$USER_HOST_GROUP_FILE"

  # /etc/sudoers.d/$HOST_USER file
  if ! sudo -n true 2> /dev/null; then
    echo "docker-env: This script will generate a 'sudoers.d' file to be mounted in the" \
      "development container. As this file needs to be owned by the root user, your password" \
      "will be required."
  fi

  echo "$HOST_USER ALL=(ALL) NOPASSWD:ALL" > "$USER_HOST_SUDOER_FILE"
  chmod 440 "$USER_HOST_SUDOER_FILE"
  sudo chown root "$USER_HOST_SUDOER_FILE"

  # SSH socket
  if [ "$(uname)" = "Darwin" ]; then
    HOST_SSH_AUTH_SOCK="/run/host-services/ssh-auth.sock" # Docker for Mac workaround

  else
    HOST_SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
  fi

  # docker compose env file
  {
    echo "HOST_USER=$HOST_USER"
    echo "HOST_UID=$HOST_UID"
    echo "HOST_GID=$HOST_GID"
    echo "HOST_SSH_AUTH_SOCK=$HOST_SSH_AUTH_SOCK"
  } > "$USER_HOST_COMPOSE_ENV_FILE"
}

# Container entrypoint (used inside container)
_entrypoint() {
  USERNAME="$(id -un)"

  # Rationalize ownership of project's ancestor directories
  DIRECTORY="$PWD"
  while [ "$DIRECTORY" != "/" ]; do
    sudo chown "$USERNAME" "$DIRECTORY"
    [ "$DIRECTORY" = "$HOME" ] && break
    DIRECTORY="$(dirname "$DIRECTORY")"
  done

  # Rationalize ownership of SSH socket, if any
  if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    sudo chown "$USERNAME" "$SSH_AUTH_SOCK"
  fi

  # Exec provided command or pause to keep container alive
  if [ $# -gt 0 ]; then
    "$@"

  else
    tail -f /dev/null
  fi
}

COMMAND="${1:---help}"
if [ -n "$DOCKER_ENV_CURRENT" ]; then
  if [ "$COMMAND" = "_entrypoint" ]; then
    shift
    _entrypoint "$@"

  else
    echo "docker-env: Already inside the dev container." >&2
    exit 1
  fi
fi

case "$COMMAND" in
  -h | --help)
    _help
    ;;

  init)
    shift
    _init "$@"
    _compose build --pull dev
    ;;

  build)
    _compose build --pull dev
    ;;

  up)
    _compose up --wait
    ;;

  down)
    _compose down
    ;;

  exec)
    shift
    _compose exec dev "$@"
    ;;

  shell)
    _compose exec dev "${SHELL:-/bin/sh}" --login
    ;;

  tag)
    shift
    TAG="${1:-latest}"
    docker image tag "$IMAGE_NAME" "$IMAGE_NAME:$TAG"
    ;;

  pull)
    if [ -z "$DOCKER_ENV_REGISTRY" ]; then
      echo "docker-env: 'DOCKER_ENV_REGISTRY' is not set, cannot proceed with pull." >&2
      exit 1
    fi

    shift
    TAG="${1:-latest}"
    docker image pull "$IMAGE_NAME:$TAG"
    ;;

  push)
    if [ -z "$DOCKER_ENV_REGISTRY" ]; then
      echo "docker-env: 'DOCKER_ENV_REGISTRY' is not set, cannot proceed with push." >&2
      exit 1
    fi

    shift
    TAG="${1:-latest}"
    docker image push "$IMAGE_NAME:$TAG"
    ;;

  *)
    echo "docker-env: '$COMMAND' is not a docker-env command." >&2
    echo "See '$0 --help'" >&2
    exit 1
    ;;
esac
