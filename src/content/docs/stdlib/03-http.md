---
title: HTTP
sidebar:
  order: 3
---

The `http` namespace provides an HTTP/HTTPS client and server. HTTPS requires OpenSSL.

## HTTP Client

### GET request

```praia
let res = http.get("http://example.com/api")
print(res.status)       // 200
print(res.body)         // response body string
print(res.headers)      // map of lowercase header names
```

### POST request

```praia
// Simple string body
let res = http.post("http://example.com/api", "hello")

// With headers
let res = http.post("http://example.com/api", {
    body: "{\"name\": \"Ada\"}",
    headers: {"Content-Type": "application/json"}
})
```

### General request

```praia
let res = http.request({
    method: "PUT",
    url: "http://example.com/api/1",
    body: "updated data",
    headers: {"Content-Type": "text/plain"}
})
```

### Response format

All client methods return:

```praia
{
    status: 200,
    body: "...",
    headers: {"content-type": "text/html", ...}
}
```

Header names are lowercased for consistent access.

### Request options

`http.request({...})` accepts these option fields beyond `method`/`url`/`body`/`headers`. All are optional with safe defaults.

| Option | Default | Effect |
|--------|---------|--------|
| `timeout` | -- | Shorthand: same value applied to connect, read, AND total. Seconds (float ok) |
| `connectTimeout` | 30 | TCP/TLS handshake budget, in seconds |
| `readTimeout` | 30 | Per `recv()` / `SSL_read()` budget, in seconds |
| `totalTimeout` | none | Overall request budget including redirects, in seconds |
| `followRedirects` | `true` | Follow 3xx responses with Location headers |
| `maxRedirects` | 10 | Throw if a chain exceeds this |
| `insecure` | `false` | **Skip TLS certificate verification.** Testing/dev only; equivalent to `curl -k` |
| `caBundle` | system trust store | Path to a custom CA PEM bundle |

```praia
// Strict timeouts on a flaky upstream
let r = http.request({
    url: "https://api.flaky.example.com/data",
    connectTimeout: 3,
    readTimeout: 5,
    totalTimeout: 10,
})

// Inspect a 3xx ourselves
let r = http.request({url: probableRedirect, followRedirects: false})
if (r.status == 301) { ... }

// Self-signed dev cert (skip verify)
let r = http.request({url: "https://localhost:8443/", insecure: true})

// Internal CA / private PKI
let r = http.request({url: "https://internal.corp/", caBundle: "/etc/ssl/corp-root.pem"})
```

### Redirects

The client follows 3xx with Location by default, up to `maxRedirects` hops.

- **303 See Other**: always switches to GET, drops the request body.
- **301 / 302**: switches POST (or any non-GET/HEAD method) to GET and drops the body. Matches every browser/HTTP-library convention since the 1990s.
- **307 / 308**: preserves both method AND body. These codes exist to disambiguate from the 301/302 method-switch behavior.

**Security**: an `https://` → `http://` Location is refused outright. Relative-path Locations like `?foo=bar` aren't supported; absolute paths (`/foo`) and protocol-relative (`//host/foo`) URLs are.

When `followRedirects` is `false`, the 3xx response is returned as-is with `Location` in `headers.location`.

### Timeouts

- **`connectTimeout`** uses non-blocking connect + poll, so a slow handshake doesn't stall the calling task.
- **`readTimeout`** is enforced via `SO_RCVTIMEO`/`SO_SNDTIMEO`; each individual recv/send can wait at most this long.
- **`totalTimeout`** bounds the entire request including all redirect hops. Per-request timeouts are capped at the remaining budget when this kicks in.

Connect failures throw "connect timed out after Nms"; read failures throw "HTTP read timed out".

### Streaming responses — `http.openStream`

`http.request` slurps the body into memory. `http.openStream` returns a stream handle so you can consume the response incrementally — for downloads bigger than RAM, NDJSON feeds, log tails, etc.

```praia
let s = http.openStream({url: "https://example.com/big.json"})
print(s.status, s.headers["content-length"])

while (!s.eof()) {
    let chunk = s.read(8192)
    process(chunk)
}
s.close()
```

Same options surface as `http.request` (timeouts, redirects, TLS). Redirects are followed before the handle is returned -- by the time you see `s.status`, you're looking at the final response.

#### Handle methods

| Method | Description |
|--------|-------------|
| `s.status` | HTTP status code (int) |
| `s.headers` | Response headers map (lowercase keys) |
| `s.cookies` | Array of raw `Set-Cookie` header values |
| `s.read(n)` | Read up to `n` bytes; `""` at EOF |
| `s.readLine()` | Read one line (no trailing `\n`); `nil` at EOF. CRLF and LF both work |
| `s.readAll()` | Drain everything remaining as a string |
| `s.eof()` | `true` once the body is exhausted |
| `s.close()` | Close the connection. Idempotent. Subsequent reads throw |

