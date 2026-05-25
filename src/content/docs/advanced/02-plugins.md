---
title: Native Plugins
sidebar:
  order: 2
---

Praia can load native C++ modules at runtime via `loadNative()`. This lets you write performance-critical code or wrap C/C++ libraries.

## Scaffolding with Sand

The fastest way to start a plugin project is with the `sand` package manager:

```sh
sand init --plugin
```

This creates a ready-to-go grain with:
- `grain.yaml` — package manifest
- `main.praia` — entry point that loads the compiled plugin
- `plugins/yourname.cpp` — C++ plugin template with the entry point stubbed out
- `Makefile` — builds the plugin for macOS (`.dylib`) or Linux (`.so`)

Build and test:

```sh
make
praia main.praia
```

From there, add your native functions to the `.cpp` file and export them in `main.praia`.

## Manual setup

If you prefer to set things up by hand:

**1. Write a plugin** (`mymodule.cpp`):

```cpp
#include "praia_plugin.h"

PRAIA_DECLARE_ABI();

extern "C" void praia_register(PraiaMap* module) {
    module->entries["double"] = Value(makeNative("mymodule.double", 1,
        [](const std::vector<Value>& args) -> Value {
            if (!args[0].isNumber())
                throw RuntimeError("expected a number", 0);
            return Value(args[0].asNumber() * 2);
        }));
}
```

`PRAIA_DECLARE_ABI()` is required -- see [ABI versioning](#abi-versioning) below.

**2. Build it:**

```sh
make plugin SRC=mymodule.cpp OUT=mymodule.dylib   # macOS
make plugin SRC=mymodule.cpp OUT=mymodule.so       # Linux
```

**3. Use it in Praia:**

```praia
let mod = loadNative("./mymodule")
print(mod.double(21))  // 42
```

## ABI versioning

The plugin API is versioned. Every plugin must invoke `PRAIA_DECLARE_ABI()` once at file scope:

```cpp
#include "praia_plugin.h"

PRAIA_DECLARE_ABI();

// ... your praia_register etc.
```

`loadNative()` checks the declared version against the running praia binary's compiled-in version and refuses plugins that don't match -- with a clear "rebuild the plugin against the current headers" error rather than crashing later from a layout mismatch. Plugins that omit `PRAIA_DECLARE_ABI()` are refused for the same reason.

When the ABI changes (e.g. `Value`'s variant layout or `PraiaMap`'s key type), the version bumps. Existing plugins continue working at the older praia release; rebuilding picks up the new version automatically.

## Plugin metadata

Optional. Declare a `name`, `version`, and `description` once at file scope:

```cpp
#include "praia_plugin.h"

PRAIA_DECLARE_ABI();
PRAIA_PLUGIN_METADATA("mymod", "1.2.0", "Does the thing");
```

`loadNative()` exposes the values under a `_meta` key on the returned module map, so user code can do:

```praia
let mod = loadNative("./mymod")
print(mod._meta.name, mod._meta.version)
```

Plugins that don't declare metadata get no `_meta` key -- backward-compatible and opt-in. The underscore prefix keeps it from colliding with normal module functions.

## Opaque handles

For plugins wrapping a C/C++ resource -- a DB connection, a file handle, an OS object -- return a `praia::makeExternal<T>(ptr, typeName, deleter)` Value instead of squeezing the pointer into a map or string. The Value:

- Holds the opaque pointer + a destructor that fires when the last reference drops (during the GC sweep).
- Carries a `typeName` tag so the plugin can type-check on unwrap (`praia::getExternal<T>(value, typeName)`).
- Prints as `<external:typeName>` and compares by pointer identity.
- Can be passed through arrays, maps, function calls -- but isn't hashable (can't be a map key).

### Example: wrapping a SQLite connection

The handle wraps `sqlite3*` in a small struct alongside a `closed` flag, so explicit `db.close(conn)` and the GC-time deleter are both idempotent -- running close twice (or close-then-GC) doesn't double-free.

