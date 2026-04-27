---
title: Error Handling
sidebar:
  order: 9
---

## try / catch

Wrap code that might fail in a `try` block. If an error occurs, execution jumps to `catch` with the error value.

```praia
try {
    let data = sys.read("config.txt")
    print(data)
} catch (err) {
    print("failed to read config:", err)
}
```

## finally

A `finally` block runs cleanup code regardless of success or failure:

```praia
let file = sys.read("data.txt")
try {
    process(file)
} catch (err) {
    print("error:", err)
} finally {
    cleanup()    // always runs
}
```

## throw

Throw any value as an error. If not caught, the program terminates.

```praia
func divide(a, b) {
    if (b == 0) {
        throw "division by zero"
    }
    return a / b
}

try {
    print(divide(10, 0))
} catch (err) {
    print("error:", err)     // error: division by zero
}
```

You can throw any value -- strings, numbers, maps:

```praia
throw {code: 404, message: "not found"}
```

Runtime errors (type errors, index out of bounds, etc.) are also caught:

```praia
try {
    let arr = [1, 2, 3]
    print(arr[99])
} catch (err) {
    print(err)              // Array index out of bounds
}
```

## ensure

`ensure` is an early-exit guard (like Swift's `guard`). If the condition is falsy, the `else` block runs -- which should exit the scope (typically `return` or `throw`).

```praia
func greet(name) {
    ensure (name) else {
        print("no name provided")
        return
    }
    print("hello %{name}!")
}

greet("Ada")    // hello Ada!
greet(nil)      // no name provided
```

`ensure` is useful for input validation:

```praia
func processAge(age) {
    ensure (type(age) == "int") else {
        throw "age must be a number"
    }
    ensure (age >= 0 && age <= 150) else {
        throw "age out of range"
    }
    print("valid age: %{age}")
}
```

## Error stack traces

When an error occurs inside nested function calls, Praia prints the full call stack:

```
[line 3] Runtime error: Division by zero
  at divide() line 7
  at calculate() line 11
  at main() line 14
```

Caught errors (via `try/catch`) do not print a trace -- only uncaught errors that terminate execution.
