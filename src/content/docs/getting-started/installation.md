---
title: Installation
sidebar:
  order: 1
---

## Quick install

The fastest way to install Praia on macOS or Linux:

```sh
curl -fsSL https://praia.sh/install.sh | sh
```

This downloads the latest release binary for your platform and installs it to `/usr/local/bin/`. It also installs the standard library grains and the [sand](/grains/sand/) package manager.

## Build from source

If you prefer to build from source, or need to customize the build:

### Clone the repository

```sh
git clone --recursive https://github.com/praia-lang/praia.git
cd praia
```

## Install dependencies (optional)

Praia builds without external libraries, but you lose HTTPS, SQLite, REPL history, Unicode-aware strings, and the RE2 regex engine.

**macOS:**

```sh
brew install openssl@3 readline sqlite utf8proc re2
```

**Ubuntu / Debian:**

```sh
sudo apt install g++ make libssl-dev libreadline-dev libsqlite3-dev libutf8proc-dev libre2-dev
```

**Fedora / RHEL:**

```sh
sudo dnf install gcc-c++ make openssl-devel readline-devel sqlite-devel utf8proc-devel re2-devel
```

### What each dependency enables

| Dependency | Enables | Required? |
|------------|---------|-----------|
| OpenSSL | HTTPS client (`http.get("https://...")`) | Optional |
| SQLite | `sqlite.open()` built-in | Optional |
| readline/libedit | REPL history and line editing | Optional |
| utf8proc | Unicode-aware strings (grapheme splitting, case mapping, emoji) | Optional |
| RE2 | Safe regex engine (O(n) guaranteed, no catastrophic backtracking) | Optional -- falls back to `std::regex` |

## Build and install

```sh
make
sudo make install
```

This installs `praia` and `sand` (the package manager) to `/usr/local/bin/`, with stdlib grains in `/usr/local/lib/praia/`.

To customize the install location:

```sh
sudo make install PREFIX=/usr              # /usr/bin/praia, /usr/lib/praia/
sudo make install LIBDIR=/opt/praia/lib    # custom lib path
```

## Uninstall

```sh
sudo make uninstall
```

## Building without installing

If you just want to build and run locally:

```sh
make
./praia                   # REPL
./praia script.praia      # run a file
./praia -v                # print version
```

## Running tests

```sh
make test                 # run the test suite
./praia test              # same thing
./praia test path/to/dir  # test a specific directory
```

## Platform support

Praia uses POSIX APIs and runs on macOS, Linux, and Windows via WSL. It should work on BSD but is untested. There is no native Windows support.
