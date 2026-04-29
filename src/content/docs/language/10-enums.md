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

## Tagged values

Tagged values are data-carrying variants — like Rust enums with data. Any capitalized call to an undefined name creates a tagged value:

```praia
let result = Ok(42)
let error = Err("not found")
let point = Point(1, 2)

print(result)       // Ok(42)
print(type(result)) // "tagged"
print(result.tag)   // "Ok"
print(result.values) // [42]
```

### Pattern matching

Destructure tagged values in `match`:

```praia
match (result) {
    Ok(val) { print("success: " + str(val)) }
    Err(msg) { print("error: " + msg) }
}

match (Point(3, 4)) {
    Point(x, y) { print(x + y) }   // 7
}
```

### Equality

```praia
Ok(1) == Ok(1)     // true
Ok(1) == Err(1)    // false
```

Class constructors take priority — tagged values only apply when the name isn't defined as a class or function.
