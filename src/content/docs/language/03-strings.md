---
title: Strings
sidebar:
  order: 3
---

Strings are enclosed in double quotes and are UTF-8 encoded.

## Escape sequences

| Escape | Meaning |
|--------|---------|
| `\n` | Newline |
| `\t` | Tab |
| `\r` | Carriage return |
| `\0` | Null byte |
| `\\` | Backslash |
| `\"` | Double quote |
| `\'` | Single quote |
| `\%` | Literal `%` (prevents interpolation) |
| `\xHH` | Byte from 2-digit hex value |
| `\u{HHHH}` | Unicode codepoint (1-6 hex digits) |

### Unicode escapes

`\u{...}` inserts any Unicode codepoint by its hex value:

```praia
"\u{E9}"        // "e" (e-acute)
"\u{1F600}"     // "emoji"
"\u{1F1F5}\u{1F1F9}"  // "flag"
```

## String interpolation

Use `%{expression}` inside strings:

```praia
let name = "Ada"
let age = 36
print("%{name} is %{age} years old")
// Ada is 36 years old

print("2 + 2 = %{2 + 2}")
// 2 + 2 = 4
```

## Multiline strings

Triple-quoted strings (`"""`) span multiple lines. The first newline after the opening quotes is stripped.

```praia
let html = """
<html>
  <body>
    <h1>%{title}</h1>
  </body>
</html>
"""
```

Interpolation and escape sequences work inside triple-quoted strings.

## String indexing

Strings are indexed by grapheme cluster (visible character), not by byte:

```praia
let s = "hello"
print(s[0])         // h
print(s[-1])        // o (negative = from end)

let emoji = "Hi!!"
print(len(emoji))   // 3 (grapheme clusters)
```

## String methods

| Method | Description |
|--------|-------------|
| `.upper()` | Uppercase copy |
| `.lower()` | Lowercase copy |
| `.strip()` | Remove leading/trailing whitespace |
| `.split(sep)` | Split into array by separator |
| `.contains(sub)` | Check if substring exists |
| `.replace(old, new)` | Replace all occurrences |
| `.startsWith(prefix)` | Check prefix |
| `.endsWith(suffix)` | Check suffix |
| `.title()` | Capitalize first letter of each word |
| `.capitalize()` | Capitalize first letter, lowercase the rest |
| `.capitalizeFirst()` | Capitalize first letter, leave the rest |
| `.slice(start, end?)` | Extract substring (negative indices supported) |
| `.indexOf(substr, start?)` | Find first position (-1 if not found) |
| `.lastIndexOf(substr)` | Find last position (-1 if not found) |
| `.repeat(count)` | Repeat string N times |
| `.padStart(len, char?)` | Left-pad to width (default: space) |
| `.padEnd(len, char?)` | Right-pad to width (default: space) |
| `.trimStart()` | Remove leading whitespace |
| `.trimEnd()` | Remove trailing whitespace |
| `.graphemes()` | Split into array of grapheme clusters |
| `.codepoints()` | Array of Unicode codepoint values (integers) |
| `.bytes()` | Array of raw byte values (integers) |
| `.charCode(index?)` | Unicode codepoint of grapheme at index (default: 0) |

### Examples

```praia
"hello".upper()                  // "HELLO"
"  hello  ".strip()              // "hello"
"a,b,c".split(",")              // ["a", "b", "c"]
"hello world".contains("world") // true
"hello".replace("l", "r")       // "herro"

// Casing variants
"how old is Ada?".title()           // "How Old Is Ada?"
"how old is Ada?".capitalize()      // "How old is ada?"
"how old is Ada?".capitalizeFirst() // "How old is Ada?"

// Chaining
"  Hello World  ".strip().lower()   // "hello world"
```

## Universal methods

These work on any value type:

| Method | Description |
|--------|-------------|
| `.toString()` | Convert any value to its string representation |
| `.toNum()` | Convert to number (works on numbers, bools, and numeric strings) |

```praia
42.toString()           // "42"
true.toString()         // "true"
[1, 2].toString()       // "[1, 2]"

true.toNum()            // 1
false.toNum()           // 0
"3.14".toNum()          // 3.14
```

## String concatenation

`+` concatenates when either side is a string:

```praia
"hello " + "world"  // "hello world"
"count: " + 42      // "count: 42"
```

See also: [Regex](/stdlib/08-regex/) for pattern matching on strings.
