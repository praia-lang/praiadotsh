---
title: Operators
sidebar:
  order: 4
---

## Arithmetic

```praia
2 + 3       // 5
10 - 4      // 6
3 * 7       // 21
15 / 4      // 3.75
17 % 5      // 2
[1,2] + [3,4]  // [1, 2, 3, 4]  (array concat)
```

## Comparison

Works on numbers and strings (lexicographic ordering).

```praia
3 < 5               // true
"apple" < "banana"  // true
"abc" <= "abc"      // true
```

## Equality

Works on any types. Arrays and maps compare by value.

```praia
1 == 1              // true
"hi" == "hi"        // true
[1, 2] == [1, 2]    // true
nil == nil           // true
1 == "1"             // false
```

**Floating-point note:** `==` uses exact equality. Due to IEEE 754, `0.1 + 0.2 != 0.3`. Use `math.approx()` for approximate comparison:

```praia
0.1 + 0.2 == 0.3              // false
math.approx(0.1 + 0.2, 0.3)   // true
```

## Logical

`&&` and `||` short-circuit and return the deciding value, not just `true`/`false`.

```praia
true && "yes"       // "yes"
false && "yes"      // false
nil || "default"    // "default"
true || "other"     // true
!true               // false
!nil                // true
```

## Ternary

```praia
let label = x > 5 ? "big" : "small"
let grade = score >= 90 ? "A" : score >= 80 ? "B" : "C"
```

## Optional chaining

`?.` accesses a property only if the object is non-nil. Returns `nil` if the object is `nil` or the field does not exist.

```praia
let user = {address: {city: "Lisbon"}}
print(user?.address?.city)    // "Lisbon"
print(user?.phone?.number)    // nil (no error)

let x = nil
print(x?.name)                // nil
```

`?[` does the same for index access. It returns `nil` when the object is `nil`, the index is out of bounds, or the map key is missing. Type errors (e.g. indexing a number) still throw.

```praia
let arr = nil
print(arr?[0])                // nil (object is nil)

let nums = [10, 20]
print(nums?[5])               // nil (out of bounds)

let m = {a: 1}
print(m?["missing"])          // nil (no such key)
```

## Nil coalescing

`??` returns the left side if non-nil, otherwise evaluates the right side (short-circuit).

```praia
let name = nil ?? "anonymous"      // "anonymous"
let port = config?.port ?? 8080    // 8080 if port is nil
let x = 0 ?? 42                   // 0 (not nil, so left wins)
```

Chains naturally with `?.`:

```praia
let city = user?.address?.city ?? "unknown"
```

## Compound assignment

```praia
let x = 10
x += 5              // 15
x -= 3              // 12
x *= 2              // 24
x /= 4              // 6
x %= 4              // 2
```

## Increment / Decrement

```praia
let i = 0
i++                 // i is now 1
i--                 // i is now 0
```

## Pipe operator

The pipe operator `|>` passes the left side as the first argument to the right side:

```praia
// Without pipe
print(sort(filter(nums, lam{ it > 5 })))

// With pipe
nums
    |> filter(lam{ it > 5 })
    |> sort
    |> print
```

`a |> f` becomes `f(a)`. `a |> f(x)` becomes `f(a, x)`.

### Implicit `it`

Lambdas without `in` get an implicit `it` parameter:

```praia
[1, 2, 3] |> filter(lam{ it > 1 }) |> map(lam{ it * 2 })
```

### Error pipeline (`|?>`)

`|?>` catches errors — if the left side throws, the error is passed to the handler:

```praia
let data = input |> json.parse |?> lam{ nil }  // nil on parse error
```

## Bitwise operators

| Operator | Description |
|----------|-------------|
| `&` | Bitwise AND |
| `\|` | Bitwise OR |
| `^` | Bitwise XOR |
| `~` | Bitwise NOT (unary) |
| `<<` | Left shift |
| `>>` | Right shift |

```praia
255 & 15        // 15
240 | 15        // 255
255 ^ 15        // 240
~0              // -1
1 << 8          // 256
256 >> 4        // 16
```

All values are converted to 64-bit integers for bitwise operations. Note: `|` is bitwise OR, `|>` is the pipe operator, `||` is logical OR.

## Type checking (`is`)

```praia
42 is "int"             // true
"hello" is "string"     // true

class Dog extends Animal {}
let d = Dog()
d is Dog                // true
d is Animal             // true
```

See [Data Types](/language/02-types/) for supported type names.

## Operator precedence

From highest to lowest:

| Precedence | Operators | Description |
|-----------|-----------|-------------|
| 1 | `()` `[]` `.` | Call, index, field access |
| 2 | `++` `--` | Postfix increment/decrement |
| 3 | `-` `!` `~` | Unary negation, logical NOT, bitwise NOT |
| 4 | `*` `/` `%` | Multiplication, division, modulo |
| 5 | `+` `-` | Addition, subtraction |
| 6 | `<<` `>>` | Bitwise shift |
| 7 | `&` | Bitwise AND |
| 8 | `^` | Bitwise XOR |
| 9 | `\|` | Bitwise OR |
| 10 | `<` `>` `<=` `>=` | Comparison |
| 11 | `==` `!=` | Equality |
| 12 | `&&` | Logical AND |
| 13 | `\|\|` | Logical OR |
| 14 | `=` | Assignment (right-associative) |

Parentheses can override precedence:

```praia
print(2 + 3 * 4)       // 14
print((2 + 3) * 4)     // 20
```
