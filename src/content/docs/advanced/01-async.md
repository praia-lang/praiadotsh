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
- Each async Praia function gets its own VM with a **deep copy** of globals, captured upvalues, and arguments — tasks are fully isolated, no shared mutable state, no data races
- Native functions (`http.get`, `sys.exec`, etc.) also run in true parallel
- A bare `async fn()` (no `let f =`) is fire-and-forget — it returns immediately and the task runs to completion in the background

## Sharing state across async tasks

Because globals/upvalues/arguments are deep-copied, **you cannot share a Praia map, array, or class instance between an async task and its caller** — each side has its own independent copy. This is the price of "no data races" in user code.

```praia
let m = {}
func writer(k, v) { m[k] = v }
let f = async writer("a", 1)
await f
print(m)              // {} — the task mutated its own copy of `m`
```

To communicate, use one of the following:

- **`SharedMap`** — cross-task key-value store. Use this when async tasks need to read or write shared state by key (progress trackers, job state, caches). See below.
- **`Queue`** — built for cross-task messaging (the queue itself isn't deep-copied; only the values you send through it are messages, not shared state).
- **`CancellationToken`** — cooperative cancel signal. The caller flips the flag; long-running tasks poll and bail. See below.
- **External resources** — files, SQLite, sockets, native plugin state. These live outside the Praia heap, so all tasks see the same underlying resource. Use `Lock()` to coordinate concurrent access (see below).
- **`await`** — collect results back from the task. The future's return value is moved across the boundary.

## SharedMap

`SharedMap()` is a thread-safe key-value store that survives the `async` deep-copy. Unlike a regular `{}` map, mutations from inside an async task are visible to the caller and vice versa.

```praia
let jobs = SharedMap()

jobs.set("abc", {progress: 0})
let f = async lam{ in
    jobs.update("abc", lam{ s in s.progress = 50; return s })
}()
await f
print(jobs.get("abc"))     // {progress: 50}
```

| Method | Description |
|--------|-------------|
| `m.set(k, v)` | Insert or replace the value for `k`. |
| `m.get(k)` | Returns the value, or `nil` if absent. |
| `m.get(k, default)` | Returns the value, or `default` if absent. |
| `m.has(k)` | `true` if `k` is present. |
| `m.delete(k)` | Removes `k`. Returns `true` if it was present. |
| `m.update(k, fn)` | Atomic read-modify-write. `fn` receives the current value (or `nil`); its return value is stored. Lock held during `fn`. |
| `m.keys()` | Snapshot array of keys. |
| `m.values()` | Snapshot array of values. |
| `m.size()` | Number of entries. |
| `m.clear()` | Remove all entries. |

`update` is the right tool for compound mutations like increments, list appends, or conditional writes — the lock guarantees no other task observes a half-update. Don't do I/O inside `update`; the lock is held for the duration of `fn`.

The lock is `recursive`, so `fn` can call `m.has`/`m.get`/`m.set` on the same SharedMap without deadlocking.

### What happens if `fn` throws

The slot-level guarantee is "all or nothing": if `fn` throws, the SharedMap entry for `k` is **not** overwritten — the throw propagates out of `update` and the previous value (if any) remains.

But the value `fn` receives is the *same map/array/instance* the SharedMap is holding (Praia maps and arrays are reference types). If `fn` mutates that value in place before throwing, those partial mutations stick — the original is half-modified even though the slot wasn't reassigned:

```praia
m.set("k", {a: 1, b: 2})
try {
    m.update("k", lam{ s in
        s.a = 99       // mutates the shared map directly
        throw "oops"   // slot write is skipped, but s.a = 99 already happened
        return s
    })
} catch (e) {}
print(m.get("k"))   // {a: 99, b: 2} — half-modified
```

If you need transactional semantics, build the new value before mutating anything observable. Either return a fresh map from `fn` (so the input isn't touched) or wrap the body in `try`/`catch` and restore the snapshot yourself:

```praia
m.update("k", lam{ s in
    let next = {a: s.a, b: s.b}    // snapshot
    next.a = 99
    if (somethingBad) { throw "oops" }
    return next                    // only stored on success
})
```

## CancellationToken

`CancellationToken()` is a flag that any task can flip to "cancelled". Pass it to a long-running async task and have the task poll `cancelled()` periodically to bail out cleanly. This is the cooperative alternative to killing a task by signal: the task gets to clean up its own subprocess, files, etc.

```praia
let token = CancellationToken()

func work(tok) {
    let proc = sys.spawn(["ffmpeg", "-i", "in.mp4", "out.webm"])
    while (true) {
        if (tok.cancelled()) {
            proc.kill()
            return "cancelled"
        }
        let line = proc.readLine()
        if (line == nil) { break }
        // ...
    }
    proc.wait()
    return "done"
}

let f = async work(token)
// ... later, from any thread:
token.cancel()
print(await f)        // "cancelled"
```

| Method | Description |
|--------|-------------|
| `token.cancel()` | Set the cancelled flag. Idempotent. |
| `token.cancelled()` | Returns `true` if `cancel()` has been called. |
| `token.throwIfCancelled()` | Throws `"cancelled"` if cancelled, otherwise returns nil. Convenient for early-bail patterns inside loops. |

The flag is a `std::atomic<bool>` under the hood — `cancel()` and `cancelled()` are lock-free. Cancellation is a one-way transition; tokens cannot be un-cancelled. Make a fresh `CancellationToken()` per logical operation.

For tasks that block on I/O (e.g. `proc.readLine()`), check `cancelled()` between reads. The task only notices cancellation at poll points, so cancellation latency is bounded by the longest gap between checks. If you also need fast cancellation for a blocked subprocess, the task can call `proc.kill()` itself when `cancelled()` returns true.

## Queues

Queues are thread-safe FIFO queues for communication between async tasks.

```praia
let q = Queue()      // unbounded — send() never blocks (until closed)
let q = Queue(10)    // bounded — send() blocks while 10 items are pending
```

> **Renamed.** Previously `Channel()`. The name `Channel` still works as
> a deprecated alias and prints a one-line warning to stderr on first
> use; rename to `Queue` to silence it. Method names (`send`, `recv`,
> `tryRecv`, `close`, `isClosed`, `isEmpty`, `closed`) are unchanged.
>
> Not a rendezvous primitive: senders don't wait for a receiver to be
> ready. Use `Queue(N)` if you want backpressure.

| Method | Description |
|--------|-------------|
| `q.send(val)` | Send a value (blocks when bounded and full; never blocks when unbounded). |
| `q.recv()` | Receive a value (blocks until available, nil when closed + empty). |
| `q.tryRecv()` | Non-blocking receive (nil if empty). |
| `q.close()` | Close the queue (no more sends). |
| `q.isClosed()` | True once `close()` has been called. The "can I still send?" check for producers. |
| `q.isEmpty()` | True when the buffer has no pending values. The "is there anything to read?" check for consumers. |
| `q.closed()` | True when **closed AND drained** (= `isClosed() && isEmpty()`). The "is this queue done forever?" check for shutdown logic. |

> The three flags answer different questions. A producer wanting to bail out cleanly should consult `isClosed()` — `closed()` stays `false` until the buffer drains, so a producer checking it can race past a `close()` call and only see it once their own buffered values have already been consumed.

### Producer-consumer

```praia
let q = Queue()

func producer(q) {
    for (i in 0..5) {
        q.send(i)
    }
    q.close()
}

async producer(q)

while (true) {
    let val = q.recv()
    if (val == nil) { break }
    print(val)
}
```

### Fan-out: multiple workers

```praia
let results = Queue()

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

`Lock()` is a mutex for serializing concurrent access to **external resources** — files, sqlite handles, sockets, native plugin state. It does not, and cannot, make a Praia value shared across tasks; for that, use a Queue.

```praia
let lock = Lock()
let db = sqlite.open("counts.db")

func increment() {
    lock.withLock(lam{ in
        let row = db.query("SELECT n FROM c WHERE id = 1")
        db.run("UPDATE c SET n = ? WHERE id = 1", [row[0].n + 1])
    })
}

let f1 = async increment()
let f2 = async increment()
await f1
await f2
// db is shared; lock prevents the two reads/writes from racing
```

| Method | Description |
|--------|-------------|
| `lock.acquire()` | Acquire the lock (blocks if held) |
| `lock.release()` | Release the lock |
| `lock.withLock(fn)` | Acquire, call fn, release -- even if fn throws. Returns fn's return value. |

**Always prefer `withLock`** -- it handles errors correctly and cannot forget to release.

The lock is re-entrant: the same thread can acquire it multiple times without deadlocking.

### What happens if `fn` throws

`withLock` releases the mutex on throw — so the next caller can enter the critical section. It does **not** roll back any state `fn` mutated before throwing. If you're guarding compound state that needs to be all-or-nothing on failure, build the new state locally inside `fn` and only commit it (assign to the shared variable, write to the file, etc.) on the last line, after everything that could throw:

```praia
lock.withLock(lam{ in
    let staged = computeNextState()   // may throw — nothing committed yet
    db.run("UPDATE ...", [staged])    // commit
})
```

## HTTP server concurrency

The HTTP server is **single-threaded** -- handlers run serially. `async` inside a handler is still useful for fire-and-forget background work or for parallelising I/O with `await`; just remember the cross-task isolation rules above.

If a handler needs to communicate progress back to a *later* request (e.g. polling `/progress/:id` while a conversion runs in the background), don't try to share a Praia map. Two practical options:

```praia
// 1. Queue-driven: a long-running pump goroutine drains updates
let updates = Queue(100)
let _job = async runConversion(jobId, updates)
// the handler for /progress/:id reads from a per-job state file or sqlite
// row that the background task wrote — channels are FIFO so they don't
// fit "look up by id"

// 2. Disk- or db-backed job state
let _job = async runConversion(jobId)   // task writes to _jobs/<jobId>.json
// /progress/:id reads _jobs/<jobId>.json
```

For app-level body limits use `middleware.bodyLimit(n)`; for DoS protection put a reverse proxy (nginx, caddy) in front.
