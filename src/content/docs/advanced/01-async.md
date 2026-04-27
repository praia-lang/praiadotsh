---
title: Async & Concurrency
sidebar:
  order: 1
---

`async` runs a function call in a background thread and returns a **future**. `await` blocks until the future has a result. Both native and Praia functions run in true parallel.

## Basic usage

```praia
func compute(n) {
    let sum = 0
    for (i in 0..n) { sum += i }
    return sum
}

let f1 = async compute(10000)
let f2 = async compute(20000)
let f3 = async compute(30000)

print(await f1, await f2, await f3)
```

## Parallel shell commands

```praia
let f1 = async sys.exec("sleep 1 && echo done1")
let f2 = async sys.exec("sleep 1 && echo done2")
let f3 = async sys.exec("sleep 1 && echo done3")

print(await f1, await f2, await f3)
// Total time: ~1 second (not 3)
```

## futures.all and futures.race

```praia
// Wait for all futures, returns an array of results
let fs = map([1,2,3,4,5], lam{ n in async compute(n) })
let results = futures.all(fs)

// Wait for the first future to finish
let winner = futures.race([async slowTask(), async fastTask()])
```

| Function | Description |
|----------|-------------|
| `futures.all(arr)` | Await all futures, return results as an array |
| `futures.race(arr)` | Return the result of the first future to complete |

## Error handling

If an async task throws, `await` re-throws it:

```praia
let f = async http.get("http://invalid-host")
try {
    let r = await f
} catch (err) {
    print("request failed:", err)
}
```

## How it works

- `async funcCall(args)` evaluates the function and arguments on the current thread, then spawns the call in a new OS thread
- Returns a **future** immediately
- `await future` blocks until the background thread finishes
- Each async Praia function gets its own VM with a snapshot of globals -- tasks are fully isolated, no shared mutable state, no data races
- Native functions (`http.get`, `sys.exec`, etc.) also run in true parallel

## Channels

Channels are thread-safe queues for communication between async tasks.

```praia
let ch = Channel()      // unbuffered channel
let ch = Channel(10)    // buffered channel (up to 10 items)
```

| Method | Description |
|--------|-------------|
| `ch.send(val)` | Send a value (blocks if full) |
| `ch.recv()` | Receive a value (blocks until available, nil when closed + empty) |
| `ch.tryRecv()` | Non-blocking receive (nil if empty) |
| `ch.close()` | Close the channel (no more sends) |
| `ch.closed()` | Returns true if closed and empty |

### Producer-consumer

```praia
let ch = Channel()

func producer(ch) {
    for (i in 0..5) {
        ch.send(i)
    }
    ch.close()
}

async producer(ch)

while (true) {
    let val = ch.recv()
    if (val == nil) { break }
    print(val)
}
```

### Fan-out: multiple workers

```praia
let results = Channel()

func scan(target, results) {
    let r = sys.exec("ping -c1 -W1 " + target)
    if (r.exitCode == 0) {
        results.send(target + " is up")
    } else {
        results.send(target + " is down")
    }
}

let targets = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
for (t in targets) {
    async scan(t, results)
}

for (i in 0..len(targets)) {
    print(results.recv())
}
```

## Lock

`Lock()` creates a mutex for thread-safe access to shared state.

```praia
let lock = Lock()
let counter = 0

// Manual acquire/release
lock.acquire()
counter = counter + 1
lock.release()

// withLock -- auto-releases when the function returns (or throws)
lock.withLock(lam{ in
    counter = counter + 1
})
```

| Method | Description |
|--------|-------------|
| `lock.acquire()` | Acquire the lock (blocks if held) |
| `lock.release()` | Release the lock |
| `lock.withLock(fn)` | Acquire, call fn, release -- even if fn throws |

**Always prefer `withLock`** -- it handles errors correctly and cannot forget to release.

The lock is re-entrant: the same thread can acquire it multiple times without deadlocking.

## HTTP server concurrency

The HTTP server is **single-threaded** -- handlers run serially. If you use `async` inside a handler, use `Lock()` to protect shared data:

```praia
let lock = Lock()
let db = sqlite.open("app.db")

server.post("/increment", lam{ req, params in
    let result = lock.withLock(lam{ in
        let row = db.query("SELECT count FROM counters WHERE id = 1")
        let newCount = row[0].count + 1
        db.run("UPDATE counters SET count = ? WHERE id = 1", [newCount])
        return newCount
    })
    return http.json({count: result})
})
```
