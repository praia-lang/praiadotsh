---
title: Networking
sidebar:
  order: 6
---

The `net` namespace provides TCP and UDP socket operations, DNS resolution, and socket timeouts. All functions support both IPv4 and IPv6.

## TCP Client

```praia
let sock = net.connect("localhost", 5432)
net.send(sock, "hello")
let response = net.recv(sock)
print(response)
net.close(sock)
```

## TCP Server

```praia
let server = net.listen(9000)
print("listening on 9000")

while (true) {
    let client = net.accept(server)
    let data = net.recv(client)
    net.send(client, "echo: " + data)
    net.close(client)
}
```

## UDP

```praia
// Send a UDP datagram
let sock = net.udp()
net.sendTo(sock, "127.0.0.1", 9999, "hello udp")
net.close(sock)

// Listen for UDP datagrams
let server = net.udpBind(9999)
let msg = net.recvFrom(server)
print(msg.data, "from", msg.host, msg.port)
net.close(server)
```

## DNS Resolution

```praia
let ips = net.resolve("example.com")
print(ips)    // ["93.184.216.34", "2606:2800:..."]
```

## Socket Timeouts

```praia
let sock = net.connect("localhost", 8080)
net.setTimeout(sock, 5000)     // 5 second timeout
```

## Function reference

### TCP

| Function | Description |
|----------|-------------|
| `net.connect(host, port)` | Connect to a TCP server, returns socket |
| `net.listen(port)` | Bind and listen on a port, returns server socket |
| `net.accept(server)` | Accept a connection, returns client socket |
| `net.send(sock, data)` | Send a string, returns bytes sent |
| `net.recv(sock, maxBytes?)` | Receive data (default 4096 bytes), returns string |
| `net.recvAll(sock)` | Read until connection closes, returns string |

### UDP

| Function | Description |
|----------|-------------|
| `net.udp()` | Create an IPv4 UDP socket |
| `net.udp6()` | Create an IPv6 UDP socket |
| `net.udpBind(port)` | Create and bind a UDP socket to a port |
| `net.sendTo(sock, host, port, data)` | Send a UDP datagram |
| `net.recvFrom(sock, maxBytes?)` | Receive a datagram, returns `{data, host, port}` |

### Raw sockets

| Function | Description |
|----------|-------------|
| `net.rawSocket(protocol)` | Create a raw socket (`"icmp"`, `"tcp"`, `"udp"`, etc.) |
| `net.rawSend(sock, host, data)` | Send raw data to a host |
| `net.rawRecv(sock, maxBytes?)` | Receive raw data, returns `{data, host}` |

Raw sockets require root or `CAP_NET_RAW` on Linux. On macOS, unprivileged ICMP echo is supported via a `SOCK_DGRAM` fallback.

### General

| Function | Description |
|----------|-------------|
| `net.resolve(host)` | DNS lookup, returns array of IP strings |
| `net.setTimeout(sock, ms)` | Set send/recv timeout in milliseconds |
| `net.close(sock)` | Close a socket |

## Example: ICMP ping

```praia
if (!sys.isRoot()) {
    print("warning: raw sockets may need root")
}

let sock = net.rawSocket("icmp")
net.setTimeout(sock, 2000)

let packet = bytes.pack(">BBHHh", [8, 0, 0, 1, 1])
net.rawSend(sock, "127.0.0.1", packet)
let reply = net.rawRecv(sock)
print("reply from:", reply.host)
net.close(sock)
```
