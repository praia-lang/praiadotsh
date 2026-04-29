---
title: Math & Random
sidebar:
  order: 1
---

## Math

The `math` namespace provides mathematical constants and functions.

### Constants

| Name | Value |
|------|-------|
| `math.PI` | 3.14159265358979 |
| `math.E` | 2.71828182845905 |
| `math.INF` | Infinity |

### Functions

| Function | Description |
|----------|-------------|
| `math.sqrt(x)` | Square root |
| `math.pow(x, y)` | x raised to power y |
| `math.abs(x)` | Absolute value |
| `math.floor(x)` | Round down |
| `math.ceil(x)` | Round up |
| `math.round(x)` | Round to nearest |
| `math.trunc(x)` | Truncate to integer (toward zero) |
| `math.idiv(a, b)` | Integer division (truncated toward zero) |
| `math.min(a, b)` | Minimum |
| `math.max(a, b)` | Maximum |
| `math.clamp(x, lo, hi)` | Clamp x between lo and hi |
| `math.approx(a, b, epsilon?)` | Approximate equality (default epsilon: 1e-9) |
| `math.sin(x)`, `cos`, `tan` | Trigonometry (radians) |
| `math.asin(x)`, `acos`, `atan` | Inverse trig |
| `math.atan2(y, x)` | Two-argument arctangent |
| `math.log(x)` | Natural log |
| `math.log2(x)`, `log10(x)` | Base-2 and base-10 log |
| `math.exp(x)` | e^x |
| `math.isNan(x)` | `true` if x is NaN |
| `math.isInf(x)` | `true` if x is ±Infinity |

### Examples

```praia
print(math.sqrt(144))              // 12
print(math.pow(2, 10))             // 1024
print(math.sin(math.PI / 2))       // 1
print(math.clamp(150, 0, 100))     // 100
```

## Random

The `random` namespace provides random number generation using a Mersenne Twister engine.

| Function | Description |
|----------|-------------|
| `random.int(min, max)` | Random integer between min and max (inclusive) |
| `random.float()` | Random float between 0.0 and 1.0 |
| `random.choice(arr)` | Random element from an array |
| `random.shuffle(arr)` | Shuffle an array in place |
| `random.seed(n)` | Set the seed for reproducible results |

### Examples

```praia
print(random.int(1, 100))          // e.g. 42
print(random.float())              // e.g. 0.7312
print(random.choice(["a", "b"]))   // "a" or "b"

let deck = [1, 2, 3, 4, 5]
random.shuffle(deck)
print(deck)

// Reproducible
random.seed(42)
print(random.int(0, 100))          // always 51
```
