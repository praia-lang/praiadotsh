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
| `http.file(path, status?)` | Serve a file with auto-detected MIME type |

```praia
return http.json(data)
return http.json({error: "not found"}, 404)
return http.text("hello")
return http.html("<h1>Hi</h1>")
return http.redirect("/login")
return http.redirect("/new-url", 301)
return http.file("public/style.css")
```

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

```praia
let u = url.parse("https://example.com:8080/api?key=val")
print(u.scheme)    // "https"
print(u.host)      // "example.com"
print(u.port)      // 8080
print(u.path)      // "/api"
print(u.query)     // "key=val"
```

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
