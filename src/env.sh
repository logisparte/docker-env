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
if [ -f "$PWD/.env" ]; then
  set -a
  . "$PWD/.env"
  set +a
fi

PROJECT_NAME="${DOCKER_ENV_PROJECT_NAME:-"$(basename "$PWD")"}"
PROJECT_COMPOSE_FILE="${DOCKER_ENV_PROJECT_COMPOSE_FILE:-"$PWD/docker/compose.yaml"}"
PROJECT_CACHE_DIRECTORY="${DOCKER_ENV_PROJECT_CACHE_DIRECTORY:-$PWD/.cache/docker-env}"
PROJECT_BASE_COMPOSE_FILE="$PROJECT_CACHE_DIRECTORY/base.compose.yaml"
PROJECT_DEFAULT_SERVICE="${DOCKER_ENV_PROJECT_DEFAULT_SERVICE:-"dev"}"
BASE_TAG="${DOCKER_ENV_BASE_TAG:-latest}"
BUILD_TAGS="${DOCKER_ENV_BUILD_TAGS:-}"
BUILD_PLATFORMS="${DOCKER_ENV_BUILD_PLATFORMS:-}"

_help() {
  {
    echo
    echo "Usage: ./docker/env.sh COMMAND [OPTIONS] [ARGS...]"
    echo
    echo "Encapsulate your project's dev environment inside one or more Docker containers using docker compose"
    echo
    echo "Commands:"
    echo "  shell [SERVICE]|Open an interactive shell in a dev env container"
    echo "  exec [SERVICE] -- COMMAND|Execute a command in a dev env container"
    echo "  compose [ARGUMENTS...]|Directly call 'docker compose' with project settings"
    echo
    echo \
      "For more info on how to use docker-env, head to https://github.com/logisparte/docker-env"
  } | awk -F "|" '{printf "%-40s %s\n", $1, $2}'
}

_init_user() {
  #
  # Prepare host files to map host user into dev env containers
  #

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
    echo "docker-env: This script will generate a 'sudoers.d' file to be mounted in" \
      "development containers. As this file needs to be owned by the root user, your password" \
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

  # User compose file
  if [ ! -f "$USER_COMPOSE_FILE" ]; then
    {
      echo "services:"
      echo "  user:"
      echo "    # Add your customizations here, example:"
      echo "    # volumes:"
      echo "    #   - ./custom_volume:/custom_volume"
    } > "$USER_COMPOSE_FILE"
  fi
}