The in-tree [`sqlite` builtin](/advanced/sqlite/) and [HTTP session](/stdlib/http/#sessions----httpsession) handle both follow this exact pattern -- they're the in-tree reference implementations of `makeExternal` on top of real C resources (a `sqlite3*` and a pool of TCP/TLS sockets, respectively).

```cpp
#include "praia_plugin.h"
#include <sqlite3.h>

PRAIA_DECLARE_ABI();

namespace {
struct sqlite3_wrapper {
    sqlite3* conn = nullptr;
    bool closed = false;
};
}

extern "C" void praia_register(PraiaMap* module) {
    module->entries["open"] = Value(makeNative("db.open", 1,
        [](const std::vector<Value>& args) -> Value {
            auto& path = praia::requireString(args, 0, "db.open");
            auto* w = new sqlite3_wrapper;
            if (sqlite3_open(path.c_str(), &w->conn) != SQLITE_OK) {
                // sqlite3_open can leave conn as NULL on OOM in
                // older SQLite builds -- guard before reading the
                // error message or calling close on it.
                std::string msg = w->conn ? sqlite3_errmsg(w->conn)
                                          : "out of memory";
                if (w->conn) sqlite3_close_v2(w->conn);
                delete w;
                praia::error("db.open: " + msg);
            }
            return praia::makeExternal<sqlite3_wrapper>(w, "sqlite3.connection",
                [](sqlite3_wrapper* p) {
                    if (!p->closed) sqlite3_close_v2(p->conn);
                    delete p;
                });
        }));

    module->entries["close"] = Value(makeNative("db.close", 1,
        [](const std::vector<Value>& args) -> Value {
            auto* w = praia::getExternal<sqlite3_wrapper>(args[0], "sqlite3.connection");
            if (w->closed) return Value();
            // sqlite3_close_v2 (vs the v1 close) defers actual
            // cleanup until any outstanding prepared statements
            // and blob handles are finalized, rather than
            // returning SQLITE_BUSY -- so we can mark `closed`
            // unconditionally and SQLite handles the rest.
            sqlite3_close_v2(w->conn);
            w->closed = true;
            return Value();
        }));
}
```

User code:

```praia
let db = loadNative("./mydb")
let conn = db.open(":memory:")
// ... use conn ...
// when `conn` goes out of scope (or is reassigned), sqlite3_close runs.
```

### TypeName convention

Use `"module.type"` -- e.g. `"sqlite.connection"`, `"prscan.scanner"`. The string isn't accessible via any Praia-side API or field, but it IS visible in string form: `str(handle)` and `print(handle)` show `<external:typeName>`. Treat it as a diagnostic-only label from Praia's perspective, and as the plugin's internal type tag from C++. Two different plugins using the same `typeName` for unrelated handles will accept each other's handles in `getExternal<T>` -- choose a prefix that's unlikely to collide.

### Lifetime

The deleter runs in `PraiaExternal::~PraiaExternal()` when the last `shared_ptr<PraiaExternal>` drops:

- Reassigning the last user-code variable: deleter runs immediately (refcount drop).
- Going out of scope: same.
- Held in a map / closed-over by a callable: stays alive until the container is itself dropped or GC-swept.

If your wrapped resource holds back-references into Praia (e.g. a callback registered with a C library), don't let the C side outlive the handle -- the deleter is your last chance to unregister.

### What user code sees

A Value that prints as `<external:typeName>`, passes through assignments / function calls / arrays / maps unchanged, and can't be used as a map key (the underlying pointer isn't hashable). The typeName isn't accessible via any API or field -- but it IS visible in string form (`str(h)`, `print(h)`, REPL output) as part of the `<external:...>` rendering. Treat that string output as a diagnostic label, not a stable contract; for type checks, use `praia::getExternal<T>` on the C++ side.

## GC roots: stashing Values across native calls

