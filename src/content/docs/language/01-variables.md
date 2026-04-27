---
title: Variables
sidebar:
  order: 1
---

## Declaring variables

Declare variables with `let`. Uninitialized variables are `nil`.

```praia
let name = "Ada"
let age = 36
let score              // nil

age = 37               // reassignment
```

## Constants (convention)

Use `UPPER_SNAKE_CASE` for values that should not change. Praia warns on reassignment:

```praia
let MAX_RETRIES = 3
let BASE_URL = "https://api.example.com"

MAX_RETRIES = 5        // Warning: reassigning constant 'MAX_RETRIES'
```

This is a convention, not a hard error -- the reassignment still happens, but the warning signals a likely mistake. Single-letter names like `N` or `X` do not trigger the warning.

## Destructuring

Unpack arrays and maps into variables in a single `let` statement.

### Array destructuring

```praia
let [a, b, c] = [1, 2, 3]
print(a, b, c)              // 1 2 3

let [first, ...rest] = [1, 2, 3, 4, 5]
print(first)                 // 1
print(rest)                  // [2, 3, 4, 5]
```

Missing elements become `nil`:

```praia
let [x, y, z] = [1, 2]
print(z)                     // nil
```

### Map destructuring

```praia
let {name, age} = {name: "Ada", age: 36}
print(name, age)             // Ada 36
```

Rename with `key: varName`:

```praia
let {name: userName, age: userAge} = {name: "Ada", age: 36}
print(userName)              // Ada
```

Rest collects remaining keys:

```praia
let {name, ...other} = {name: "Ada", age: 36, lang: "Praia"}
print(other)                 // {age: 36, lang: "Praia"}
```

## Spread operator

The `...` operator spreads arrays and maps into literals.

### Array spread

```praia
let a = [1, 2, 3]
let b = [4, 5, 6]
let combined = [...a, ...b]       // [1, 2, 3, 4, 5, 6]
let withExtra = [0, ...a, 99]     // [0, 1, 2, 3, 99]
```

### Map spread

```praia
let defaults = {host: "localhost", port: 8080}
let overrides = {port: 3000, debug: true}
let config = {...defaults, ...overrides}
// {host: "localhost", port: 3000, debug: true}
```

Later spreads override earlier keys.

### Spread in function calls

```praia
func add(a, b, c) { return a + b + c }
let args = [1, 2, 3]
print(add(...args))       // 6
```

This enables generic function wrappers:

```praia
func wrapper(fn) {
    return lam{ ...args in fn(...args) }
}
```
