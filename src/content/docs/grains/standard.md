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
| `middleware` | CORS, JSON body parsing, auth, request IDs, body size limits for the router |
| `cookie` | Parse/build single headers, `parseSet` for response attributes, `sign`/`verify` (HMAC), `encrypt`/`decrypt` (AEAD), and a `Jar` class that tracks cookies across requests |
| `multipart` | Parser for `multipart/form-data` request bodies. `parse(req, {maxSize: N})` and a router `middleware()` form |
| `session` | Server-side session management (in-memory store) |

### Testing

| Grain | Description |
|-------|-------------|
| `testing` | Assertions, fixtures (`tempDir`, `cleanup`), `beforeEach`/`afterEach`, `subtest`/`testEach`, `skip`/`only`, `matchSnapshot` |

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
| `logger` | Leveled, structured logging. Sinks (`stdoutSink`, `stderrSink`, `fileSink`, `multiSink`), formatters (`textFormatter`, `jsonFormatter`), `.with()` for sticky context |

### Utilities

| Grain | Description |
|-------|-------------|
| `strings` | Extended string utilities |
| `collections` | `Stack`, `Queue`, `Deque`, `Set`, `OrderedMap`, `Counter`, `DefaultDict` — each header has Big-O notes |
| `heap` | Binary min-heap (priority queue) on plain arrays: `push`, `pop`, `peek`, `heapify`, `pushPop`, `replace`. Optional `keyFn` for priority-queue use |
| `bisect` | Binary search on sorted arrays: `left`, `right`, `insort`, `contains`. Mirrors Python's `bisect` module |
| `statistics` | Numeric descriptive stats: `mean`, `median` (+ `medianLow`/`High`), `mode`, `multimode`, `variance`/`pvariance`, `stdev`/`pstdev`, `range`, `quantiles`, `covariance`, `correlation` |
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

// Fixtures: temp dirs auto-clean at end-of-test.
testing.test("uses a temp dir", lam{ in
    let dir = testing.tempDir()
    fs.write(dir + "/x.txt", "hi")
    testing.assertEqual(fs.read(dir + "/x.txt"), "hi", nil)
})

// Subtests + table-driven cases.
testing.testEach("addition cases", [
    {name: "0+0", a: 0, b: 0, want: 0},
    {name: "neg", a: -1, b: 1, want: 0}
], lam{ t, c in
    t.assertEqual(c.a + c.b, c.want, nil)
})

// Snapshots: first run writes, later runs compare.
// Re-run with PRAIA_UPDATE_SNAPSHOTS=1 to accept new output.
testing.test("render", lam{ in
    testing.matchSnapshot("default", "expected\noutput\n")
})

testing.done()
```

`testing.beforeEach(fn)` / `afterEach(fn)` register file-scoped hooks.
A throwing `beforeEach` skips the test body but still runs `afterEach`
and cleanups. `testing.cleanup(fn)` registers a per-test cleanup
(reverse-order, runs after `afterEach`, runs even when the body
throws). `testing.skip(name, fn?)` and `testing.only(name, fn)` control
which tests run.

`testing.assertContains` works on strings (substring), arrays (element),
and maps (**key presence** — `{a: nil}` still contains `"a"`).

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
server.use(middleware.bodyLimit(10_000_000))   // reject bodies > 10 MB with 413
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