If your plugin stashes a Praia `Value` in C++ static / global storage that outlives the native function call -- a callback table, a cache, a singleton -- you **must** pin it as a GC root. Otherwise the next garbage collection treats the value as unreachable and the sweep hollows out the underlying object's internal references. The `shared_ptr` you held stays valid, but the object is empty: a stashed `Callable` finds an empty closure environment, a cached `PraiaMap` finds its entries cleared.

`praia::pinValue` registers the value with the current thread's `GcHeap` so the mark phase visits it on every collection. Reference-counted by multiplicity: pin N times means N unpins to release. The matching uses last-in-first-out, so nested RAII pin/unpin pairs work without bookkeeping.

```cpp
#include "praia_plugin.h"
#include <unordered_map>

namespace {
std::unordered_map<std::string, Value> g_callbacks;
}

extern "C" void praia_register(PraiaMap* module) {
    module->entries["on"] = Value(makeNative("mod.on", 2,
        [](const std::vector<Value>& args) -> Value {
            auto& name = praia::requireString(args, 0, "mod.on");
            praia::requireCallable(args, 1, "mod.on");   // validate type
            // Release the old pin BEFORE overwriting the map slot --
            // otherwise the old value leaks a pin forever.
            auto it = g_callbacks.find(name);
            if (it != g_callbacks.end()) praia::unpinValue(it->second);
            praia::pinValue(args[1]);
            g_callbacks[name] = args[1];
            return Value();
        }));

    module->entries["fire"] = Value(makeNative("mod.fire", 1,
        [](const std::vector<Value>& args) -> Value {
            auto& name = praia::requireString(args, 0, "mod.fire");
            auto it = g_callbacks.find(name);
            if (it == g_callbacks.end()) return Value();
            // Safe to call: the pin kept the callable's closure
            // environment alive across however many GC sweeps fired
            // between `mod.on(...)` and now.
            return praia::call(it->second.asCallable(), {});
        }));
}
```

### When you need this

| Storage shape | Pin needed? |
|---|---|
| Local `Value` / `Value` argument in a non-reentrant native call | No. The C++ stack frame keeps the `shared_ptr` alive, and nothing else runs between native entry and return to trigger a sweep. |
| Local `Value` / argument across a `praia::call` callback, async yield, or any other reentrant path | **Yes.** Re-entering the interpreter can run a GC sweep on this thread; the C++ stack pins the `shared_ptr` but the sweep can still clear the object's *internal* references. |
| `Value` stashed in C++ static / global between calls | **Yes.** |
| `Value` inside a `PraiaExternal`'s opaque data | **Yes, if the stored Value is GC-tracked.** The external itself is GC-tracked, but its `data` field is just `void*` -- the GC doesn't know to walk inside. Pin any Praia Values you store there. |

The rule in one sentence: **a local `Value` is safe without a pin only while no Praia code can run on this thread**. The moment you call back into the interpreter -- directly via `praia::call`, indirectly via anything that allocates Praia objects, or across an async yield -- a sweep can fire and the value's internals are exposed.

### When you don't

Values that aren't GC-tracked (numbers, strings, bools, nil) accept `pinValue` harmlessly -- the registry adds the entry, the mark phase no-ops on the unwrappable type, and the sweep can't break anything anyway. There's no need to type-check before pinning.

### Scope guard (RAII)

For short-lived holds inside a native function -- e.g. saving an argument across a `praia::call` that recursively triggers GC -- use `PinnedValue`. Move-only; pin on construction, unpin on destruction.

```cpp
module->entries["recurseSafely"] = Value(makeNative("mod.recurseSafely", 2,
    [](const std::vector<Value>& args) -> Value {
        praia::PinnedValue keepAlive(args[0]);   // pin until scope exit
        praia::call(args[1].asCallable(), {});
        return keepAlive.get();
    }));
```

### Common bugs