#### Framing

The stream decodes three body framings transparently:

- **`Content-Length: N`** -- exactly N bytes, then EOF.
- **`Transfer-Encoding: chunked`** -- parses `HEXSIZE\r\n<data>\r\n` until the `0\r\n` terminator. Chunk extensions (`;k=v` after the size) are ignored.
- **Neither header** -- read until the server closes (HTTP/1.0; HTTP/1.1 with `Connection: close`).

#### Composing with json.parser

The handle has the same `.read(n)` shape `json.parser` expects, so streaming NDJSON over HTTP is one line of glue:

```praia
let s = http.openStream({url: feedUrl})
let p = json.parser(s)
while (!p.eof()) {
    let record = p.nextValue()
    handleRecord(record)
}
s.close()
```

#### Limits

- **Streamed request bodies** aren't supported -- `body` is sent up front. For huge uploads, use multipart-with-temp-file or a different protocol.
- The handle keeps the underlying TCP socket open until `.close()`. Don't leak handles.

## HTTP Server

### Creating a server

Pass a handler function to `http.createServer`. The handler receives a request map and returns a response map:

```praia
let server = http.createServer(lam{ req in
    if (req.path == "/") {
        return {
            status: 200,
            body: "<h1>Hello!</h1>",
            headers: {"Content-Type": "text/html"}
        }
    }
    return {status: 404, body: "Not Found"}
})

server.listen(8080)
```

### Request object

| Field | Description |
|-------|-------------|
| `method` | `"GET"`, `"POST"`, etc. |
| `path` | URL path (e.g. `"/hello"`) |
| `query` | Parsed query parameters as a map |
| `headers` | Map of lowercase header names |
| `body` | Request body string |

### Response format

| Field | Default | Description |
|-------|---------|-------------|
| `status` | `200` | HTTP status code |
| `body` | `""` | Response body |
| `headers` | `{"Content-Type": "text/plain"}` | Response headers |

You can also return a plain string, which becomes a 200 text/plain response.

### Response helpers

| Helper | Description |
|--------|-------------|
| `http.json(obj, status?)` | JSON response with `application/json` |
| `http.text(str, status?)` | Plain text response |
| `http.html(str, status?)` | HTML response with `charset=utf-8` |
| `http.redirect(url, status?)` | Redirect (302 by default) |
| `http.file(path, status?, opts?)` | Serve a file with auto-detected MIME type |

```praia
return http.json(data)
return http.json({error: "not found"}, 404)
return http.text("hello")
return http.html("<h1>Hi</h1>")
return http.redirect("/login")
return http.redirect("/new-url", 301)
return http.file("public/style.css")
```

#### Serving files from user input — path traversal

`http.file` and `http.fileStream` will serve whatever path you give them — including `/etc/passwd`. By design: if you're serving a hard-coded asset, you don't pay any path-resolution overhead, and the API stays out of your way. **But if any part of the path comes from a request** (URL params, query strings, form fields, headers), you must constrain where it can resolve to, or an attacker passing `../../etc/passwd` will read whatever the server process can read.

Use the `withinDir` option — it resolves both the path and the dir to their canonical absolute forms (handling `..`, relative components, and symlinks) and refuses to serve anything outside:

```praia
server.get("/files/:name", lam{ req, params in
    // Without withinDir, a name of "../../etc/passwd" would be served.
    // With it, the request gets rejected before any read.
    return http.file("uploads/" + params.name, {withinDir: "uploads"})
})
```

On escape, the call throws — handle it like any other error (return 404, log, etc.):

```praia
try {
    return http.file("uploads/" + params.name, {withinDir: "uploads"})
} catch (e) {
    return http.text("not found", 404)
}
```

Symlinks pointing outside the jail are blocked too (a symlink in `uploads/` that targets `/etc/passwd` is rejected).

### Server-Sent Events (SSE)

`http.sse(req, callback)` keeps the connection open for real-time streaming:

```praia
server.get("/events", lam{ req, params in
    return http.sse(req, lam{ send in
        for (i in 0..10) {
            send(json.stringify({count: i}), "update")
            time.sleep(1000)
        }
        send("done", "close")
    })
})
```

### Request body size

The server has no built-in cap on request body size — it reads up to `Content-Length` bytes into `req.body`. This matches the philosophy of `net/http`, Flask, and Express: the stdlib stays out of policy. If you need a limit, opt in:

- **Application-level** — use `middleware.bodyLimit(n)` from the [middleware grain](/grains/standard/) to reject requests with `Content-Length` over `n` bytes (returns 413).
- **DoS-grade** — put a reverse proxy (nginx, caddy) in front. A determined attacker can lie about `Content-Length` or stream forever; only the proxy can short-circuit before the body is buffered.

```praia
use "router"
use "middleware"

let app = router.create()
app.use(middleware.bodyLimit(10_000_000))   // 10 MB cap
```

Headers are capped at 64 KB regardless.

### Error handling

If the handler throws an error, the server returns a 500 response and continues running.

### Graceful shutdown

The server handles `SIGINT` (Ctrl-C) and `SIGTERM` gracefully. Code after `listen()` runs after shutdown:

```praia
server.listen(8080)
print("Shutting down...")
db.close()
```

## URL encoding

| Function | Description |
|----------|-------------|
| `http.encodeURI(str)` | Percent-encode a string (RFC 3986) |
| `http.decodeURI(str)` | Decode percent-encoded sequences |

```praia
http.encodeURI("hello world")       // "hello%20world"
http.decodeURI("hello%20world")    // "hello world"
```

## URL parsing

`url.parse` decomposes a URL into RFC 3986 components: `scheme`,
`userinfo`, `host`, `port`, `path`, `query`, `fragment`. Scheme is
lowercased; `port` is `nil` when absent (so an explicit `0` is
distinguishable); IPv6 literals must be bracketed in the URL but the
`host` field is returned unbracketed.

```praia
let u = url.parse("https://user:pass@example.com:8080/api?key=val#section")
print(u.scheme)    // "https"
print(u.userinfo)  // "user:pass"
print(u.host)      // "example.com"
print(u.port)      // 8080
print(u.path)      // "/api"
print(u.query)     // "key=val"
print(u.fragment)  // "section"

let v = url.parse("http://[::1]:8080/")
print(v.host)      // "::1"   (brackets stripped)
print(v.port)      // 8080
```

Malformed input throws: non-numeric or out-of-range ports, an
unterminated `[..]` literal, a bare IPv6 address without brackets
(ambiguous), or any CR/LF/NUL byte (header-injection guard).

## URL building

The inverse of `url.parse`: compose a URL string from a component map. Every field is optional.

```praia
url.build({scheme: "https", host: "api.example.com", path: "/v1/items"})
// "https://api.example.com/v1/items"

url.build({
    scheme: "https",
    host:   "api.example.com",
    port:   8443,
    path:   "/v1/items",
    query:  {limit: 50, tag: "blue"},
    fragment: "section-1"
})
// "https://api.example.com:8443/v1/items?limit=50&tag=blue#section-1"
```

- IPv6 hosts are auto-bracketed.
- Default ports (`80` for `http`, `443` for `https`) are dropped.
- `query` can be a string (verbatim) or a map (run through `buildQuery`).
- Without `scheme`/`host`, you get a relative URL (`/items?limit=10`).
- Opaque URIs like `mailto:ada@example.com` work with `{scheme: "mailto", path: "ada@example.com"}`.

## Query strings

| Function | Behavior |
|----------|----------|
| `url.buildQuery(map)` | Serialize to `k=v&k=v` with RFC 3986 percent-encoding |
| `url.parseQuery(str)` | Parse; repeated keys auto-collapse to an array |
| `url.parseQueryAll(str)` | Parse; values are always arrays (predictable shape) |
| `url.encode(str)` / `url.decode(str)` | Component-level percent-encoding; `decode` also handles `+` as space |

```praia
url.buildQuery({a: 1, b: "hello world", c: true})
// "a=1&b=hello%20world&c=true"

url.buildQuery({tags: ["red", "blue"]})
// "tags=red&tags=blue"

url.buildQuery({a: "kept", b: nil})
// "a=kept"                        // nil values skipped

url.parseQuery("tags=red&tags=blue")
// {tags: ["red", "blue"]}         // auto-array on repeated key

url.parseQueryAll("a=1&b=2&a=3")
// {a: ["1", "3"], b: ["2"]}       // always arrays
```

`buildQuery` rejects nested maps or arrays inside values -- there's no canonical wire form. Use JSON-encoded strings if you need structured data in a query parameter.

## Router grain

For Express-style routing with path parameters, see the [router grain](/grains/standard/).

```praia
use "router"

let server = router.create()

server.get("/users/:id", lam{ req, params in
    return {status: 200, body: "User %{params.id}"}
})

server.listen(8080)
```
