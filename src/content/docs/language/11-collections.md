---
title: Collections
sidebar:
  order: 11
---

## Arrays

Arrays are ordered, mixed-type collections with reference semantics.

```praia
let nums = [1, 2, 3]
let mixed = [1, "two", true, nil]
let empty = []
```

### Index access

```praia
let arr = [10, 20, 30]
print(arr[0])       // 10
print(arr[-1])      // 30 (negative = from end)

arr[1] = 99
print(arr)          // [10, 99, 30]
```

### Nested arrays

```praia
let matrix = [[1, 2], [3, 4]]
print(matrix[1][0]) // 3
```

### Reference semantics

```praia
let a = [1, 2, 3]
let b = a           // b points to the same array
b.push(4)
print(a)            // [1, 2, 3, 4]
```

### Array methods

| Method | Description |
|--------|-------------|
| `.push(value)` | Append an element |
| `.pop()` | Remove and return the last element |
| `.contains(value)` | Check if value is in the array |
| `.join(separator)` | Join elements into a string |
| `.reverse()` | Reverse the array in place |
| `.shift()` | Remove and return the first element |
| `.unshift(val)` | Add element to the beginning |
| `.slice(start, end?)` | Extract subarray (negative indices supported) |
| `.indexOf(val)` | Find index of element (-1 if not found) |
| `.find(fn)` | First element where fn returns truthy (nil if not found) |

```praia
let arr = [1, 2, 3]
arr.push(4)                     // [1, 2, 3, 4]
arr.pop()                       // returns 4
arr.contains(2)                 // true
["a", "b", "c"].join(", ")     // "a, b, c"
arr.reverse()                   // [3, 2, 1]
```

### Functional operations

These global functions work well with the [pipe operator](/language/04-operators/#pipe-operator):

| Function | Description |
|----------|-------------|
| `filter(arr, fn)` | Keep elements where fn returns truthy |
| `map(arr, fn)` | Transform each element |
| `flatMap(arr, fn)` | Map then flatten — array results are spread into output |
| `reduce(arr, fn, initial?)` | Fold to single value. fn receives `(acc, elem)` |
| `each(arr, fn)` | Call fn on each element, returns the array |
| `sort(arr, comparator?)` | Sorted copy. Optional: `lam{ a, b in a.age - b.age }` |
| `any(arr, fn)` | `true` if any element matches |
| `all(arr, fn)` | `true` if all elements match |
| `unique(arr)` | Remove duplicates, preserving order |
| `zip(a, b)` | Pair elements: `[[a0, b0], [a1, b1], ...]` |
| `enumerate(arr)` | Index-value pairs: `[[0, elem], ...]` |
| `groupBy(arr, fn)` | Group by key function → map of arrays |

```praia
let nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

nums |> filter(lam{ n in n % 2 == 0 }) |> print
// [2, 4, 6, 8, 10]

nums |> reduce(lam{ acc, n in acc + n }, 0) |> print
// 55

[{name: "Alice", dept: "eng"}, {name: "Bob", dept: "sales"}]
    |> groupBy(lam{ p in p.dept })
// {eng: [...], sales: [...]}
```

## Maps

Maps hold key-value pairs. Keys can be any hashable value: strings, integers, floats, booleans, or nil.

```praia
let person = {name: "Ada", age: 36}
let config = {"api-key": "abc123"}
let empty = {}
```

### Computed keys

Use `[expr]` for computed or non-string keys:

```praia
let m = {[42]: "answer", [true]: "yes", name: "Ada"}
print(m[42])       // answer
print(m[true])     // yes
print(m.name)      // Ada
```

Identifier keys like `name:` are sugar for the string key `"name":`.

### Access and assignment

```praia
// Dot notation (string keys only)
print(person.name)          // Ada
person.email = "ada@ex.com"

// Bracket notation (any key type)
print(person["name"])       // Ada
person["city"] = "London"
person[1] = "one"           // integer key
```

Arrays, maps, instances, and functions cannot be used as keys (not hashable).

### Reference semantics

Maps, like arrays, use reference semantics:

```praia
let a = {x: 1}
let b = a
b.y = 2
print(a)            // {x: 1, y: 2}
```

### Map methods

| Method | Description |
|--------|-------------|
| `.has(key)` | Returns `true` if the key exists |
| `.get(key, default?)` | Returns value or default (nil if omitted) |
| `.delete(key)` | Removes key, returns `true` if it existed |
| `.merge(other)` | Returns new map with other's values taking priority |

```praia
let m = {a: 1, b: 2}
m.has("a")           // true
m.get("z", 0)        // 0
m.delete("b")        // true
{a: 1}.merge({b: 2}) // {a: 1, b: 2}
```

### Map utilities

| Function | Description |
|----------|-------------|
| `keys(map)` | Return array of map keys |
| `values(map)` | Return array of map values |
| `len(map)` | Number of entries |

```praia
let config = {host: "localhost", port: 8080}
config |> keys |> print          // ["host", "port"]
config |> values |> print        // ["localhost", 8080]
```

## Built-in functions

| Function | Description |
|----------|-------------|
| `print(args...)` | Print values separated by spaces, with newline |
| `len(value)` | Length of an array, string, or map |
| `push(array, value)` | Append a value to an array |
| `pop(array)` | Remove and return the last element |
| `type(value)` | Return the type as a string |
| `str(value)` | Convert any value to a string |
| `num(value)` | Convert a string or number to a number |

```praia
print(len([1, 2, 3]))      // 3
print(len("hello"))         // 5
print(len({a: 1, b: 2}))   // 2

print(type(42))             // int
print(str(42) + "!")        // 42!
print(num("3.14") * 2)     // 6.28
```