- **Replace-without-unpin.** Storing a new value in a slot you already pinned without unpinning the old one leaks a pin every time. The old value stays a root forever; eventually the registry walks slow as it grows.
- **Unpin-without-pin.** `praia::unpinValue(v)` is silent on a missing match -- won't crash, but also won't tell you the bookkeeping is off.
- **Pinning the wrong thread's heap.** Each thread has its own `GcHeap`. Pin in the thread that holds the C++ storage. If your plugin spans threads, pin per-thread or pin only on the owning thread.

## Plugin API

### Entry point

Every plugin exports a single C function:

```cpp
extern "C" void praia_register(PraiaMap* module);
```

This receives an empty `PraiaMap`. Populate its `entries` with native functions.

### Creating functions

Use `makeNative(name, arity, fn)`:

```cpp
module->entries["add"] = Value(makeNative("mymod.add", 2,
    [](const std::vector<Value>& args) -> Value {
        return Value(args[0].asNumber() + args[1].asNumber());
    }));
```

- `name` -- display name for error messages
- `arity` -- number of parameters, or `-1` for variadic
- `fn` -- `std::function<Value(const std::vector<Value>&)>`
- `paramNames` (optional) -- vector of parameter names. Pass it to let user code call your function with named arguments:

  ```cpp
  module->entries["add"] = Value(makeNative("mymod.add", 2,
      [](const std::vector<Value>& args) -> Value {
          return Value(args[0].asNumber() + args[1].asNumber());
      },
      {"x", "y"}));
  ```

  Praia code can then write `mod.add(x: 1, y: 2)` or `mod.add(y: 2, x: 1)`. Without `paramNames`, named-arg calls throw the standard "Named arguments not supported" error.

### Argument validation

`praia_plugin.h` exports inline helpers in the `praia` namespace for the standard type/arity checks. They throw `RuntimeError` with the canonical wording the engine's own builtins use:

```cpp
module->entries["substring"] = Value(makeNative("mymod.substring", 3,
    [](const std::vector<Value>& args) -> Value {
        auto& s = praia::requireString(args, 0, "mymod.substring");
        int64_t start = praia::requireInt(args, 1, "mymod.substring");
        int64_t end   = praia::requireInt(args, 2, "mymod.substring");
        return Value(s.substr(start, end - start));
    }));
```

- `requireString(args, i, "fn")` -> `"fn() argument N must be a string"` (N is 1-based)
- `requireInt`, `requireNumber`, `requireBool`, `requireArray`, `requireMap`, `requireCallable` -- same shape, different type word
- `requireArity(args, n, "fn")` -- enforces exact arg count
- `requireArityRange(args, lo, hi, "fn")` -- enforces a range (for variadics)
- `praia::error("msg")` -- bare shorthand for `throw RuntimeError("msg", 0);` for cases the helpers don't cover

