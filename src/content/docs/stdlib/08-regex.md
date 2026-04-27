---
title: Regex
sidebar:
  order: 8
---

Regular expressions are available as string methods. When built with RE2 (the default), regex operations are guaranteed O(n) with no risk of catastrophic backtracking. Without RE2, Praia falls back to `std::regex`.

## String regex methods

| Method | Description |
|--------|-------------|
| `.test(pattern)` | Returns `true` if the pattern matches anywhere |
| `.match(pattern)` | First match map (`{match, groups, index}`) or `nil` |
| `.matchAll(pattern)` | Array of all match maps |
| `.replacePattern(pattern, replacement)` | Replace all matches (supports `$1`, `$2` back-references) |

### test

```praia
"hello123".test("[0-9]+")       // true
"hello".test("[0-9]+")          // false
```

### match

```praia
let m = "age: 25".match("(\\w+): (\\d+)")
print(m.match)      // age: 25
print(m.groups)     // ["age", "25"]
print(m.index)      // 0

"hello".match("\\d+")   // nil
```

### matchAll

```praia
let nums = "abc123def456".matchAll("\\d+")
for (m in nums) {
    print(m.match, "at", m.index)
}
// 123 at 3
// 456 at 9
```

### replacePattern

```praia
"hello   world".replacePattern("\\s+", " ")
// "hello world"

"John Smith".replacePattern("(\\w+) (\\w+)", "$2, $1")
// "Smith, John"
```

Use `.replace()` for literal string replacement, `.replacePattern()` for regex.

### Error handling

Invalid regex patterns throw a catchable error:

```praia
try {
    "test".test("[invalid")
} catch (err) {
    print(err)      // Invalid regex: ...
}
```

## re grain (advanced regex)

The `re` grain provides named capture groups, regex split, and escape.

```praia
use "re"
```

| Function | Description |
|----------|-------------|
| `re.test(str, pattern)` | Returns `true` if pattern matches |
| `re.find(str, pattern)` | First match with `groups`, `named`, `index` (or `nil`) |
| `re.findAll(str, pattern)` | Array of all matches with `named` maps |
| `re.replace(str, pattern, repl)` | Replace all matches |
| `re.split(str, pattern)` | Split string by regex pattern |
| `re.escape(str)` | Escape special regex characters |

### Named groups

Use `(?<name>...)` syntax:

```praia
let m = re.find("2026-04-22", "(?<year>\\d{4})-(?<month>\\d{2})-(?<day>\\d{2})")
print(m.named.year)    // "2026"
print(m.named.month)   // "04"
print(m.named.day)     // "22"
```

### split

```praia
re.split("one,,two,,,three", ",+")       // ["one", "two", "three"]
re.split("hello world  foo", "\\s+")     // ["hello", "world", "foo"]
```

### escape

```praia
let literal = re.escape("file (1).txt")
re.test("file (1).txt", literal)          // true
```

## Practical examples

```praia
// Email validation
let email = "ada@example.com"
if (email.test("^[\\w.+-]+@[\\w-]+\\.[\\w.]+$")) {
    print("valid email")
}

// Extract all words
let words = "Hello, World! 123".matchAll("[a-zA-Z]+")
for (w in words) { print(w.match) }

// Clean up whitespace
let clean = "  too   many   spaces  ".strip().replacePattern("\\s+", " ")
print(clean)    // "too many spaces"
```
