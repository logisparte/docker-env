#!/bin/sh -e
#
# docker-env 0.3.0
#
# Copyright 2025 logisparte inc.
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

if [ -f "$PWD/.env" ]; then
  set -a
  . "$PWD/.env"
  set +a
fi

PROJECT_NAME="$(basename "$PWD")"
export IMAGE_NAME="$PROJECT_NAME-dev"
if [ -n "$DOCKER_ENV_REGISTRY" ]; then
  export IMAGE_NAME="$DOCKER_ENV_REGISTRY/$IMAGE_NAME"
fi

PROJECT_DOCKER_DIRECTORY="$PWD/docker"
PROJECT_COMPOSE_FILE="$PROJECT_DOCKER_DIRECTORY/compose.yaml"
PROJECT_DOCKERFILE="$PROJECT_DOCKER_DIRECTORY/Dockerfile"
USER_DIRECTORY="$HOME/.config/docker-env"
USER_COMPOSE_FILE="$USER_DIRECTORY/compose.yaml"
USER_HOST_DIRECTORY="$USER_DIRECTORY/host"
USER_HOST_COMPOSE_ENV_FILE="$USER_HOST_DIRECTORY/.env"
USER_HOST_PASSWD_FILE="$USER_HOST_DIRECTORY/passwd"
USER_HOST_GROUP_FILE="$USER_HOST_DIRECTORY/group"
USER_HOST_SUDOER_FILE="$USER_HOST_DIRECTORY/sudoer"

export COMPOSE_BAKE=true

_help() {
  {
    echo
    echo "Usage: ./docker/env.sh COMMAND [OPTIONS] [ARGS...]"
    echo
    echo "Encapsulate your project's development environment inside a Docker container"
    echo
    echo "Commands:"
    echo "  name|Output the dev image name"
    echo "  init [OPTIONS]|Prepare user host files and build dev image"
    echo "  build [OPTIONS]|Build dev image"
    echo "  clean [OPTIONS]|Delete user host files and dev image"
    echo "  up|Create and start a persistent dev container"
    echo "  down|Stop and remove the dev container"
    echo "  exec|Execute a command in the running dev container"
    echo "  shell|Open an interactive shell in the running dev container"
    echo "  tag [NEW_TAG=latest] [CURRENT_TAG=]|Tag the dev image"
    echo "  pull [TAG=latest]|Pull the dev image from the \$DOCKER_ENV_REGISTRY"
    echo "  push [TAG=latest]|Push the dev image to the \$DOCKER_ENV_REGISTRY"
    echo
    echo \
      "For more help on how to use docker-env, head to https://github.com/logisparte/docker-env"
  } | awk -F "|" '{printf "%-40s %s\n", $1, $2}'
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
  if [ -d "$USER_HOST_DIRECTORY" ]; then
    echo "docker-env: User host files already exist at $USER_HOST_DIRECTORY, skipping."
    return 0
  fi

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

# Build the image from cache, if possible
_build() {
  docker image build \
    --file "$PROJECT_DOCKERFILE" \
    --tag "$IMAGE_NAME" \
    --cache-from "type=registry,ref=$IMAGE_NAME" \
    --cache-to type=inline \
    --pull \
    "$@" \
    .
}

# Delete host files and image
_clean() {
  rm -rf "$USER_HOST_DIRECTORY"
  docker image remove "$IMAGE_NAME" "$@"
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

  # Exec provided one-off command or pause to keep container alive
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

  name)
    echo "$IMAGE_NAME"
    ;;

  init)
    shift
    _init
    _build "$@"
    ;;

  clean)
    shift
    _clean "$@"
    ;;

  build)
    shift
    _build "$@"
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
    NEW_TAG="${1:-latest}"
    if [ $# -gt 1 ]; then
      CURRENT_IMAGE_NAME="$IMAGE_NAME:$2"
    else
      CURRENT_IMAGE_NAME="$IMAGE_NAME"
    fi

    docker image tag "$CURRENT_IMAGE_NAME" "$IMAGE_NAME:$NEW_TAG"
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