`requireInt` is strict (rejects float values that happen to be whole numbers); use `requireNumber` when either form is acceptable. Matches the `asInt`/`asNumber` distinction in the [Value type](#the-value-type) pitfall callout below.

### The Value type

| Constructor | Praia type |
|------------|------------|
| `Value()` or `Value(nullptr)` | nil |
| `Value(true)` | bool |
| `Value(42)` | int |
| `Value(3.14)` | float |
| `Value(std::string("hi"))` or `Value("hi")` | string |
| `Value(shared_ptr<PraiaArray>)` | array |
| `Value(shared_ptr<PraiaMap>)` | map |
| `Value(shared_ptr<PraiaSet>)` | set |
| `Value(shared_ptr<Callable>)` | function |

Type checking and accessors:

```cpp
args[0].isString()    // type check
args[0].asString()    // const std::string&
args[0].isNumber()    // true for int or float
args[0].asNumber()    // double (converts int)
args[0].isInt()       // true only for int
args[0].asInt()       // int64_t -- only safe after isInt()
args[0].isArray()     // true for array
args[0].asArray()     // shared_ptr<PraiaArray>
args[0].isMap()       // true for map
args[0].asMap()       // shared_ptr<PraiaMap>
args[0].isCallable()  // true for function/lambda
args[0].asCallable()  // shared_ptr<Callable>
```

> **Pitfall.** `asInt()` is *only* safe after `isInt()` (`std::get` throws `bad_variant_access` on a double-holding Value). If you guard with `isNumber()` instead, use `asNumber()` -- it returns a double and converts ints transparently.

> **`std::string` doubles as Praia's bytes type.** Praia uses a single string type for both text and binary data, like Python's bytes objects. Plugins wrapping binary protocols can put raw bytes (including embedded NULs) into `Value(std::string)`; they round-trip through `asString()` byte-for-byte. Don't reach for `std::vector<uint8_t>` or invent a Bytes wrapper -- the existing string accessors handle it.

### Creating arrays and maps

Use `gcNew<T>()` to create GC-tracked containers:

```cpp
auto arr = gcNew<PraiaArray>();
arr->elements.push_back(Value(1));
arr->elements.push_back(Value(2));
return Value(arr);

auto map = gcNew<PraiaMap>();
map->entries["key"] = Value("value");
return Value(map);
```

Always use `gcNew` instead of `std::make_shared` -- it registers the object with Praia's garbage collector.

### Calling Praia code back

When your plugin accepts a `Callable` argument (a user-provided lambda or function), invoke it through `praia::call`:

```cpp
#include "praia_plugin.h"

extern "C" void praia_register(PraiaMap* module) {
    // filter(array, predicate) -- keep elements where predicate(x) is truthy
    module->entries["filter"] = Value(makeNative("mymod.filter", 2,
        [](const std::vector<Value>& args) -> Value {
            auto pred = args[1].asCallable();
            auto out = gcNew<PraiaArray>();
            for (auto& elem : args[0].asArray()->elements) {
                Value keep = praia::call(pred, {elem});
                if (keep.isTruthy()) out->elements.push_back(elem);
            }
            return Value(out);
        }));
}
```

`praia::call` works for both Praia engines (the tree-walker and the bytecode VM) -- your plugin doesn't need to know which one is running.

**Pitfall -- deferred invocation.** Callbacks must be invoked synchronously from the same plugin call that received them. If you stash a callable and invoke it later from a worker thread, a libuv-style scheduler, or any other off-engine context, `praia::call` will throw with "no active Praia executor on this thread". Stack-based VMs and tracing GCs can't safely have user code called on threads they didn't sanction. Use `praia::postToEngine` (next section) to marshal the call back to the engine.

### Calling back from background threads -- `praia::postToEngine`

`praia::postToEngine` is the supported path for plugins that genuinely do background work (libuv-style I/O, `std::thread` workers, native event loops) and need to fire Praia callbacks when the work finishes.

```cpp
void praia::postToEngine(void* engine,
                         std::shared_ptr<Callable> fn,
                         std::vector<Value> args);
```

The `engine` token is captured on the engine thread via `praia::currentExecutor()`. From any thread -- even ones that have no Praia executor of their own -- call `postToEngine` to enqueue `fn(args)` for execution on the engine's next yield point.

```cpp
#include "praia_plugin.h"
#include <chrono>
#include <thread>

extern "C" void praia_register(PraiaMap* module) {
    module->entries["scheduleAfter"] = Value(makeNative("mod.scheduleAfter", 2,
        [](const std::vector<Value>& args) -> Value {
            int  ms = (int)praia::requireNumber(args, 0, "mod.scheduleAfter");
            auto cb = praia::requireCallable(args, 1, "mod.scheduleAfter");

            // Pin the callable so the engine's GC doesn't collect its
            // closure environment while the worker is sleeping. Pin
            // runs on the engine thread; the worker can't pin from
            // its own thread (no executor there).
            praia::pinValue(args[1]);

            void* engine = praia::currentExecutor();   // capture HERE

            std::thread([engine, cb, ms]() {
                std::this_thread::sleep_for(std::chrono::milliseconds(ms));
                praia::postToEngine(engine, cb, {});
                // The matching unpin must run on the engine thread —
                // typically the callback unpins itself at the end of
                // its body (see the in-tree counter plugin's test
                // harness for the pattern).
            }).detach();

            return Value();
        }));
}
```

#### When the post fires

The engine drains its post queue at every yield point:

- **Tree-walker:** before every statement and expression.
- **Bytecode VM:** every ~1024 bytecode ops (same boundary as GC + SIGINT checks).

Latency is microseconds for realistic workloads.

#### Lifetime and shutdown

The plugin is responsible for ensuring the engine outlives any pending posts. Workers should be joined or otherwise drained in the plugin's teardown; posting to an engine that's already been destroyed is undefined behavior.

#### Fire-and-forget

`postToEngine` has no return value. Callback exceptions are caught by the drain loop and logged to stderr (`[praia::postToEngine] callback raised: <message>`); a bad callback can't poison the queue, but the caller can't observe success directly. For result-passing, capture a Praia `Queue` or shared map in the callback's closure.

#### What can go wrong synchronously

`postToEngine` itself only fails in one way: passing a null `engine` token throws `RuntimeError`. On a detached worker there's no enclosing handler, so an uncaught throw aborts via `std::terminate`. Capture the token *before* spawning the worker (`praia::currentExecutor()` can return null if the plugin is loaded from an unusual context), and consider guarding against `engine == nullptr` if your plugin's call graph allows it.

#### Why workers can't call praia::call or praia::pinValue

Both helpers begin with `if (!currentExecutor()) throw`. On a worker thread, `currentExecutor()` is null because no engine has bound its thread-local for that thread. `postToEngine` is the only API safe to call from such threads -- it carries the engine token explicitly so the queue knows which engine to wake.

### Cooperating with cancellation -- `praia::shouldCancel`

Praia user code can poll `tok.cancelled()` between statements to bail out of a long-running task, but once execution enters a compute-heavy native (a multi-MB regex, a numeric optimizer, a streaming parse) it stays there until the native returns. `praia::shouldCancel()` lets the native cooperate.

```cpp
std::optional<bool> praia::shouldCancel();
```

Returns one of three values:

- `std::nullopt` -- no cancellation token is bound on the calling thread. Treat as "no cancellation requested" and run to completion. This is the default outside an active `withCancel(token, fn)` scope.
- `false` -- a token is bound but hasn't been cancelled. Keep working; check again next iteration.
- `true` -- a token is bound and has been cancelled. Bail out -- return a partial result, throw `RuntimeError`, or whatever the surrounding API expects.

The Praia side uses the helper `withCancel(token, fn, ...args)` to push a token onto the thread-local for the duration of `fn`. It composes with `async` without any change to async's signature:

```praia
let tok = CancellationToken()
async lam{ in
    withCancel(tok, lam{ in
        myplugin.heavyCompute(input)
    })
}()
// elsewhere on the main thread, when the user clicks Cancel:
tok.cancel()
```

In the native:

```cpp
module->entries["heavyCompute"] = Value(makeNative("myplugin.heavyCompute", 1,
    [](const std::vector<Value>& args) -> Value {
        auto input = praia::requireString(args, 0, "myplugin.heavyCompute");
        int64_t done = 0;
        for (size_t i = 0; i < input.size(); i++) {
            // Amortise the poll across ~4096 iterations -- the atomic
            // load is cheap (~1ns), but a hot inner loop notices.
            if ((i & 0xfff) == 0) {
                auto c = praia::shouldCancel();
                if (c && *c) break;  // partial result is fine
            }
            done = work_on(input[i], done);
        }
        return Value(done);
    }));
```

Implementation is a thread-local pointer read plus, if non-null, one atomic acquire load -- safe to call from the inner loop of a tight compute loop. The polling interval is your call; `4096` matches the GC throttle the VM uses internally and gives sub-millisecond cancellation latency on typical CPU work.

**Worker threads start with no token bound.** A `std::thread` you spawn with `postToEngine` won't inherit the engine thread's `withCancel` scope; `shouldCancel()` returns `nullopt` on that worker. If you need the worker to cooperate with cancellation, capture the `CancellationToken` value yourself (pin it via `praia::pinValue`) and poll `token.cancelled()` from the worker.

### Returning a Future -- `praia::Promise`

`postToEngine` is fire-and-forget -- the worker delivers a result but the original native call has already returned. For the natural async shape, where the native call returns a Future and user code `await`s it,  use `praia::Promise`:

```cpp
class praia::Promise {
public:
    Promise();                                  // fresh promise + linked future
    Value future() const;                       // the Value to hand to user code
    void resolve(Value result) noexcept;        // fulfil with a value
    void reject(const std::string& msg) noexcept;  // fail with a message
};
```

Returns a Future Value the caller can `await`. The plugin's worker fulfils the Promise from any thread; the await rendezvous handles the cross-thread synchronisation under the hood (it's a `std::shared_future` internally).

