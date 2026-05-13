---
title: XML and plist
sidebar:
  order: 13
---

The `xml` namespace is a DOM-style parser plus serializer for the practical XML subset; `plist` is an Apple-flavored property-list layer on top of it.

## XML

### Data model

Each element is a Praia map:

```praia
{
    tag: "div",
    attrs: {class: "box", id: "main"},
    children: [
        "Hello ",                                          // text node
        {tag: "b", attrs: {}, children: ["world"]},        // child element
        "!"
    ]
}
```

A `children` array can contain a mix of element maps and text-node strings, which is how mixed content like `<p>before <b>bold</b> after</p>` round-trips faithfully.

### Functions

| Function | Description |
|----------|-------------|
| `xml.parse(str)` | Parse an XML document; returns the root element map |
| `xml.stringify(tree, indent?)` | Serialize an element tree. With `indent > 0`, elements-only children are pretty-printed; elements containing mixed content stay inline so whitespace isn't corrupted |
| `xml.escape(str)` | Replace `< > & " '` with their entity references |
| `xml.unescape(str)` | Decode the 5 standard entities and numeric character references |

```praia
let doc = xml.parse("<book id=\"42\"><title>Praia</title></book>")
print(doc.tag)                       // "book"
print(doc.attrs.id)                  // "42"
print(doc.children[0].tag)           // "title"
print(doc.children[0].children[0])   // "Praia"

print(xml.stringify(doc))
// <book id="42"><title>Praia</title></book>
```

### What's supported

- Elements with attributes (both `"..."` and `'...'` quoting)
- Self-closing tags (`<br/>`)
- Mixed content (text interleaved with child elements)
- The 5 standard entities (`&lt; &gt; &amp; &quot; &apos;`)
- Numeric character references (`&#65;` decimal, `&#x41;` hex)
- CDATA sections (preserved verbatim)
- Comments / processing instructions / DOCTYPE -- skipped on parse

### Out of scope

Custom entity declarations / DTDs, XPath, XSLT, schema validation, namespace resolution (qualified names like `foo:bar` round-trip as plain strings -- no separate namespace URI tracking). The depth cap on nesting is 200; deeper inputs throw.

## Property Lists (plist)

Apple-flavored XML property lists, layered on top of `xml.parse`.

| plist element | Praia type |
|---------------|------------|
| `<dict>` (alternating `<key>` + value) | map |
| `<array>` | array |
| `<string>` | string |
| `<integer>` | int |
| `<real>` | float |
| `<true/>` / `<false/>` | bool |
| `<data>` | string (base64-decoded into raw bytes) |
| `<date>` | string (ISO 8601, verbatim) |

| Function | Description |
|----------|-------------|
| `plist.parse(str)` | Parse an XML plist into the typed Praia value |
| `plist.stringify(value, indent?)` | Serialize a Praia value as an XML plist with the canonical Apple DOCTYPE |

```praia
let cfg = plist.parse(fs.read("Info.plist"))
print(cfg.CFBundleIdentifier)
print(cfg.CFBundleVersion)

let out = plist.stringify({name: "Ada", version: 1, tags: ["alpha", "beta"]}, 2)
fs.write("out.plist", out)
```

### Limits

- **Binary plists** (`bplist00` magic) are NOT supported. The parser throws a clear error pointing at `plutil -convert xml1 file.plist` (the standard macOS converter).
- **Dates** round-trip as ISO 8601 strings; the parser doesn't convert them into `time.*` epoch seconds because Praia's time API is Unix-seconds and date-string arithmetic isn't in core.
- **`<data>` on output**: Praia strings double as byte sequences, so `plist.stringify` always emits `<string>` even for binary payloads. If you specifically need `<data>` output, build the XML by hand with `xml.stringify`.
- **`nil`** has no plist representation; emitting it throws.
