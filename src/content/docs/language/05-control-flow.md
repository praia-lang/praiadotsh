---
title: Control Flow
sidebar:
  order: 5
---

## if / elif / else

Conditions are always wrapped in parentheses. Bodies use braces.

```praia
let score = 85

if (score >= 90) {
    print("A")
} elif (score >= 80) {
    print("B")
} elif (score >= 70) {
    print("C")
} else {
    print("F")
}
```

## match

Match a value against multiple cases. Cases are tested top-to-bottom; first match wins. Use `_` for the default case.

```praia
let cmd = "stop"

match (cmd) {
    "start" { print("starting") }
    "stop" { print("stopping") }
    "restart" { print("restarting") }
    _ { print("unknown command") }
}
```

Cases can be any expression (compared with `==`):

```praia
let x = 10

match (x) {
    5 * 2 { print("ten") }
    5 * 3 { print("fifteen") }
    _ { print("other") }
}
// ten
```

### Type patterns with `is`

Use `is` to match by type name or class:

```praia
match (value) {
    is "int"    { print("integer") }
    is "string" { print("string") }
    is "array"  { print("array") }
    is MyClass  { print("a MyClass instance") }
    _           { print("something else") }
}
```

### Guard clauses with `when`

Use `when` for conditional matching:

```praia
let score = 85

match (score) {
    when score >= 90 { print("A") }
    when score >= 80 { print("B") }
    when score >= 70 { print("C") }
    _                { print("F") }
}
// B
```

### Mixing patterns

Equality, type, and guard patterns can be freely mixed:

```praia
let x = -5

match (x) {
    0           { print("zero") }
    when x > 0  { print("positive") }
    when x < 0  { print("negative") }
}
```

If no case matches and there is no default, nothing happens.

## while

```praia
let i = 0
while (i < 5) {
    print(i)
    i++
}
```

## for (range)

`for (var in start..end)` -- end is exclusive.

```praia
for (i in 0..5) {
    print(i)            // 0, 1, 2, 3, 4
}

let n = 10
for (i in 1..n + 1) {
    print(i)            // 1 through 10
}
```

## for-in (arrays)

```praia
let names = ["alice", "bob", "charlie"]
for (name in names) {
    print("hello %{name}")
}
```

## for-in (maps)

Iterating a map yields `{key, value}` entries. You can destructure directly:

```praia
let config = {host: "localhost", port: 8080}

// Destructuring (preferred)
for ({key, value} in config) {
    print("%{key}: %{value}")
}

// Without destructuring
for (entry in config) {
    print("%{entry.key}: %{entry.value}")
}
```

## break and continue

`break` exits the innermost loop. `continue` skips to the next iteration. Both work in `while`, `for`, and `for-in`.

```praia
// Skip odd numbers
for (i in 0..10) {
    if (i % 2 != 0) { continue }
    print(i)                        // 0, 2, 4, 6, 8
}

// Stop at first match
let names = ["alice", "bob", "charlie"]
for (name in names) {
    if (name == "bob") { break }
    print(name)                     // alice
}

// break in while
let n = 0
while (true) {
    if (n >= 3) { break }
    print(n)                        // 0, 1, 2
    n++
}
```

In nested loops, `break` and `continue` only affect the innermost loop.