_generate_project_base() {
  #
  # Generate base compose.yaml file for local project, based on user host files and
  # customizations
  #

  rm -rf "$PROJECT_CACHE_DIRECTORY"
  mkdir -p "$PROJECT_CACHE_DIRECTORY"
  {
    if [ -n "$BUILD_PLATFORMS" ]; then
      echo "x-platforms: &platforms"
      echo "  platforms:"
      (
        IFS=','
        for PLATFORM in $BUILD_PLATFORMS; do echo "    - $PLATFORM"; done
      )
      echo
    fi

    echo "services:"
    echo "  docker-env:"
    echo "    extends:"
    echo "      service: user"
    echo "      file: \$HOME/.config/docker-env/compose.yaml"
    echo "    env_file:"
    echo "      - path: \$PWD/.env"
    echo "        required: false"
    echo "    environment:"
    echo "      DOCKER_ENV: true"
    echo "      SSH_AUTH_SOCK: \$HOST_SSH_AUTH_SOCK"
    echo "      TERM:"
    echo "      CI:"
    echo "    user: \$HOST_UID:\$HOST_GID"
    echo "    volumes:"
    echo "      - \${HOST_SSH_AUTH_SOCK:-/dev/null}:\${HOST_SSH_AUTH_SOCK:-/dev/null}"
    echo "      - \$HOME/.config/docker-env/host/group:/etc/group:ro"
    echo "      - \$HOME/.config/docker-env/host/passwd:/etc/passwd:ro"
    echo "      - \$HOME/.config/docker-env/host/sudoer:/etc/sudoers.d/\$HOST_USER:ro"
    echo "      - \$PWD:\$PWD"
    echo "    working_dir: \$PWD"
    echo "    entrypoint: [\"\$PWD/docker/env.sh\", \"_entrypoint\"]"
    echo

    for DOCKERFILE in "$PWD"/docker/*Dockerfile; do
      if [ ! -f "$DOCKERFILE" ]; then
        continue
      fi

      FILE_NAME="$(basename "$DOCKERFILE")"
      if [ "$FILE_NAME" = "Dockerfile" ]; then
        _SERVICE=
      else
        _SERVICE="$(echo "$FILE_NAME" | cut -d "." -f 1)"
      fi

      IMAGE="${DOCKER_ENV_REGISTRY:+$DOCKER_ENV_REGISTRY/}$PROJECT_NAME${_SERVICE:+-${_SERVICE}}-env"
      echo "  ${_SERVICE:-$PROJECT_DEFAULT_SERVICE}:"
      echo "    extends:"
      echo "      service: docker-env"
      echo "    image: $IMAGE:$BASE_TAG"
      echo "    build:"
      echo "      dockerfile: \$PWD/docker/$FILE_NAME"
      echo "      pull: true"
      echo "      cache_from:"
      echo "        - $IMAGE:$BASE_TAG"
      echo "      cache_to:"
      echo "        - type=inline"

      if [ -n "$BUILD_PLATFORMS" ]; then
        echo "      <<: *platforms"
      fi

      if [ -n "$BUILD_TAGS" ]; then
        echo "      tags:"
        (
          IFS=','
          for TAG in $BUILD_TAGS; do echo "        - $IMAGE:$TAG"; done
        )
      fi

      echo
    done
  } > "$PROJECT_BASE_COMPOSE_FILE"
}

_entrypoint() {
  #
  # Container entrypoint (used inside dev env containers)
  #

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

_init() {
  [ -d "$USER_DIRECTORY" ] || _init_user
  _generate_project_base
}

_compose() {
  DOCKER_ENV_PROJECT_BASE_COMPOSE_FILE="$PROJECT_BASE_COMPOSE_FILE" \
    docker compose \
    --project-name "$PROJECT_NAME" \
    --env-file "$USER_HOST_COMPOSE_ENV_FILE" \
    --file "$PROJECT_COMPOSE_FILE" \
    "$@"
}

_ensure_up() {
  _compose ls --quiet | grep "$PROJECT_NAME" > /dev/null 2>&1 || _compose up --wait
}

_tag() {
  TARGET_TAG="$1"
  if [ -z "$TARGET_TAG" ]; then
    echo "docker-env: Missing tag argument" >&2
    echo "  Usage: ./docker/env.sh tag TARGET_TAG"
    exit 1
  fi

  DEV_IMAGES="$({
    docker image ls --format "{{.Repository}}:{{.Tag}}" \
      | grep "-env:$BASE_TAG" \
      | sort -u
  })"

  for DEV_IMAGE in $DEV_IMAGES; do
    DEV_IMAGE_REPOSITORY=$(echo "$DEV_IMAGE" | awk -F: '{print $1}')
    docker image tag "$DEV_IMAGE" "$DEV_IMAGE_REPOSITORY:$TARGET_TAG"
  done
}

COMMAND="${1:---help}"
if [ "$DOCKER_ENV" ]; then
  if [ "$COMMAND" = "_entrypoint" ]; then
    _entrypoint "$@"

  else
    echo "docker-env: Already inside a dev env container." >&2
    exit 1
  fi
else
  case "$COMMAND" in
    -h | --help)
      _help
      ;;

    shell)
      shift
      MAYBE_SERVICE="$1"

      _init
      _ensure_up
      _compose exec \
        --env DOCKER_ENV_NAME="$PROJECT_NAME${MAYBE_SERVICE:+-$MAYBE_SERVICE}-env" \
        "${MAYBE_SERVICE:-$PROJECT_DEFAULT_SERVICE}" \
        "${SHELL:-/bin/sh}" --login
      ;;

    exec)
      shift
      case "$*" in
        "-- "*)
          SERVICE="$PROJECT_DEFAULT_SERVICE"
          shift
          ;;

        *" -- "*)
          SERVICE="$1"
          shift 2
          ;;

        *)
          echo "docker-env: Missing exec arguments" >&2
          echo "  Usage: ./docker/env.sh exec [SERVICE] -- COMMAND"
          exit 1
          ;;
      esac

      _init
      _ensure_up
      _compose exec "$SERVICE" "$@"
      ;;

    tag)
      shift
      _init
      _tag "$@"
      ;;

    compose)
      shift
      _init
      _compose "$@"
      ;;

    *)
      echo "docker-env: '$COMMAND' is not a docker-env command." >&2
      echo "See './docker/env.sh --help'" >&2
      exit 1
      ;;
  esac
fi
