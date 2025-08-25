#!/bin/sh -e
#
# docker-env 0.4.0
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

export COMPOSE_BAKE=true

USER_DIRECTORY="$HOME/.config/docker-env"
USER_HOST_DIRECTORY="$USER_DIRECTORY/host"
USER_HOST_COMPOSE_ENV_FILE="$USER_HOST_DIRECTORY/.env"
USER_HOST_PASSWD_FILE="$USER_HOST_DIRECTORY/passwd"
USER_HOST_GROUP_FILE="$USER_HOST_DIRECTORY/group"
USER_HOST_SUDOER_FILE="$USER_HOST_DIRECTORY/sudoer"
USER_COMPOSE_FILE="$USER_DIRECTORY/compose.yaml"

# Load project .env, if any
PROJECT_ENV_FILE="${DOCKER_ENV_PROJECT_ENV_FILE:-"./.env"}"
if [ -f "$PROJECT_ENV_FILE" ]; then
  set -a
  . "$PROJECT_ENV_FILE"
  set +a
fi

PROJECT_NAME="${DOCKER_ENV_PROJECT_NAME:-"$(basename "$PWD")"}"
PROJECT_DOCKER_DIRECTORY="${DOCKER_ENV_PROJECT_DOCKER_DIRECTORY:-"$PWD/docker"}"
PROJECT_COMPOSE_FILE="${DOCKER_ENV_PROJECT_COMPOSE_FILE:-"$PROJECT_DOCKER_DIRECTORY/compose.yaml"}"
PROJECT_CACHE_DIRECTORY="${DOCKER_ENV_PROJECT_CACHE_DIRECTORY:-$PWD/.cache/docker-env}"
PROJECT_BASE_COMPOSE_FILE="$PROJECT_CACHE_DIRECTORY/base.compose.yaml"
PROJECT_DEFAULT_SERVICE="${DOCKER_ENV_PROJECT_DEFAULT_SERVICE:-"dev"}"

_help() {
  {
    echo
    echo "Usage: $PROJECT_DOCKER_DIRECTORY/env.sh COMMAND [OPTIONS] [ARGS...]"
    echo
    echo "Encapsulate your project's dev environment inside one or more Docker containers using docker compose"
    echo
    echo "Commands:"
    echo "  shell [SERVICE]|Open an interactive shell in a dev env container"
    echo "  exec [SERVICE] -- COMMAND|Execute a command in a dev env container"
    echo "  up [OPTIONS]|Build/pull images, create and start dev containers"
    echo "  down [OPTIONS]|Stop and remove dev containers"
    echo "  compose [ARGUMENTS...]|Directly call 'docker compose' with project settings"
    echo
    echo \
      "For more info on how to use docker-env, head to https://github.com/logisparte/docker-env"
  } | awk -F "|" '{printf "%-40s %s\n", $1, $2}'
}

# Prepare host files to map host user into dev env containers
_init_user() {
  mkdir -p "$USER_HOST_DIRECTORY"

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
  cat > "$USER_HOST_COMPOSE_ENV_FILE" << EOF
HOST_USER=$HOST_USER
HOST_UID=$HOST_UID
HOST_GID=$HOST_GID
HOST_SSH_AUTH_SOCK=$HOST_SSH_AUTH_SOCK
EOF

  # User compose file
  if [ ! -f "$USER_COMPOSE_FILE" ]; then
    cat > "$USER_COMPOSE_FILE" << EOF
services:
  user:
    # Add your customizations here, example:
    # volumes:
    #   - ./custom_volume:/custom_volume
EOF
  fi
}

