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

### Recommendations

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

Assuming your Docker daemon is running:

1. `./docker/env.sh init` To pull and/or build the image and create host files.
2. `./docker/env.sh up` To create and start a dev container.
3. `./docker/env.sh shell` To open a shell inside the running dev container.
4. Develop (optionally, attach your editor/IDE to the running dev container).
5. `exit` to close the shell and return to the host computer.
6. `./docker/env.sh down` To stop and remove the running dev container.

> Again, using a `$HOME/.config/docker-env/compose.yaml` file will allow you to mount your
>  personal configurations in the container for a more familiar environment.

#### CI/CD

1. `./docker/env.sh init` To pull and/or build the image and host files.
2. `./docker/env.sh up` To create and start a dev container.
3. `./docker/env.sh exec COMMAND` To run a command inside the dev container (like running
   tests).
4. `./docker/env.sh down` To stop and remove the running dev container.

> You can also use the `tag`, `push` and `pull` subcommands to manage your dev image registry
>  versioning.

## Contributors

```shell
git clone git@github.com:logisparte/docker-env.git
cd docker-env
git config --local core.hooksPath "$PWD/hooks"
```

> The git hooks will format and lint code before commit, and the git messages will be linted
>  using `commitlint`.

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

To format all files:

```shell
./scripts/format.sh all
```

#### Lint

[ShellCheck](https://github.com/koalaman/shellcheck) is used to analyze shell code.
[MarkdownLint](https://github.com/igorshubovych/markdownlint-cli) is used to analyze markdown
code. To analyze dirty files:

```shell
./scripts/lint.sh
```

To analyze all files:

```shell
./scripts/lint.sh all
```