```cpp
module->entries["fetch"] = Value(makeNative("myplugin.fetch", 1,
    [](const std::vector<Value>& args) -> Value {
        auto url = praia::requireString(args, 0, "myplugin.fetch");

        praia::Promise promise;
        Value fut = promise.future();

        // Promise is shared_ptr-backed; copies all refer to the same
        // state, so capture by value freely.
        std::thread([promise, url]() mutable {
            try {
                std::string body = blockingHttpGet(url);
                promise.resolve(Value(std::move(body)));
            } catch (const std::exception& e) {
                promise.reject(std::string("fetch failed: ") + e.what());
            }
        }).detach();

        return fut;
    }));
```

User code:

```praia
let body = await myplugin.fetch("https://example.com")
```

**Fulfilment.** `resolve` and `reject` are `noexcept` and safe from any thread. The first call wins via an atomic CAS; subsequent calls (or a `reject` after a `resolve`, etc.) are silent no-ops. This matches JavaScript Promise semantics -- "first to land takes the slot, the rest are ignored" -- which is what you want when a timeout and a completion are racing to fulfil the same Promise.

**The dropped-without-fulfilment case.** If the last `Promise` reference drops before `resolve` or `reject` is called, the linked Future is rejected with the RuntimeError `"plugin Promise was dropped before resolve or reject"`. Awaiting code sees that as a normal catchable error. No silent hangs. This catches "worker thread exited via an early return" bugs at runtime.

