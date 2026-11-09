---
title: Collections
sidebar:
  order: 11
---

## Mutation convention

Collection methods follow a uniform rule across arrays, maps, and sets:

- **Past-tense / noun-like names** (`sorted`, `reversed`, `union`, `intersection`, `difference`, `merge`) return a **new** collection; the receiver is untouched.
- **Methods ending in `InPlace`** (`sortInPlace`, `reverseInPlace`, `unionInPlace`, `intersectionInPlace`, `differenceInPlace`, `mergeInPlace`) **mutate the receiver** and return nil.
- **Imperative one-word verbs** (`push`, `pop`, `shift`, `unshift`, `add`, `remove`, `delete`, `clear`) are mutating by long-standing convention.
- **Strings are immutable** — every string method is pure.

The legacy names `.sort()` and `.reverse()` (when called on arrays) still work but emit a one-line stderr deprecation warning the first time they're hit; run with `--strict-deprecations` to promote the warning to a hard error in CI.

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
| `.reversed()` | Return a reversed copy (receiver unchanged) |
| `.reverseInPlace()` | Reverse the array in place; returns nil |
| `.shift()` | Remove and return the first element |
| `.unshift(val)` | Add element to the beginning |
| `.slice(start, end?)` | Extract subarray (negative indices supported) |
| `.indexOf(val)` | Find index of element (-1 if not found) |
| `.find(fn)` | First element where fn returns truthy (nil if not found) |
| `.lastIndexOf(val)` | Find last index (-1 if not found) |
| `.sorted(comparator?)` | Return sorted copy |
| `.sortInPlace(comparator?)` | Sort the array in place; returns nil |
| `.sort(...)`, `.reverse()` | **Deprecated** aliases — use the explicit forms above |

```praia
let arr = [1, 2, 3]
arr.push(4)                       // [1, 2, 3, 4]
arr.pop()                         // returns 4
arr.contains(2)                   // true
["a", "b", "c"].join(", ")        // "a, b, c"
let r = [1, 2, 3].reversed()      // [3, 2, 1], original unchanged
let s = [3, 1, 2].sorted()        // [1, 2, 3]
[3, 1, 2].sortInPlace()           // mutates receiver
```

Sorting is stable: elements the comparator treats as equal keep their order. `sort()`, `.sorted()` and `.sortInPlace()` all work this way. A comparator that isn't a consistent order (one that always returns `true`, say) gives some order of the same elements rather than an error. If a comparator throws, `.sortInPlace()` leaves the array as it was.

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
| `findIndex(arr, fn)` | Index of first match, or -1 |
| `flatten(arr)` | Flatten one level of nesting |

```praia
let nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

nums |> filter(lam{ it % 2 == 0 }) |> print
// [2, 4, 6, 8, 10]

nums |> reduce(lam{ acc, n in acc + n }, 0) |> print
// 55

[{name: "Alice", dept: "eng"}, {name: "Bob", dept: "sales"}]
    |> groupBy(lam{ it.dept })
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
| `.mergeInPlace(other)` | Merge other's entries into receiver in place; returns nil |
| `.entries()` | Returns `[[key, value], ...]` array |
| `.clear()` | Remove all entries |

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

## Sets

Sets hold an unordered collection of unique values. Elements must be hashable: `nil`, bool, int, float, string, or tagged values — the same rules as map keys. Arrays, maps, instances, and other sets aren't hashable and can't be elements.

> Looking for `collections.Set`? It still exists as a deprecated wrapper around native sets — see the [collections grain notes](/grains/standard/). Prefer the `#{}` literal and the methods documented below for new code.

```praia
let primes = #{2, 3, 5, 7, 11}
let mixed  = #{1, "two", true, nil, 3.14}
let empty  = #{}
```

Literal syntax: `#{...}`. The `#` distinguishes a set from a map literal — `{}` is an empty map, `#{}` is an empty set. Set literals dedup on construction: `#{1, 1, 2}` has size 2.

### Equality

Two sets are equal when they contain the same elements regardless of order:

```praia
#{1, 2, 3} == #{3, 2, 1}     // true
#{1, 2} == #{1, 2, 3}        // false
```

### Iteration

`for-in` over a set visits each element exactly once. Order is unspecified.

```praia
for (x in #{10, 20, 30}) {
    print(x)
}
```

### Spread

Spread accepts a set or an array — elements go into the resulting set with dedup-on-insert.

```praia
let a = #{1, 2, 3}
#{0, ...a, 4}        // #{0, 1, 2, 3, 4}
#{0, ...[1, 2, 3]}   // #{0, 1, 2, 3}
#{1, ...#{1, 2}}     // #{1, 2}
```

### Set methods

| Method | Description |
|--------|-------------|
| `.add(x)` | Insert `x`. Returns `true` if newly added, `false` if already present. |
| `.remove(x)` | Remove `x`. Returns `true` if it was present, `false` otherwise. |
| `.has(x)` | `true` if `x` is in the set. |
| `.size()` | Number of elements (same as `len(s)`). |
| `.clear()` | Remove every element. |
| `.toArray()` | Return a new array of the elements (order unspecified). |
| `.clone()` | Return an independent copy. |
| `.union(other)` | New set with every element of `self` or `other`. |
| `.intersection(other)` | New set with elements in both. |
| `.difference(other)` | New set with elements in `self` but not in `other`. |
| `.unionInPlace(other)` | Add every element of `other` to the receiver in place; returns nil. |
| `.intersectionInPlace(other)` | Drop elements of the receiver not present in `other` in place; returns nil. |
| `.differenceInPlace(other)` | Drop elements of the receiver also in `other` in place; returns nil. |
| `.isSubset(other)` | `true` if every element of `self` is in `other` (empty set is a subset of everything). |

```praia
let a = #{1, 2, 3}
let b = #{2, 3, 4}

a.union(b)            // #{1, 2, 3, 4}
a.intersection(b)     // #{2, 3}
a.difference(b)       // #{1}
a.isSubset(#{1, 2, 3, 4})  // true

a.add(99)             // true → a is now #{1, 2, 3, 99}
a.has(2)              // true
a.size()              // 4
```

### Union via `+`

For parity with arrays (`+` concatenates) and maps (`+` merges), the `+` operator on two sets returns their union — same as `.union()`:

```praia
#{1, 2} + #{3, 4}    // #{1, 2, 3, 4}
#{1, 2} + #{2, 3}    // #{1, 2, 3}  — dedup
```

### Set ↔ array

Use `.toArray()` to convert a set to an array. To go the other way, spread an array into a set literal:

```praia
let arr = [1, 2, 2, 3]
let s = #{...arr}     // #{1, 2, 3}
let back = s.toArray()  // [1, 2, 3] — order unspecified
```

### Reference semantics

Sets, like arrays and maps, are references:

```praia
let a = #{1, 2}
let b = a
b.add(3)
print(a)              // #{1, 2, 3}
```

## Built-in functions

| Function | Description |
|----------|-------------|
| `print(args...)` | Print values separated by spaces, with newline |
| `len(value)` | Length of an array, string, map, or set |
| `push(array, value)` | Append a value to an array |
| `pop(array)` | Remove and return the last element |
| `type(value)` | Return the type as a string |
| `str(value)` | Convert any value to a string |
| `num(value)` | Convert a string or number to a number |

```praia
print(len([1, 2, 3]))      // 3
print(len("hello"))         // 5
print(len({a: 1, b: 2}))   // 2
print(len(#{1, 2, 3}))     // 3

print(type(42))             // int
print(type(#{1}))           // set
print(str(42) + "!")        // 42!
print(num("3.14") * 2)     // 6.28
```