_generate_project_base() {
  rm -rf "$PROJECT_CACHE_DIRECTORY"
  mkdir -p "$PROJECT_CACHE_DIRECTORY"

  cat > "$PROJECT_BASE_COMPOSE_FILE" << EOF
services:
  docker-env:
    extends:
      service: user
      file: $USER_COMPOSE_FILE
    env_file:
      - path: $PROJECT_ENV_FILE
        required: false
    environment:
      DOCKER_ENV: true
      SSH_AUTH_SOCK: \$HOST_SSH_AUTH_SOCK
      TERM:
      CI:
    user: \$HOST_UID:\$HOST_GID
    volumes:
      - \${HOST_SSH_AUTH_SOCK:-/dev/null}:\${HOST_SSH_AUTH_SOCK:-/dev/null}
      - $HOME/.config/docker-env/host/group:/etc/group:ro
      - $HOME/.config/docker-env/host/passwd:/etc/passwd:ro
      - $HOME/.config/docker-env/host/sudoer:/etc/sudoers.d/\$HOST_USER:ro
      - \$PWD:\$PWD
    working_dir: \$PWD
    entrypoint: ["$PROJECT_DOCKER_DIRECTORY/env.sh", "_entrypoint"]

EOF

  for DOCKERFILE in "$PROJECT_DOCKER_DIRECTORY"/*Dockerfile; do
    if [ ! -f "$DOCKERFILE" ]; then
      continue
    fi

    FILE_NAME="$(basename "$DOCKERFILE")"
    if [ "$FILE_NAME" = "Dockerfile" ]; then
      SERVICE=
    else
      SERVICE="$(echo "$FILE_NAME" | cut -d "." -f 1)"
    fi

    IMAGE="${DOCKER_ENV_REGISTRY:+$DOCKER_ENV_REGISTRY/}$PROJECT_NAME${SERVICE:+-$SERVICE}-env"
    cat >> "$PROJECT_BASE_COMPOSE_FILE" << EOF
  ${SERVICE:-dev}:
    extends:
      service: docker-env
    image: $IMAGE:${DOCKER_ENV_PULL_TAG:-latest}
    build:
      dockerfile: $DOCKERFILE
      pull: true
      cache_from:
        - $IMAGE:${DOCKER_ENV_PULL_TAG:-latest}
      cache_to:
        - type=inline
      tags:
        - $IMAGE:${DOCKER_ENV_PUSH_TAG:-latest}

EOF
  done
}

# Container entrypoint (used inside dev env containers)
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

# To use docker compose with project's compose file and docker-env configurations
_compose() {
  DOCKER_ENV_PROJECT_BASE_COMPOSE_FILE="$PROJECT_BASE_COMPOSE_FILE" \
    docker compose \
    --project-name "$PROJECT_NAME" \
    --env-file "$USER_HOST_COMPOSE_ENV_FILE" \
    --file "$PROJECT_COMPOSE_FILE" \
    "$@"
}

_is_up() {
  _compose ls --quiet | grep "$PROJECT_NAME" > /dev/null 2>&1
}

_up() {
  [ -d "$USER_DIRECTORY" ] || _init_user
  _generate_project_base
  _compose up --wait "$@"
}

COMMAND="${1:---help}"
if [ "$DOCKER_ENV" ]; then
  if [ "$COMMAND" = "_entrypoint" ]; then
    shift
    _entrypoint "$@"

  else
    echo "docker-env: Already inside a dev env container." >&2
    exit 1
  fi
fi

case "$COMMAND" in
  -h | --help)
    _help
    ;;

  shell)
    shift
    MAYBE_SERVICE="$1"
    _is_up || _up
    _compose exec \
      --env DOCKER_ENV_NAME="$PROJECT_NAME${MAYBE_SERVICE:+-$MAYBE_SERVICE}-env" \
      "${MAYBE_SERVICE:-$PROJECT_DEFAULT_SERVICE}" \
      "${SHELL:-/bin/sh}" --login
    ;;

  exec)
    shift
    if [ "$1" != "--" ]; then
      SERVICE="$1"
      shift

    else
      SERVICE="$PROJECT_DEFAULT_SERVICE"
    fi

    if [ "$1" != "--" ]; then
      echo "docker-env: Missing command separator '--'" >&2
      exit 1
    fi

    shift
    _is_up || _up
    _compose exec "$SERVICE" "$@"
    ;;

  up)
    shift
    _up "$@"
    ;;

  down)
    shift
    _compose down "$@"
    ;;

  compose)
    shift
    _compose "$@"
    ;;

  *)
    echo "docker-env: '$COMMAND' is not a docker-env command." >&2
    echo "See '$PROJECT_DOCKER_DIRECTORY/env.sh --help'" >&2
    exit 1
    ;;
esac
