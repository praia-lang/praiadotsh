---
title: Standard Grains
sidebar:
  order: 2
---

Praia ships with a set of standard library grains. These are installed to `<libdir>/grains/` and available in any project without installation.

Import them with `use`:

```praia
use "testing"
use "router"
use "colors"
```

## Available grains

### Web & Networking

| Grain | Description |
|-------|-------------|
| `router` | Express-style HTTP routing with path parameters, middleware support |
| `middleware` | CORS, JSON body parsing, auth, request IDs for the router |
| `cookie` | HTTP cookie parsing and building |
| `session` | Server-side session management (in-memory store) |

### Testing

| Grain | Description |
|-------|-------------|
| `testing` | Test framework with `test()`, `assertEqual()`, `done()` |

### Data formats

| Grain | Description |
|-------|-------------|
| `csv` | CSV parsing and generation |
| `toml` | TOML parser |
| `ini` | INI file parser |
| `html` | HTML utilities |
| `markdown` | Markdown processing |
| `template` | String templating |

### Terminal & Output

| Grain | Description |
|-------|-------------|
| `colors` | ANSI color and style helpers (red, green, bold, RGB, etc.) |
| `progress` | Progress bars and spinners |
| `table` | Formatted text tables |
| `logger` | Structured logging with levels (debug, info, warn, error) |

### Utilities

| Grain | Description |
|-------|-------------|
| `strings` | Extended string utilities |
| `collections` | Data structure utilities |
| `math` | Extended math functions |
| `geometry` | Geometry helpers |
| `datetime` | Date and time utilities |
| `timers` | Timer utilities |
| `uuid` | UUID generation |
| `validate` | Input validation |
| `args` | Command-line argument parsing |
| `diff` | Text diffing |
| `sync` | Synchronization primitives |

### Binary & Encoding

| Grain | Description |
|-------|-------------|
| `hex` | Hex encoding/decoding, integer conversion, hex dumps |
| `re` | Advanced regex with named groups, split, escape |

## Example: testing

```praia
use "testing"

testing.test("addition", lam{ in
    testing.assertEqual(1 + 1, 2, nil)
})

testing.done()
```

Run with `praia test` to discover and execute test files.

## Example: router with middleware

```praia
use "router"
use "middleware"
use "logger"

let log = logger.create("API")
let server = router.create()

server.use(middleware.cors())
server.use(middleware.jsonBody())
server.use(logger.middleware(log))

server.get("/", lam{ req, params in
    return http.json({message: "hello"})
})

server.listen(8080)
```

## Example: colors

```praia
use "colors"

print(colors.red("error:") + " something went wrong")
print(colors.green("ok"))
print(colors.bold(colors.blue("important")))
print(colors.rgb("custom color", 255, 128, 0))
```

## Example: progress bar

```praia
use "progress"

let p = progress.bar({width: 30, showCount: true})
p.total(100)

for (i in 0..101) {
    p.update(i)
    time.sleep(10)
}
p.done()
```

## Example: table

```praia
use "table"

let users = [
    {name: "Alice", age: 30, role: "admin"},
    {name: "Bob", age: 25, role: "user"}
]
print(table.render(users))
```

## Example: hex

```praia
use "hex"

hex.encode("Hello")          // "48656c6c6f"
hex.decode("48656c6c6f")     // "Hello"
hex.fromInt(255, 4)          // "00ff"
hex.toInt("0xDEADBEEF")     // 3735928559
print(hex.dump("Hello, World!\n"))
```
