---
title: Sand Package Manager
sidebar:
  order: 3
---

[Sand](https://github.com/praia-lang/sand) is the package manager for Praia. Written in Praia itself, it installs grains from Git repositories. Sand is bundled with Praia and installed automatically via `make install` — and unlike other tools, sand installs itself as a regular global grain, so it can update itself the same way it updates anything else.

## Requirements

Requires `git` on your PATH.

## Commands

```
sand init                      Create a grain.yaml in the current directory
sand init --plugin             Create a grain with a native C++ plugin
sand install                   Restore grains from sand-lock.yaml
sand install <url>             Install a grain locally (into ext_grains/)
sand install -g <url>          Install a grain globally (-g is short for --global)
sand update                    Re-fetch all grains pinned to "latest"
sand update <name>             Re-fetch a single grain from its source
sand update sand               Self-update sand itself (`sand install -g sand` works too)
sand lock                      Sync sand-lock.yaml with grain.yaml (install missing deps)
sand remove <name>             Remove a locally installed grain
sand remove --global <name>    Remove a globally installed grain
sand list                      List locally installed grains
sand list --global             List globally installed grains
sand info <name>               Show info about an installed grain
sand --version                 Print version
sand help                      Show help
```

## install vs update vs lock

| Command | Source | Effect on lockfile | When to use |
|---------|--------|--------------------|-------------|
| `sand install` | sand-lock.yaml | Preserves dates | Restoring a project (e.g. after `git clone`) |
| `sand update` | git remote | Updates dates | Bumping `latest`-pinned grains to current upstream |
| `sand lock` | grain.yaml | Adds missing entries | After manually editing `grain.yaml` |

`sand update` accepts an optional grain name to bump just one grain. Without a name, it re-fetches every grain whose lockfile entry has `version: latest`.

`sand lock` does NOT prune entries that aren't declared in `grain.yaml` — those may be transitive dependencies you don't see directly. Use `sand remove <name>` to drop entries explicitly.

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

Use `--global` (or `-g`) to install where every project on your machine can see them:

- **As a regular user**: `~/.praia/ext_grains/<name>/`.
- **As root** (via `sudo sand install -g ...`): `<libdir>/ext_grains/<name>/` — typically `/usr/local/lib/praia/ext_grains/`.

CLI wrappers from a grain's [`bin:` section](#cli-grains-the-bin-section) land in the matching bindir: `~/.praia/bin/` for user scope, `/usr/local/bin/` for root.

Praia resolves a `use "<name>"` import in this order:

1. `ext_grains/` (walks up from the importing file; `<cwd>/ext_grains/` only when there is no file, as in the REPL)
2. `grains/` (walks up from the importing file; `<cwd>/grains/` only when there is no file, as in the REPL)
3. `~/.praia/ext_grains/` (user-global)
4. `<libdir>/ext_grains/` (system-global — same dir sand installs to with `sudo`)
5. `<libdir>/grains/` (bundled standard library)

See the [Module System](/grains/modules/) page for the full search rules.

## CLI grains: the `bin:` section

A grain can declare command-line entry points in its `grain.yaml`. When the grain is installed globally, sand plants a shell wrapper on PATH for each entry.

```yaml
name: prscan
version: 0.1.0
main: main.praia
bin:
  prscan: bin/prscan.praia
```

```sh
sand install -g github.com/viggou/prscan
# → /usr/local/bin/prscan (root) or ~/.praia/bin/prscan (user)
prscan https://github.com/foo/bar/pull/42
```

The wrapper is a small shell script with absolute paths baked in:

```sh
#!/bin/sh
# sand-managed wrapper for prscan
exec "/usr/local/bin/praia" "/usr/local/lib/praia/ext_grains/prscan/bin/prscan.praia" "$@"
```

A few rules:

- **Wrappers go to a bindir on PATH.** Root installs to `<prefix>/bin`. User installs to `~/.praia/bin/` — sand prints a one-time advisory if it isn't on your `PATH`.
- **No bin generation on local installs.** Project-scoped `ext_grains/` is for `use "<name>"`, not for polluting your PATH. `bin:` entries are only honored under `-g`.
- **Reserved names.** `praia` and `sand` are reserved — only sand's own grain.yaml is allowed to declare them. Third-party grains are refused at install time.
- **Multiple bins per grain.** Map form supports any number of entries: `bin: { foo: bin/foo.praia, bar: bin/bar.praia }`.
- **Foreign-file safety.** If `<bindir>/<name>` already exists and isn't a sand-managed wrapper (sand looks for a `# sand-managed wrapper for <name>` sentinel on line 2), sand refuses to overwrite it.

On `sand remove -g <name>` the wrappers come back out. On `sand update -g <name>` they're regenerated — if the new version of the grain renamed a bin, the old wrapper is cleaned up.

## Updating sand itself

Sand is installed as a regular grain under `<libdir>/ext_grains/sand/` (alongside whatever else you've installed), so it updates itself the same way it updates anything else:

```sh
sand update sand
# or, equivalently:
sand install -g sand
```

If sand was installed system-wide via `make install`, self-update needs `sudo`. Sand checks for this and prints a clean error before any network fetch:

```
$ sand update sand
error sand is installed system-wide at /usr/local/lib/praia/ext_grains;
       re-run with sudo to self-update
```

The replacement uses an atomic swap (stage to a sibling `.new.<pid>` directory, rename the running sand to `.bak.<pid>`, rename `.new` → final, delete `.bak`). If anything fails between the renames, sand restores from `.bak.<pid>` so a botched update never leaves you without a working sand.

## Project manifest

Run `sand init` to create a `grain.yaml` and `main.praia`. The generated manifest looks like this (with two example dependencies filled in):

```yaml
name: my-project
version: 0.1.0
description: A short description
author: username
license: MIT
main: main.praia
# bin: declares CLI entry points planted on PATH when this
# grain is installed globally (`sand install -g`). Each key is
# the command name, each value a relative .praia file. Leave
# empty for libraries. Example:
#   bin:
#     my-project: main.praia
bin:
dependencies:
  db: github.com/user/praia-db
  dotenv: github.com/user/praia-dotenv
```

The `bin:` section is live but empty by default — leave it as-is for libraries. To ship a CLI, replace the empty `bin:` line with key/value pairs as shown in the comment (also see [CLI grains](#cli-grains-the-bin-section) above). `sand init --plugin` produces the same `bin:` scaffolding alongside the C++ plugin files.

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

### Native plugins

If your grain ships a C++ plugin (a `plugins/` directory with `.cpp` source), users normally need a C++ toolchain installed to build it. You can skip that step for them by publishing prebuilt `.dylib`/`.so` binaries to a GitHub Release and declaring them under a `prebuilt:` block in `grain.yaml` -- sand will download, verify the sha256, and install the binary directly. See [Distributing prebuilt binaries](/docs/advanced/plugins#distributing-prebuilt-binaries) on the plugins page for the schema and authoring workflow.

## How it works

- `sand install <url>` clones the repo, reads the grain's `grain.yaml` for its name, and copies it into `ext_grains/<name>/`.
- Installed grains are tracked in `sand-lock.yaml` (local) or `<install-dir>/.sand-lock.yaml` (global).
- `sand install` with no arguments restores from `sand-lock.yaml`.
- Multi-file grains work because relative imports (`use "./helpers"`) resolve from the grain's own directory.
- Sand itself lives at `<libdir>/ext_grains/sand/` and is treated like any other globally installed grain. There's no separate "system sand" code path — `sand update sand` runs the same installer the user runs for third-party grains.

See also: [Module System](/grains/modules/) for how grain resolution works.
