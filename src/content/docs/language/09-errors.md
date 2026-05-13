---
title: Error Handling
sidebar:
  order: 9
---

## try / catch

Wrap code that might fail in a `try` block. If an error occurs, execution jumps to `catch` with the error value.

```praia
try {
    let data = fs.read("config.txt")
    print(data)
} catch (err) {
    print("failed to read config:", err)
}
```

## finally

A `finally` block runs cleanup code regardless of success or failure:

```praia
let file = fs.read("data.txt")
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

## defer

`defer` registers cleanup code to run when the function exits — on return, throw, or normal completion. Multiple defers run in LIFO order.

```praia
func processFile(path) {
    let db = sqlite.open("app.db")
    defer db.close()

    let sock = net.connect("host", 80)
    defer net.close(sock)
    // Both close automatically on exit
}
```

Defers run even on exceptions. If a defer throws, other defers still run.

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

## Interrupts (Ctrl+C)

Pressing Ctrl+C during execution throws `"Interrupted"`, which is catchable with `try/catch`:

```praia
try {
    for (i in 0..999999999) {
        doWork(i)
    }
} catch (err) {
    print("stopped: " + str(err))   // "stopped: Interrupted"
    cleanup()
}
```

Without a `try/catch`, Ctrl+C prints `Uncaught error: Interrupted` and exits. This is similar to Python's `KeyboardInterrupt`.
