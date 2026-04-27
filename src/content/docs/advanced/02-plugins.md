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

extern "C" void praia_register(PraiaMap* module) {
    module->entries["double"] = Value(makeNative("mymodule.double", 1,
        [](const std::vector<Value>& args) -> Value {
            if (!args[0].isNumber())
                throw RuntimeError("expected a number", 0);
            return Value(args[0].asInt() * 2);
        }));
}
```

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

### The Value type

| Constructor | Praia type |
|------------|------------|
| `Value()` | nil |
| `Value(true)` | bool |
| `Value(int64_t(42))` | int |
| `Value(3.14)` | float |
| `Value(std::string("hi"))` | string |
| `Value(shared_ptr<PraiaArray>)` | array |
| `Value(shared_ptr<PraiaMap>)` | map |

Type checking and accessors:

```cpp
args[0].isString()    // type check
args[0].asString()    // const std::string&
args[0].isNumber()    // true for int or float
args[0].asNumber()    // double (converts int)
args[0].isInt()       // true only for int
args[0].asInt()       // int64_t
args[0].isArray()     // true for array
args[0].asArray()     // shared_ptr<PraiaArray>
args[0].isMap()       // true for map
args[0].asMap()       // shared_ptr<PraiaMap>
```

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

Or build manually:

```sh
# macOS
g++ -std=c++17 -shared -fPIC -I$(praia --include-path) -undefined dynamic_lookup -o myplugin.dylib myplugin.cpp

# Linux
g++ -std=c++17 -shared -fPIC -I$(praia --include-path) -o myplugin.so myplugin.cpp
```

## Header

Include a single header:

```cpp
#include "praia_plugin.h"
```

This re-exports: `value.h` (Value, PraiaArray, PraiaMap, RuntimeError), `gc_heap.h` (gcNew), `builtins.h` (makeNative).

## Behavior

- **Extension auto-detection** -- `loadNative("./mymod")` tries `.dylib` on macOS, `.so` on Linux
- **Caching** -- loading the same path twice returns the cached module
- **Lifetime** -- plugins are never unloaded; function pointers remain valid
- **GC integration** -- containers created with `gcNew` participate in Praia's GC
- **Thread safety** -- plugin code runs on the interpreter's thread
