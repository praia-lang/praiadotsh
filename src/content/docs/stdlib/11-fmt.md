---
title: Formatting (fmt)
sidebar:
  order: 11
---

`fmt` is a Go-style formatter for building strings with width, precision, sign control, and typed verbs. Reach for it when string interpolation gets too noisy (`"%-10s | %6.2f"` is clearer than concatenating padded substrings) or when you need precise control over numeric output.

## API

| Function | Description |
|----------|-------------|
| `fmt.sprintf(format, args...)` | Format and return the resulting string |
| `fmt.printf(format, args...)` | Format and write to stdout (no trailing newline) |
| `fmt.println(args...)` | Print args separated by spaces, with a trailing newline (no format string) |
| `fmt.errorf(format, args...)` | Same body as `sprintf`. Named so `throw fmt.errorf(...)` reads naturally |

## Verbs

| Verb | Argument | Output |
|------|----------|--------|
| `%d` | integer (or integer-valued float) | base 10 |
| `%b` `%o` `%x` `%X` | integer | binary / octal / lower-hex / upper-hex |
| `%f` `%F` | number | fixed-point decimal (default 6 fractional digits) |
| `%e` `%E` | number | scientific (default 6 fractional digits) |
| `%g` `%G` | number | shortest of `%e`/`%f` |
| `%s` | any | `toString()` of the value |
| `%q` | any | Go-style quoted string (escapes `"`, `\`, control chars) |
| `%t` | bool | `"true"` / `"false"` |
| `%c` | integer codepoint | UTF-8 character |
| `%v` | any | default formatting (same as `%s`) |
| `%T` | any | type name (`"int"`, `"string"`, `"map"`, …) |
| `%%` | -- | literal `%` |

## Flags

| Flag | Effect |
|------|--------|
| `-` | left-align inside `width` |
| `+` | force sign on positives |
| ` ` (space) | leading space for positives (sign placeholder) |
| `0` | zero-pad numeric verbs (ignored with `-`) |
| `#` | alternate form: `0b` / `0o` / `0x` prefix for `%b`/`%o`/`%x` |

## Width and precision

The full spec is `%[flags][width][.precision]verb`. `width` is the minimum output size; `.precision` truncates strings or sets decimal digits for floats. Width is counted in grapheme clusters for non-numeric verbs, matching Praia's `len()`.

```praia
fmt.sprintf("%10s",   "hi")           // "        hi"
fmt.sprintf("%-10s",  "hi")           // "hi        "
fmt.sprintf("%05d",   42)             // "00042"
fmt.sprintf("%05d",  -42)             // "-0042"      // zero-pad AFTER the sign
fmt.sprintf("%.3f",   3.14159)        // "3.142"
fmt.sprintf("%010.2f", -3.5)          // "-000003.50"
fmt.sprintf("%.3s",   "hello world")  // "hel"
fmt.sprintf("%#x",    255)            // "0xff"
fmt.sprintf("%+d",    42)             // "+42"
fmt.sprintf("%c",     0x1F600)        // "\u{1F600}"
fmt.sprintf("%q",     "say \"hi\"")   // "\"say \\\"hi\\\"\""
fmt.sprintf("%T",     [1, 2])         // "array"
```

## Errors

Format/argument mismatches throw -- `fmt.sprintf` deliberately fails loudly rather than producing Go's `%!d(string=foo)` "fail-open" output. Throw cases:

- Wrong arg type for a verb (`"%d"` with a string, `"%t"` with a number).
- Too few or too many arguments for the format string.
- Unknown verb (`"%z"`).
- Incomplete spec (`"%5.2"` with no verb).
- Non-integer or out-of-range codepoint for `%c`.

## `throw fmt.errorf(...)` pattern

Praia throws strings; `errorf` makes formatted error messages a one-liner:

```praia
if (port < 0 || port > 65535) {
    throw fmt.errorf("port %d out of range (expected 0..65535)", port)
}
```
