---
title: Hello World
sidebar:
  order: 2
---

## Your first program

Create a file called `hello.praia`:

```praia
print("Hello, World!")
```

Run it:

```sh
praia hello.praia
```

## Basic syntax

Praia uses familiar C-style syntax with some differences.

### Variables

Declare variables with `let`:

```praia
let name = "Praia"
let version = 1
let running = true
```

### Functions

Define functions with `func`:

```praia
func greet(name) {
    print("Hello, %{name}!")
}

greet("world")
```

### String interpolation

Use `%{expression}` inside strings:

```praia
let lang = "Praia"
print("%{lang} is fun!")
```

### Comments

```praia
// single-line comment

/* multi-line
   comment */
```

### Semicolons

Semicolons are optional. They are useful for one-liners:

```sh
praia -c 'let x = 1; let y = 2; print(x + y)'
```

## Running scripts

```sh
praia script.praia                # run a file
praia script.praia arg1 arg2      # with arguments (available via sys.args)
praia -c 'print("inline")'       # run a one-liner
```

## Next steps

- Learn about the [REPL](/getting-started/repl/) for interactive use
- Read about [variables](/language/01-variables/) and [types](/language/02-types/)
- See the full [operators](/language/04-operators/) reference
