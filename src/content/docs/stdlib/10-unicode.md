---
title: Unicode
sidebar:
  order: 10
---

The `unicode` namespace covers operations that need to look at the codepoint stream as a whole rather than just walking it: canonical normalization, monospace display width, and sortable keys for case-insensitive and accent-tolerant comparison.

Per-grapheme operations like indexing, slicing, iteration, and `.reverse()` live on the [string methods](/language/03-strings/) themselves.

## Normalization

```praia
let cleaned = unicode.normalize(userInput, "NFC")
```

Praia strings are UTF-8 byte sequences; the same visible text can be encoded multiple ways (precomposed `é` vs `e` + combining acute). Normalize before storing or comparing so equality works regardless of how the input arrived.

| Form | Meaning | Use when |
|------|---------|----------|
| `"NFC"`  | Canonical composition | Default for storage and comparison — most pipelines expect this |
| `"NFD"`  | Canonical decomposition (combining marks separated) | You need to inspect or strip accents |
| `"NFKC"` | Compatibility composition (`½` → `1/2`-style folding) | You want visually-similar forms to compare equal (`"ﬁ"` ↔ `"fi"`, `"１"` ↔ `"1"`) |
| `"NFKD"` | Compatibility decomposition | NFKC's decomposed sibling |

## Monospace display width

```praia
let cells = unicode.displayWidth(s)
```

Sum of cell widths across grapheme clusters: ASCII = 1, CJK and emoji = 2, combining marks = 0. Use it for TUI/CLI layout where byte length and codepoint count both give the wrong answer.

```praia
let label = "你好 — \u{1F44B}"
let cells = unicode.displayWidth(label)   // 7 (4 + 2 + 1, padded by ASCII)
let pad = " ".repeat(20 - cells)
print(label + pad + "|")
```

The function takes the width of each grapheme cluster's first codepoint, so multi-codepoint emoji ZWJ sequences (`👨‍👩‍👧‍👦`) render as the base emoji's width (2), not the sum of each component (8). Control characters contribute 0 — `\t` and friends are rendered however the terminal feels like; this function doesn't expand them.

## Collation keys

`unicode.collateKey(s)` produces a byte string suitable for case-insensitive alphabetical sort:

```praia
let sorted = sort(names, lam{ a, b in
    unicode.collateKey(a) < unicode.collateKey(b)
})
```

`unicode.foldKey(s)` is the same idea but also strips combining marks — use it for diacritic-insensitive search:

```praia
if (unicode.foldKey(query) == unicode.foldKey(candidate)) {
    print("match (accents and case ignored)")
}
```

| | `collateKey` | `foldKey` |
|---|---|---|
| Case folded? | yes | yes |
| Combining marks kept? | yes | no |
| `"Élan"` vs `"elan"` | distinct keys, "elan" sorts first | identical keys |
| Best for | case-insensitive sort | accent-tolerant search |

### Scope of `collateKey`

`collateKey` is built on NFD + casefold and byte-compares the result. That gives a usable case-insensitive sort and handles diacritics gracefully, but it's not a UCA-grade locale collator: accented variants of a letter sort to the END of their letter's section rather than interleaving with un-accented variants. Concretely:

```praia
sort(["Élan", "Eve", "Adam", "elan", "edge"], lam{ a, b in
    unicode.collateKey(a) < unicode.collateKey(b)
})
// ["Adam", "edge", "elan", "Eve", "Élan"]
```

For most "sort this list of names" use cases that's the right answer. For real locale-specific tailoring — Spanish "ll", Swedish ä-after-z, Turkish dotless-i — link ICU and call `ucol_*` directly.

## Encoding conversions

`s.encode(encoding)` converts a UTF-8 string into bytes in the named encoding; `bytes.decode(b, encoding)` is the inverse. Use these when interacting with legacy data sources or non-UTF-8 protocols.

| Encoding | Notes |
|----------|-------|
| `"utf-8"` | Identity with validation -- invalid UTF-8 throws rather than passing through |
| `"utf-16le"` / `"utf-16be"` | Surrogate pairs for codepoints ≥ U+10000; odd byte counts and lone surrogates rejected on decode |
| `"latin-1"` (alias `"iso-8859-1"`) | Single-byte per codepoint; codepoints > U+00FF throw on encode |
| `"ascii"` | Codepoints/bytes must be < U+0080 |

Encoding names are case-insensitive and ignore `-` / `_`, so `"UTF-8"`, `"utf8"`, and `"Utf_8"` all resolve to the same encoder.

```praia
"caf\u{E9}".encode("latin-1")              // 4 bytes; "é" becomes a single byte 0xE9
"caf\u{E9}".encode("utf-8")                // 5 bytes; "é" is the two-byte 0xC3 0xA9
"\u{1F600}".encode("utf-16le")             // surrogate pair, little-endian units

let raw = fs.read("legacy.txt")
let text = bytes.decode(raw, "latin-1")    // safest fallback for unknown 8-bit data

// Unencodable codepoints throw rather than silently corrupting.
"\u{1F600}".encode("latin-1")              // throws: codepoint U+01F600 not encodable in latin-1
"caf\u{E9}".encode("ascii")                // throws: codepoint U+00E9 not encodable in ASCII
```

Asian legacy encodings (Shift-JIS, GBK, EUC-KR, Big5, Windows-125x) are intentionally out of scope -- they'd need either table-based decoders bundled into the binary or a libiconv dependency, and the modern web has moved on. Open an issue if you have a concrete interop need.

## Build dependency

`unicode.*` requires utf8proc. If Praia is built without it, every function in this namespace throws "requires utf8proc (rebuild with HAVE_UTF8PROC)". See [the installation guide](/getting-started/installation/) for how to get utf8proc on your system.
