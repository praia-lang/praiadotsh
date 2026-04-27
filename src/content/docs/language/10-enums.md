---
title: Enums
sidebar:
  order: 10
---

Enums create named constants with auto-incrementing integer values.

```praia
enum Color { Red, Green, Blue }
print(Color.Red)      // 0
print(Color.Green)    // 1
print(Color.Blue)     // 2
```

## Custom values

```praia
enum Status { Active = 1, Inactive = 0, Pending = 2 }

if (status == Status.Active) {
    print("active")
}
```

## Auto-increment

Auto-increment continues from the last assigned value:

```praia
enum Level { Low = 10, Medium, High }
print(Level.Medium)   // 11
print(Level.High)     // 12
```

## Enums are maps

Enums are implemented as maps, so you can pass them around, iterate their keys, and use them anywhere a map is expected.
