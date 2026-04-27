---
title: Generators
sidebar:
  order: 8
---

A generator is a function whose body contains `yield`. Calling it returns a **generator object** instead of executing the body. The body runs lazily, pausing at each `yield` and resuming on the next `.next()` call.

No special keyword is needed -- any function or lambda that uses `yield` becomes a generator automatically.

## Basic usage

```praia
func countdown(n) {
    while (n > 0) { yield n; n = n - 1 }
}

let g = countdown(3)
print(g.next())   // {value: 3, done: false}
print(g.next())   // {value: 2, done: false}
print(g.next())   // {value: 1, done: false}
print(g.next())   // {value: nil, done: true}
```

`.next()` returns a map with `value` (the yielded value) and `done` (whether the generator is exhausted).

## for-in integration

Generators work directly with `for-in` loops. Iteration is lazy -- values are produced one at a time.

```praia
func range(n) {
    for (i in 0..n) { yield i }
}

for (x in range(5)) { print(x) }   // 0 1 2 3 4
```

## Infinite generators

Since generators are lazy, they can produce infinite sequences. Use `break` to stop.

```praia
func naturals() {
    let n = 0
    while (true) { yield n; n = n + 1 }
}

for (x in naturals()) {
    if (x >= 5) { break }
    print(x)    // 0 1 2 3 4
}
```

## Sending values

`yield` is an expression that returns the value passed to `.next(arg)`. The first `.next()` primes the generator; subsequent calls resume with the sent value.

```praia
func accumulator() {
    let total = 0
    while (true) {
        let val = yield total
        total = total + val
    }
}

let acc = accumulator()
acc.next()              // prime -- {value: 0, done: false}
acc.next(10)            // {value: 10, done: false}
acc.next(5)             // {value: 15, done: false}
acc.next(25)            // {value: 40, done: false}
```

## Generator lambdas

Lambdas can be generators too:

```praia
let squares = lam{ n in for (i in 0..n) { yield i * i } }

for (x in squares(5)) { print(x) }   // 0 1 4 9 16
```

## Return value

A `return` inside a generator sets `done: true` and the return value as the final `value`.

```praia
func gen() {
    yield 1
    return 99
}

let g = gen()
print(g.next())   // {value: 1, done: false}
print(g.next())   // {value: 99, done: true}
```

## Generator properties

| Property/Method | Description |
|---|---|
| `.next()` | Resume, return `{value, done}` |
| `.next(val)` | Resume with sent value |
| `.done` | `true` if generator is exhausted |
