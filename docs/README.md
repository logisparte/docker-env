# docker-env

Encapsulate your project's development environment inside a Docker container.

## License

This repository is distributed under the terms of the [Apache 2.0 license](/LICENSE).

## Users

### Installation

Installation in a project is a short manual process, detailed as follows:

- Copy/paste all files in [`/src`](/src) into your project's `/docker` directory.
- Also create a `Dockerfile` in your project's `/docker` directory to define its development
  environment. **This image is not intended to run in production, just during development**. You
  should use one of the templates in [`/templates`](/templates) as a starting point.
- Optionally, create a `compose.yaml` file in your `$HOME/.config/docker-env` directory using
  the `user.compose.yaml` template in [`/templates`](/templates). This file will be used to
  mount your personal configurations in your development containers.
- Run `./docker/env.sh init`

Now you're ready to start using `docker-env` in your project. Run `./docker/env.sh --help` for
more information on general usage.

### Multiple environments

You can also use multiple environment images, each with their own Dockerfiles. To do so, simply
prefix each Dockerfile with the corresponding service name, example:

Instead of simply:

`./docker/Dockerfile` -> `dev` service in your project's compose.yaml file

Do:

`./docker/server.Dockerfile` -> `server` service in your project's compose.yaml file
`./docker/app.Dockerfile` -> `app` service in your project's compose.yaml file

### Environment variables

You can customize the following environment variables:

<!-- markdownlint-disable MD013 -->

| var                                  | default                 | description                                                      |
| ------------------------------------ | ----------------------- | ---------------------------------------------------------------- |
| `DOCKER_ENV_PROJECT_NAME`            | Repository name         | Name of your project (used to generated images and containers)   |
| `DOCKER_ENV_PROJECT_COMPOSE_FILE`    | `./docker/compose.yaml` | The dev env compose file, where services are defined             |
| `DOCKER_ENV_PROJECT_CACHE_DIRECTORY` | `./.cache/docker-env`   | Where docker-env will store its generated files for your project |
| `DOCKER_ENV_PROJECT_DEFAULT_SERVICE` | dev                     | Default dev env service to use when unspecified                  |
| `DOCKER_ENV_REGISTRY`                | -                       | Registry where built images will be pulled/pushed from/to        |
| `DOCKER_ENV_BASE_TAG`                | latest                  | Image tag to build/pull from registry                            |
| `DOCKER_ENV_BUILD_TAGS`              | -                       | Extra image tags to add when building images                     |
| `DOCKER_ENV_BUILD_PLATFORMS`         | -                       | Target platforms when building images                            |

These variables are readonly:

| var                                    | value                                                   | description                                                                                                            |
| -------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `DOCKER_ENV`                           | true                                                    | Only available inside a dev env container                                                                              |
| `DOCKER_ENV_NAME`                      | Name of the current environment                         | Only available inside a dev env container                                                                              |
| `DOCKER_ENV_SERVICE`                   | Name of the current service                             | Only available inside a dev env container                                                                              |
| `DOCKER_ENV_PROJECT_BASE_COMPOSE_FILE` | `$DOCKER_ENV_PROJECT_CACHE_DIRECTORY/base.compose.yaml` | Generated base compose file that **must** be extended by your dev-env service(s) in `$DOCKER_ENV_PROJECT_COMPOSE_FILE` |

<!-- markdownlint-enable MD013 -->

### Recommendations

### Add .cache directory to .gitignore

`docker-env` stores a generated base compose.yaml file for your project in `.cache/docker-env`.
This file should not be commited as it may contain user-specific paths.

#### Alias

You should create an alias for `./docker/env.sh` as it's going to be tedious to type it all the
time otherwise.

#### Registry

To speed up development and continuous integration, it's recommended to push your dev image to
your organization's registry. Doing so will allow `docker-env` to pull its latest version and
use it as cache when rebuilding the image. To do so, simply set the registry variable in your
environment:

```shell
export DOCKER_ENV_REGISTRY="ghcr.io/<FOO>" # or any other container registry
```

### Workflows

#### Local development

Assuming your Docker daemon is running, just run `./docker/env.sh shell` to build/pull images,
create containers, start them and open an interactive shell in the dev env container.

> Again, customizing the `$HOME/.config/docker-env/compose.yaml` file will allow you to mount
> your personal configurations in the container for a more familiar environment.

#### CI workflows

You can use `./docker/env.sh exec -- COMMAND` to build/pull images, create containers, start
them and execute a command in the dev env container. The `compose` and `tag` subcommands,
alongside some [environment variables](#environment-variables) can also be used to craft
efficient workflows.

> You can look at this repo's CI/CD workflows for inspiration

#### Winding down

When done, you can stop and remove the environment using `./docker/env.sh compose down` (like
any other docker compose environment)

## Contributors

```shell
git clone git@github.com:logisparte/docker-env.git
cd docker-env
./scripts/setup.sh # install git hooks
```

> The git hooks will format and lint code before commit, and the git messages will be linted
> using `commitlint`.

### Environment

The `docker-env` project uses itself to encapsulate its development environment inside a Docker
container! To achieve this, there are some symlinks set up in `/docker` that point to the source
files alongside the project's `Dockerfile`. This allows to have quick, local feedback on
changes.

### Scripts

#### Format

[shfmt](https://github.com/mvdan/sh) is used to format shell files.
[Prettier](https://github.com/prettier/prettier) is used to format markdown and yaml files. To
format dirty files:

```shell
./scripts/format.sh
```

#### Lint

[ShellCheck](https://github.com/koalaman/shellcheck) is used to analyze shell code.
[MarkdownLint](https://github.com/igorshubovych/markdownlint-cli) is used to analyze markdown
code. To analyze dirty files:

```shell
./scripts/lint.sh
```
