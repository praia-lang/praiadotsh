---
title: REPL
sidebar:
  order: 3
---

Run `praia` with no arguments to start the interactive REPL (Read-Eval-Print Loop).

```
$ praia
Praia REPL (type 'exit' to quit)
>> 2 + 3
5
>> let x = 10
>> x * 2
20
>> "hello".upper()
HELLO
```

## Features

- **Arrow keys** for command history (up/down) and line editing (left/right). Requires readline or libedit.
- **Auto-print** -- expression results are printed automatically. `nil` results are hidden.
- **Multi-line input** -- detected automatically when braces are unbalanced:

```
>> func greet(name) {
..   print("hello %{name}")
.. }
>> greet("world")
hello world
```

- **Persistent state** -- variables, functions, and classes survive between inputs.
- **Exit** with `Ctrl-D` or type `exit`.

## Command-line flags

```sh
praia                             # start REPL
praia --tree                      # REPL with tree-walker interpreter
```

The REPL uses the bytecode VM by default. Pass `--tree` to use the tree-walking interpreter instead.
