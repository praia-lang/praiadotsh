---
title: Classes
sidebar:
  order: 7
---

## Defining a class

```praia
class Animal {
    func init(name, sound) {
        this.name = name
        this.sound = sound
    }

    func speak() {
        print("%{this.name} says %{this.sound}")
    }
}
```

- `class` defines a class
- `func init` is the constructor (called automatically)
- `this` refers to the current instance

## Creating instances

Call the class like a function -- no `new` keyword:

```praia
let cat = Animal("Whiskers", "meow")
cat.speak()         // Whiskers says meow
```

## Properties

Properties are set on `this` and accessed with dot notation:

```praia
print(cat.name)     // Whiskers
cat.name = "Luna"
cat.speak()         // Luna says meow
```

## Inheritance

Use `extends` for single inheritance:

```praia
class Dog extends Animal {
    func init(name) {
        super.init(name, "woof")
        this.tricks = []
    }

    func learn(trick) {
        this.tricks.push(trick)
    }
}

let buddy = Dog("Buddy")
buddy.speak()           // Buddy says woof (inherited)
buddy.learn("sit")
```

## super

Use `super.method()` to call the parent's version of a method:

```praia
class Cat extends Animal {
    func init(name) {
        super.init(name, "meow")
    }

    func describe() {
        return "%{this.name} the cat"
    }
}
```

`super` works correctly with multi-level inheritance.

## Method overriding

Child classes can override parent methods:

```praia
class Animal {
    func describe() { return "an animal" }
}

class Cat extends Animal {
    func describe() { return "a cat" }
}

let c = Cat()
print(c.describe())    // a cat
```

## Classes are values

Classes are first-class and can be stored in variables:

```praia
let MyClass = Animal
let a = MyClass("Rex", "woof")
a.speak()
```

## Instance equality

Instances use reference equality by default:

```praia
let a = Animal("Rex", "woof")
let b = a
print(a == b)       // true (same reference)

let c = Animal("Rex", "woof")
print(a == c)       // false (different instances)
```

Override with `__eq` for custom equality (see operator overloading below).

## Operator overloading

Define special "dunder" methods to customize operator behavior:

```praia
class Vec {
    func init(x, y) { this.x = x; this.y = y }
    func __add(other) { return Vec(this.x + other.x, this.y + other.y) }
    func __eq(other)  { return this.x == other.x && this.y == other.y }
    func __neg()      { return Vec(-this.x, -this.y) }
    func __str()      { return "(%{this.x}, %{this.y})" }
    func __len()      { return 2 }
    func __index(key) { if (key == 0) { return this.x } return this.y }
    func __indexSet(key, val) {
        if (key == 0) { this.x = val } else { this.y = val }
    }
}

let a = Vec(1, 2) + Vec(3, 4)   // Vec(4, 6)
print(-a)                        // (-4, -6)
print(a == Vec(4, 6))            // true
print(len(a))                    // 2
print(a[0])                      // 4
```

### Available dunder methods

| Method | Operators |
|--------|-----------|
| `__add(other)` | `+` |
| `__sub(other)` | `-` (binary) |
| `__mul(other)` | `*` |
| `__div(other)` | `/` |
| `__mod(other)` | `%` |
| `__eq(other)` | `==`, `!=` (negated) |
| `__lt(other)` | `<`, `>=` (negated) |
| `__gt(other)` | `>`, `<=` (negated) |
| `__neg()` | unary `-` |
| `__str()` | `str()`, string interpolation |
| `__len()` | `len()` |
| `__index(key)` | `obj[key]` |
| `__indexSet(key, val)` | `obj[key] = val` |

`str()` checks `__str` first, then falls back to `toString()` for backwards compatibility.

## Static methods

Define class-level methods with `static func`:

```praia
class Point {
    func init(x, y) { this.x = x; this.y = y }
    static func origin() { return Point(0, 0) }
    static func fromArray(arr) { return Point(arr[0], arr[1]) }
}

let p = Point.origin()
let q = Point.fromArray([3, 4])
```

Static methods are inherited by subclasses and can be overridden:

```praia
class Animal {
    static func type() { return "animal" }
}
class Dog extends Animal {
    static func type() { return "dog" }
}
print(Dog.type())    // "dog"
```