**`reject` round-trips your message.** Praia's `await` rethrows `RuntimeError` unchanged, so a `promise.reject("io error: timeout")` becomes a catchable RuntimeError carrying `"io error: timeout"` verbatim -- no wrapping prefix.

**GC contract for `resolve(Value)`.** Praia's Future is not traced by the GC; a Value sitting between `resolve` and `await` is invisible to the collector. For **non-GC values** (numbers, strings, bools, nil) this doesn't matter -- they have no interior the sweep could hollow. Most plugins resolve with these and never hit the rest of this paragraph. For **GC-tracked values** (Map, Array, Instance, Callable) the plugin must keep the value pinned via `praia::pinValue` while it's in transit between resolve and await. The canonical pattern is the same pin-on-engine / unpin-on-engine wrapper `postToEngine` plugins use (see `examples/plugins/counter.cpp::scheduleAsync` for a worked example); the `resolve` from the worker then operates on a pre-pinned value, and a small unpin wrapper posted back to the engine releases the pin after the await consumes it.

### Process-exit cleanup -- `praia_at_exit`

Plugins that own OS resources past the lifetime of any one native call -- log files, sockets, write-behind buffers, file locks, named shared memory -- may export an optional teardown hook:

```cpp
extern "C" void praia_at_exit(void) {
    g_logFile.flush();
    g_logFile.close();
    g_worker.signal_stop();
    g_worker.join();
}
```

No macro is needed; `loadNative` dlsyms for the symbol and registers it if present. The hook runs once, on the main thread, after `main()` returns or unwinds through `sys.exit()`, in **LIFO** order across plugins (so plugins loaded later tear down first, mirroring how layered dependencies want to be released).

