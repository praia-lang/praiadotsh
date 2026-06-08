---
title: Functions
sidebar:
  order: 6
---

Functions are first-class values. Define them with `func`.

```praia
func add(a, b) {
    return a + b
}

print(add(2, 3))    // 5
```

## Default parameters

Parameters can have default values. Non-default parameters must come first.

```praia
func greet(name, greeting = "Hello") {
    print("%{greeting}, %{name}!")
}

greet("Ada")              // Hello, Ada!
greet("Ada", "Welcome")   // Welcome, Ada!
```

Defaults activate only when the caller **omits** the argument. Passing `nil` explicitly is preserved — it does NOT trigger the default. To convert nil to a fallback at the call site, use `??`:

```praia
greet("Ada", nil)              // "nil, Ada!" — explicit nil is kept
greet("Ada", maybeStr ?? "Hi") // explicit nil-handling at the call site
```

This applies to named arguments too: omitting a named param activates its default, but `name: nil` keeps nil.

## Rest parameters

Use `...name` as the last parameter to collect remaining arguments into an array:

```praia
func log(level, ...messages) {
    print("[" + level + "]", messages.join(" "))
}

log("INFO", "server", "started", "on", "8080")
// [INFO] server started on 8080
```

If no extra arguments are passed, the rest parameter is an empty array.

## Named arguments

Pass arguments by name using `name: value` syntax. Positional arguments must come first.

```praia
func createUser(name, age, role = "user") {
    return {name: name, age: age, role: role}
}

createUser("Ada", 36)                       // all positional
createUser("Ada", role: "admin", age: 36)   // mixed
createUser(name: "Ada", age: 36)            // all named
```

Named arguments work with lambdas, constructors, and the pipe operator:

```praia
func format(value, prefix = "", suffix = "") {
    return prefix + str(value) + suffix
}
42 |> format(suffix: "!")  // "42!"
```

Unknown or duplicate parameter names throw a runtime error.

Named arguments also work for stdlib natives whose positional slots are documented (most of `crypto`, `fs`, `time`, `random`, `json`, `bytes`, etc.):

```praia
let k = crypto.randomBytes(count: 32)
let iv = crypto.randomBytes(count: 16)
let ct = crypto.encrypt(plaintext: "hello", key: k, iv: iv)

fs.write(path: "/tmp/x.txt", data: "hi")
random.int(min: 1, max: 100)
json.stringify(value: data, indent: 2)
```

Nullary and trivially-unary natives (`len`, `str`, `num`, `type`, `print`, `keys`, `values`) stay positional-only — naming them adds noise. Calling those with names throws `Named arguments not supported for '<name>'`.

A handful of natives where `nil` is a meaningful value (notably `map.get(key, default?)`, since `nil` is a valid map key) also stay positional-only. The reason: native dispatch pads omitted positions with `nil` before the native body runs, so a hypothetical `m.get(default: 99)` would arrive as `[nil, 99]` and probe the map for a literal-nil key — silently wrong. Call these positionally: `m.get(key)` or `m.get(key, default)`.

Native param names are part of the API contract — once published, a rename is a breaking change.

## Implicit nil return

Functions without an explicit `return` return `nil`.

## Closures

Functions capture their enclosing scope:

```praia
func makeCounter() {
    let count = 0
    func increment() {
        count = count + 1
        return count
    }
    return increment
}

let counter = makeCounter()
print(counter())    // 1
print(counter())    // 2
print(counter())    // 3
```

## Recursion

```praia
func fib(n) {
    if (n <= 1) { return n }
    return fib(n - 1) + fib(n - 2)
}
print(fib(10))      // 55
```

## Functions as values

```praia
func apply(f, x) {
    return f(x)
}

func double(n) { return n * 2 }

print(apply(double, 21))   // 42
```

## Decorators

Decorators wrap a function using `@` syntax. `@dec func f(){}` desugars to `func f(){}; f = dec(f)`.

```praia
func log(fn) {
    return lam{ ...args in
        print("calling " + str(fn))
        return fn(...args)
    }
}

@log
func add(a, b) { return a + b }

add(2, 3)   // prints "calling <function add>", returns 5
```

Multiple decorators are applied bottom-up:

```praia
@auth
@log
func handler(req) { ... }
// equivalent to: handler = auth(log(handler))
```

Decorators can take arguments:

```praia
func role(required) {
    return lam{ fn in
        return lam{ ...args in
            print("checking role: " + required)
            return fn(...args)
        }
    }
}

@role("admin")
func deleteUser(id) { ... }
```

Decorators also work on class methods (both instance and static).

## Lambdas

Lambdas are anonymous functions defined inline with `lam{ params in body }`.

### Single expression (auto-returned)

```praia
let double = lam{ x in x * 2 }
let add = lam{ a, b in a + b }

print(double(5))        // 10
print(add(3, 4))        // 7
```

A single-expression lambda automatically returns its result.

### Multi-line (explicit return)

```praia
let process = lam{ x, y in
    let sum = x + y
    let product = x * y
    return {sum: sum, product: product}
}
```

### No parameters

```praia
let sayHi = lam{ in print("hello!") }
sayHi()
```

### Lambdas as callbacks

```praia
let nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let evens = filter(nums, lam{ it % 2 == 0 })
let squares = map(nums, lam{ it * it })

print(evens)            // [2, 4, 6, 8, 10]
print(squares)          // [1, 4, 9, 16, 25, 36, 49, 64, 81, 100]
```

### Closures

Lambdas capture their enclosing scope:

```praia
func makeMultiplier(factor) {
    return lam{ x in x * factor }
}

let triple = makeMultiplier(3)
print(triple(5))        // 15
```

### Lambdas in maps

```praia
let actions = {
    double: lam{ x in x * 2 },
    negate: lam{ x in -x }
}
print(actions.double(21))   // 42
```

## Pipe operator with functions

The pipe operator `|>` passes the left side as the first argument:

```praia
let result = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    |> filter(lam{ it % 2 == 0 })
    |> map(lam{ it * it })
    |> sort
print(result)   // [4, 16, 36, 64, 100]
```

Functions designed for pipe usage:

| Function | Description |
|----------|-------------|
| `filter(arr, predicate)` | Keep elements where predicate returns truthy |
| `map(arr, transform)` | Transform each element |
| `each(arr, fn)` | Call fn on each element (side effects), returns the array |
| `sort(arr)` | Return sorted copy |
| `keys(map)` | Return array of map keys |
| `values(map)` | Return array of map values |
