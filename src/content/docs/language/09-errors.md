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

`finally` also runs when `return`, `break`, or `continue` leaves the `try` or `catch` block early. Nested `finally` blocks run innermost first.

## throw

Throw any value as an error. Praia ships a builtin `Error` class hierarchy — `Error` base plus typed subclasses (`TypeError`, `ValueError`, `IndexError`, `KeyError`, `NameError`, `AssertionError`, `IOError`, `NetworkError`, `HTTPError`, `TimeoutError`, `ParseError`) — so user code and the engine can surface structured errors instead of bare strings. If not caught by `try/catch`, the program terminates.

```praia
try {
    throw IOError("no such file", "/etc/config", 2)
} catch (e) {
    match (e) {
        is HTTPError    { print("http: " + str(e.status)) }
        is IOError      { print("io: " + e.message + " (errno=" + str(e.errno) + ")") }
        is TypeError    { print("type: " + e.message) }
        _               { print("other: " + str(e)) }
    }
}
```

**User throws are unchanged** — strings, maps, and tagged values still arrive at `catch (err)` verbatim.

```praia
throw "boom"                                // catch (err) → err == "boom"
throw {code: 404, message: "not found"}     // catch (err) → err.code
```

**Engine runtime errors** (type errors, index out of bounds, division by zero, IO failures, …) arrive as `Error` instances. Reach the message via `.message` or `str(err)`:

```praia
try {
    let arr = [1, 2, 3]
    print(arr[99])
} catch (e) {
    print(e is Error)  // true
    print(str(e))      // "Error: Array index out of bounds"
    print(e.message)   // "Array index out of bounds"
}
```

`Error` provides string-forwarding shims — `.contains(sub)`, `.startsWith(prefix)`, `.endsWith(suffix)` — that delegate to the stringified form, so `err.contains("Division")` keeps working. Concat with `str(err) + "…"` — `+` is deliberately not overloaded on `Error`.

### Builtin Error subclasses

| Class | Extends | Fields | Purpose |
|---|---|---|---|
| `Error` | — | `.message`, `.type`, `.line`, `.column` | Base — `is Error` catches every builtin type. |
| `TypeError` | `Error` | | Wrong type in an operation. |
| `ValueError` | `Error` | | Right type, invalid value. |
| `NameError` | `Error` | | Undefined variable / property / method. |
| `IndexError` | `Error` | `.index` | Out-of-bounds array/string access. |
| `KeyError` | `Error` | `.key` | Missing map key. |
| `AssertionError` | `Error` | | Assertion failure (`assert`, `testing.expect`). |
| `IOError` | `Error` | `.path`, `.errno` | Filesystem, subprocess, generic OS. |
| `NetworkError` | `IOError` | `.host`, `.port`, `.errno` | TCP/UDP/DNS. |
| `HTTPError` | `IOError` | `.status`, `.url`, `.body` | HTTP-level failures. |
| `TimeoutError` | `IOError` | | Any wait timeout. |
| `ParseError` | `Error` | `.line`, `.column`, `.source` | Parse failures. |

Each takes a message plus optional per-class fields as positional args (with `nil` defaults):

```praia
throw IOError("no such file", "/etc/config", 2)
throw HTTPError("bad gateway", 502, "http://api/x", "upstream error")
```

### Subclassing in user code

```praia
class ConfigError extends ValueError {
    func init(message, path) {
        super.init(message)
        this.type = "ConfigError"
        this.path = path
    }
}
throw ConfigError("bad json", "/etc/x")
// `is ConfigError`, `is ValueError`, `is Error` all match in a catch.
```

## defer

`defer` registers cleanup code to run when the function exits — on return, throw, or normal completion. Multiple defers run in LIFO order.

```praia
func processFile(path) {
    let db = sqlite.open("app.db")
    defer sqlite.close(db)

    let sock = net.connect("host", 80)
    defer net.close(sock)
    // Both close automatically on exit
}
```

Defers run even on exceptions. If a defer throws, other defers still run.

`defer` also works at the **top level of a script** — useful for closing sqlite handles, flushing logs, or restoring terminal state before the program exits. Top-level defers fire when the script finishes (normal completion, uncaught throw, or `sys.exit()`). Note the REPL is the one exception: defers entered at the prompt are silently dropped because there is no defined script end.

At the top level of a grain, defers fire when the grain finishes loading (after its last statement or `export`, or when it throws), before the importing code continues.

## ensure

`ensure` is an early-exit guard, modelled on Swift's `guard`. If the condition is falsy, the `else` block runs — and the `else` block **must** terminate. Code after `ensure` only runs when the condition held, and the parser enforces this property by recognising exactly these terminators:

- `return` (with or without a value)
- `throw`
- `break` or `continue` (inside a loop)
- a nested `if`/`elif`/`else` where every branch terminates (the parser only checks each branch terminates — mixing kinds is fine, e.g. one branch can `return` while another `throw`s)
- a block whose last statement terminates

The check is purely syntactic — function calls like `sys.exit(1)` are *not* recognised on their own (a shadowed `sys` could silently subvert that guarantee). For CLI bail-out write `sys.exit(1); return` — the unreachable `return` gives the parser its terminator.

Anything else is a parse error:

```text
[line 3:col 5] Error at 'ensure': ensure: else block must terminate
via 'return', 'throw', 'break', or 'continue' (use 'if' for log-
and-continue)
```

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

With a single statement, the braces can go:

```praia
func half(n) {
    ensure (n % 2 == 0) else return nil
    return n / 2
}
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

### Optional unwrap binding — `ensure let`

Praia also supports Swift-style `guard let` for the "bail on nil, otherwise bind the value" pattern:

```praia
func printName(name) {
    ensure let unwrapped = name else {
        print("you need to provide a name")
        return
    }
    print(unwrapped)   // `unwrapped` is in scope here
}

printName("Ada")   // Ada
printName(nil)     // you need to provide a name
```

The `else` block runs *only* when the right-hand expression evaluates to `nil`. Any other value — including falsy ones like `false`, `0`, or `""` — binds to the name and the surrounding scope continues:

```praia
ensure let v = false else { return "skipped" }
// v is false here; the else did not run.
```

This is the key difference from the conditional form `ensure (cond) else`, which fires on any falsy value. Use the binding form when you mean "is the optional present?", and the conditional form when you mean "is this truthy?".

The same parse-time check applies: the `else` block must terminate.

### When to reach for `if` instead

`ensure` is exclusively for early-exit guards. If your check is "log a warning and keep going with a default," reach for plain `if`:

```praia
let content = readFile("config.json")
if (!content) {
    print("config missing, using defaults")
    content = "{}"
}
// continues with content set either way
```

Writing this as `ensure (content) else { content = "{}" }` is a parse error — the else block doesn't terminate.

## assert

`assert(cond, msg?)` is a production assertion. It throws a `RuntimeError` when `cond` is falsy. The optional `msg` is appended to the default text:

```praia
assert(user.age >= 0)                           // throws "assertion failed"
assert(input != nil, "input is required")       // throws "assertion failed: input is required"
assert(arr.len() > 0, {code: "EMPTY"})          // message can be any value (toString-coerced)
```

Praia's `assert` is **always on** -- there is no compile-time strip flag (Rust's `assert!`, not `debug_assert!`). Use it for invariants whose violation should never reach production. Truthiness rules apply: only `nil` and `false` trigger the throw; `0`, `""`, and `[]` are truthy and pass cleanly.

`assert` is for **errors that should crash**. For unit-test assertions that count pass/fail without throwing, use the testing grain's `expect` / `expectEqual` / `expectThrows` / `expectContains` family.

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
