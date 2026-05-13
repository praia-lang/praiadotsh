---
title: JSON & YAML
sidebar:
  order: 4
---

## JSON

The `json` namespace provides fast built-in JSON parsing and serialization.

### json.parse(string)

Converts a JSON string into Praia values:

| JSON | Praia |
|------|-------|
| `{}` | map |
| `[]` | array |
| `"string"` | string |
| `123` | number |
| `true/false` | bool |
| `null` | nil |

```praia
let data = json.parse("{\"name\": \"Ada\", \"age\": 36}")
print(data.name)        // Ada
print(data.age)         // 36

let list = json.parse("[1, 2, 3]")
print(list)             // [1, 2, 3]
```

### json.stringify(value, indent?)

Converts a Praia value to a JSON string. Optional `indent` for pretty-printing.

```praia
let obj = {name: "Ada", scores: [100, 95]}

json.stringify(obj)         // {"name":"Ada","scores":[100,95]}
json.stringify(obj, 2)      // pretty-printed with 2-space indent
```

### Round-tripping

```praia
let original = {users: [{name: "Alice"}, {name: "Bob"}]}
let str = json.stringify(original)
let restored = json.parse(str)
print(restored.users[0].name)   // Alice
```

### json.parser(input) -- streaming

`json.parser` is a pull-parser for streaming over JSON that doesn't fit in memory, or for newline-delimited JSON (NDJSON) feeds. `input` is either a string or a file handle (anything with a `.read(n)` method -- typically the value returned by `fs.open`). The returned object exposes:

| Method | Description |
|--------|-------------|
| `.next()` | Advance to the next token. Returns an event map `{type, value}`, or `nil` at end-of-stream |
| `.nextValue()` | Materialize one whole top-level value. Returns `nil` at EOF (use `eof()` to disambiguate from a literal `null`) |
| `.eof()` | `true` once no more data remains |
| `.close()` | Release the parser's buffer (the underlying handle stays caller-owned) |

Event `type` is one of `"objectStart"`, `"objectEnd"`, `"arrayStart"`, `"arrayEnd"`, `"key"`, `"string"`, `"number"`, `"bool"`, `"null"`. For `key`/`string`/`number`/`bool` the event also has a `value` field; for `null` the value is `nil`.

#### NDJSON loop -- the killer use case

```praia
let h = fs.open("server.log.ndjson", "r")
let p = json.parser(h)
while (!p.eof()) {
    let record = p.nextValue()
    if (record.level == "error") { print(record) }
}
h.close()
```

The parser refills its 16 KiB internal buffer from the handle on demand, so a multi-gigabyte log file streams through one chunk at a time. NDJSON works transparently -- the parser accepts any number of whitespace-separated top-level values rather than insisting on a single root.

#### Token-level walk

Use `.next()` when you want to skip uninteresting subtrees without materializing them, or when you need precise control over how the document is traversed (e.g. JSON-Pointer style lookups, schema-driven extraction).

#### Errors

Malformed input throws `json.parser: <detail> at byte <N>`: unterminated strings, dangling escapes, invalid `\u` escapes (lone surrogates), trailing commas, mismatched closers, unescaped control characters, and nesting beyond 200 levels.

## YAML

The `yaml` namespace provides built-in YAML parsing and serialization. Supports mappings, sequences, nested structures, comments, flow sequences, and quoted strings.

### yaml.parse(string)

```praia
let config = yaml.parse("host: localhost\nport: 8080\ndebug: true")
print(config.host)      // localhost
print(config.port)      // 8080
print(config.debug)     // true
```

Nested:

```praia
let yaml_str = "database:\n  host: localhost\n  port: 5432"
let conf = yaml.parse(yaml_str)
print(conf.database.host)   // localhost
```

Sequences:

```praia
let list = yaml.parse("- apple\n- banana\n- cherry")
print(list)                 // ["apple", "banana", "cherry"]
```

Flow sequences:

```praia
let data = yaml.parse("tags: [web, api, fast]")
print(data.tags)            // ["web", "api", "fast"]
```

Comments are stripped:

```praia
let data = yaml.parse("name: Ada  # the inventor")
print(data.name)            // Ada
```

### yaml.stringify(value)

```praia
let obj = {name: "Praia", features: ["fast", "simple"]}
print(yaml.stringify(obj))
// name: Praia
// features:
//   - fast
//   - simple
```

### Reading config files

```praia
let config = yaml.parse(fs.read("config.yaml"))
print("Listening on port %{config.server.port}")
```
