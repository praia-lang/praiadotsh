---
title: WebSocket
sidebar:
  order: 9
---

The `socket` grain provides WebSocket server support. Each connection runs in its own background thread.

## Basic echo server

```praia
use "socket"

let server = http.createServer(lam{ req in
    if (req.path == "/ws") {
        return socket.upgrade(req, lam{ ws in
            ws.onMessage(lam{ msg in ws.send("echo: " + msg) })
            ws.onClose(lam{ in print("disconnected") })
            ws.send("Welcome!")
        })
    }
    return {body: "Hello"}
})
server.listen(8080)
```

## API

`socket.upgrade(req, handler)` upgrades an HTTP request to a WebSocket connection. Call it inside an `http.createServer` handler and return its result.

The `handler` function receives a `ws` object:

| Method | Description |
|--------|-------------|
| `ws.send(msg)` | Send a text message |
| `ws.sendBinary(data)` | Send binary data |
| `ws.close()` | Close the connection |
| `ws.onMessage(fn)` | Set message handler |
| `ws.onClose(fn)` | Set close handler |
| `ws.id` | Unique connection ID |

## With the router

```praia
use "router"
use "socket"

let app = router.create()

app.get("/ws", lam{ req in
    return socket.upgrade(req, lam{ ws in
        ws.onMessage(lam{ msg in ws.send("echo: " + msg) })
    })
})

app.listen(8080)
```

## Chat server example

```praia
use "socket"

let clients = []

let server = http.createServer(lam{ req in
    if (req.path == "/chat") {
        return socket.upgrade(req, lam{ ws in
            push(clients, ws)
            ws.onMessage(lam{ msg in
                for (c in clients) {
                    if (c.id != ws.id) {
                        try { c.send(msg) } catch (e) {}
                    }
                }
            })
            ws.onClose(lam{ in
                clients = clients |> filter(lam{ c in c.id != ws.id })
            })
        })
    }
    return {body: "Chat server"}
})
server.listen(8080)
```
