---
title: Data Types
sidebar:
  order: 2
---

Praia has 7 types:

| Type | Examples | Notes |
|------|---------|-------|
| `nil` | `nil` | The absence of a value |
| `bool` | `true`, `false` | |
| `int` | `42`, `0xFF`, `0b1010`, `0o17` | 64-bit integer (exact up to 2^63). Supports hex, binary, octal. |
| `float` | `3.14`, `1e3`, `2.5e-4` | Double-precision float. Supports scientific notation. |
| `string` | `"hello"` | UTF-8, supports interpolation, escape sequences, and Unicode (`\u{...}`) |
| `array` | `[1, 2, 3]` | Ordered, mixed-type, reference semantics |
| `map` | `{name: "Ada"}` | Key-value pairs, reference semantics |
| `function` | `func add(a, b) { ... }` | First-class, supports closures |

Use `type()` to check a value's type at runtime:

```praia
print(type(42))         // int
print(type(3.14))       // float
print(type("hi"))       // string
print(type([1, 2]))     // array
print(type({a: 1}))     // map
```

## Number literals

### Integers

Integers support multiple bases and underscores as visual separators:

```praia
42                // decimal
0xFF              // hex
0b1010            // binary
0o755             // octal
1_000_000         // underscores ignored (readability)
0xFF_FF           // works in any base
```

### Floats

Floats support decimal points and scientific notation:

```praia
3.14              // decimal float
1e3               // 1000.0 (scientific notation)
2.5e-4            // 0.00025
1_000.5           // separators in floats too
```

Integer overflow automatically promotes to float rather than wrapping.

### Arithmetic rules

- `int + int`, `int - int`, `int * int`, `int % int` produce `int`
- Anything involving a float produces `float`
- `/` always returns `float`: `7 / 2` gives `3.5`

```praia
42 + 8          // 50 (int)
42 + 0.5        // 42.5 (float)
7 / 2           // 3.5 (always float)
7 % 2           // 1 (int)
```

Integers are 64-bit, so they are exact up to 2^63:

```praia
let big = 9007199254740993
print(big + 1)     // 9007199254740994 (exact)
```

Ints and floats compare by value: `42 == 42.0` is `true`.

## Truthiness

Only `nil` and `false` are falsy. Everything else -- including `0`, `""` (empty string), and `[]` (empty array) -- is truthy.

```praia
if (0)       { print("truthy") }   // prints (0 is truthy)
if ("")      { print("truthy") }   // prints (empty string is truthy)
if ([])      { print("truthy") }   // prints (empty array is truthy)
if (nil)     { print("truthy") }   // does not print
if (false)   { print("truthy") }   // does not print
```

To check for empty strings or arrays, use `len()`:

```praia
if (len(name) > 0) { print("has name") }
if (len(items) > 0) { print("has items") }
```

## Type checking with `is`

The `is` operator checks types and class hierarchy:

```praia
42 is "int"             // true
"hello" is "string"     // true
[1, 2] is "array"       // true

class Animal {}
class Dog extends Animal {}
let d = Dog()
d is Dog                // true
d is Animal             // true (walks inheritance chain)
```

Supported type strings: `"nil"`, `"bool"`, `"int"`, `"float"`, `"string"`, `"array"`, `"map"`, `"function"`, `"instance"`.