**Don't call into Praia from the hook.** By the time it runs, both engines have either been torn down or are about to be. `praia::call`, `praia::postToEngine`, and `praia::pinValue` are all unsafe here -- a stashed `Value` is no longer guaranteed to be invocable. The hook's job is C++-side cleanup only: close file descriptors, flush buffers, signal-and-join worker threads, free OS-owned memory if you have any.

**Worker threads.** The hook is a deadline, not a coordination point. If the plugin spawned long-running worker threads via `std::thread`, the hook is where you signal them to stop *and* `.join()` them before returning. Don't leave a thread running past the hook -- the process is about to exit and any work it does will race against C++ runtime teardown.

**Skipped paths.** The hook is best-effort. It does **not** run on `_Exit`, `abort`, `std::terminate` (uncaught exception), or a fatal signal that bypasses praia's handlers. Don't rely on it for correctness -- if durability matters, `fsync` as you write rather than at exit.

**Errors are swallowed.** An exception escaping the hook is caught, logged to stderr (`[praia_at_exit] <plugin path>: <message>`), and the next plugin's hook still runs.

### Error handling

Throw `RuntimeError` to report errors:

```cpp
if (!args[0].isString())
    throw RuntimeError("myFunc() requires a string", 0);
```

## Building

The Makefile provides a convenience target:

```sh
make plugin SRC=path/to/plugin.cpp OUT=path/to/plugin.dylib
```

Or build manually using `praia --include-path` to find the headers. Match the flags from the Makefile target -- `_XOPEN_SOURCE=600` is required on macOS (otherwise `fiber.h`'s transitive `<ucontext.h>` include errors), and the deprecated-declarations warning silences a noisy ucontext deprecation Apple ships:

```sh
# macOS
g++ -std=c++20 -Wno-deprecated-declarations \
    -D_XOPEN_SOURCE=600 -D_DARWIN_C_SOURCE \
    -shared -fPIC -I$(praia --include-path) \
    -undefined dynamic_lookup \
    -o myplugin.dylib myplugin.cpp

# Linux
g++ -std=c++20 -Wno-deprecated-declarations \
    -D_XOPEN_SOURCE=600 \
    -shared -fPIC -I$(praia --include-path) \
    -o myplugin.so myplugin.cpp
```

## Header

Include a single header:

```cpp
#include "praia_plugin.h"
```

This re-exports: `value.h` (Value, PraiaArray, PraiaMap, PraiaSet, Callable, RuntimeError), `gc_heap.h` (gcNew), `builtins.h` (makeNative), `praia_runtime.h` (the `praia::call` callback helper).

## Behavior

- **Extension auto-detection** -- `loadNative("./mymod")` tries `.dylib` on macOS, `.so` on Linux
- **Caching** -- loading the same path twice returns the cached module
- **Lifetime** -- plugins are never unloaded; function pointers remain valid
- **GC integration** -- containers created with `gcNew` participate in Praia's GC

### Thread safety

Plugin code can be called from one of three contexts. Pick the one that matches what your plugin does:

- **Synchronous calls.** Most plugins. Praia invokes your native function on its own thread; `gcNew` works as expected, `praia::call` works for callbacks, the GC sees your containers normally.
- **Inside an `async` task.** Praia ships your function to a worker thread for the task's lifetime, with the GC disabled while the task runs. You can still use `gcNew` for short-lived intermediate containers, but **don't let a `gcNew`-built object escape the task scope** -- it isn't tracked by the parent's GC. Either return primitives, deep-copy outside the plugin, or marshal the work back to the parent. See the [async/Lock guide](/docs/advanced/async) for the matching pattern on the Praia side.
- **Off-engine threads (e.g. libuv callback, your own `std::thread`).** Both `gcNew` and `praia::call` are unsafe. Marshal back to a Praia-driven thread before touching either.
