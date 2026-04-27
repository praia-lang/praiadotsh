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
let config = yaml.parse(sys.read("config.yaml"))
print("Listening on port %{config.server.port}")
```
