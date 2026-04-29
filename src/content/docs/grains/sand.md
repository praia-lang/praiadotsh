---
title: Sand Package Manager
sidebar:
  order: 3
---

[Sand](https://github.com/praia-lang/sand) is the package manager for Praia. Written in Praia itself, it installs grains from Git repositories. Sand is bundled with Praia and installed automatically via `make install`.

## Requirements

Requires `git` on your PATH.

## Commands

```
sand init                      Create a grain.yaml in the current directory
sand init --plugin             Create a grain with a native C++ plugin
sand install                   Install or update grains from sand-lock.yaml
sand install <url>             Install a grain locally (into ext_grains/)
sand install --global <url>    Install a grain globally (into ~/.praia/ext_grains/)
sand remove <name>             Remove a locally installed grain
sand remove --global <name>    Remove a globally installed grain
sand list                      List locally installed grains
sand list --global             List globally installed grains
sand info <name>               Show info about an installed grain
sand --version                 Print version
sand help                      Show help
```

## Installing grains

```sh
# Install locally (into ext_grains/)
sand install github.com/user/mygrain

# Pinned to a version (git tag)
sand install github.com/user/mygrain@0.2.0

# From any git URL
sand install https://gitlab.com/user/mygrain.git

# Install globally (shared across all projects)
sand install --global github.com/user/mygrain
```

Then use it in your code:

```praia
use "mygrain"
mygrain.doSomething()
```

## Installing from lock file

Running `sand install` with no arguments reads `sand-lock.yaml` and installs any missing grains. Grains pinned to `latest` are re-fetched for updates.

```sh
git clone https://github.com/user/myproject.git
cd myproject
sand install
```

## Local vs global

By default, grains install **locally** into `ext_grains/`, tracked in `sand-lock.yaml`. Each project has isolated dependencies.

Use `--global` (or `-g`) to install into `~/.praia/ext_grains/`, making the grain available to all projects.

Praia resolves grains in this order:

1. `ext_grains/` (local project dependencies)
2. `grains/` (bundled with your project)
3. `~/.praia/ext_grains/` (user global)
4. `<libdir>/grains/` (system, installed with Praia)

## Project manifest

Run `sand init` to create a `grain.yaml` and `main.praia`:

```yaml
name: my-project
version: 0.1.0
description: A short description
author: username
license: MIT
main: main.praia
dependencies:
  db: github.com/user/praia-db
  dotenv: github.com/user/praia-dotenv
```

When you `sand install <url>`, the dependency is automatically added to `grain.yaml` if one exists. Transitive dependencies listed in a grain's own `grain.yaml` are installed automatically.

## Publishing a grain

A grain is a Git repository with a `grain.yaml` and Praia source files:

```
my-grain-repo/
  grain.yaml       # name: mygrain
  main.praia       # entry point
  helpers.praia    # internal module (use "./helpers")
```

```yaml
name: mygrain
version: 0.1.0
main: main.praia
dependencies:
```

Tag releases with git tags for versioned installs:

```sh
git tag 0.1.0
git push origin 0.1.0
```

## How it works

- `sand install <url>` clones the repo, reads the grain's `grain.yaml` for its name, and copies it into `ext_grains/<name>/`
- Installed grains are tracked in `sand-lock.yaml` (local) or `~/.praia/ext_grains/.sand-lock.yaml` (global)
- `sand install` with no arguments restores from `sand-lock.yaml`
- Multi-file grains work because relative imports (`use "./helpers"`) resolve from the grain's own directory

See also: [Module System](/grains/modules/) for how grain resolution works.
