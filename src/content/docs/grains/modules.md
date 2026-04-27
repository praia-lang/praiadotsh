---
title: Module System
sidebar:
  order: 1
---

Praia's module system uses **grains** (like sand grains). A grain can be a single `.praia` file or a directory with multiple files.

## Creating a grain

The quickest way to start a grain project is with `sand init`:

```sh
mkdir mygrain && cd mygrain
sand init
```

This creates a `grain.yaml` manifest and a `main.praia` entry file. For grains that include a native C++ plugin, use `sand init --plugin` instead (see [Native Plugins](/advanced/02-plugins/)).

You can also create a grain manually. A grain is any `.praia` file that ends with an `export` statement:

```praia
// grains/math.praia
let PI = 3.14159

func square(x) { return x * x }
func cube(x) { return x * x * x }

export { PI, square, cube }
```

## Importing a grain

Use `use` to import. The grain is bound to a variable named after the last path segment:

```praia
use "math"

print(math.PI)          // 3.14159
print(math.square(5))   // 25
```

### Custom alias

Use `as` to bind to a different name:

```praia
use "logger" as log
use "collections" as col

let l = log.create("App")
```

This is required for grain names with hyphens:

```praia
use "my-grain" as myGrain
myGrain.doSomething()
```

### Relative imports

Paths starting with `./` or `../` are resolved relative to the importing file:

```praia
use "./helpers/greeter"
greeter.hello("world")
```

## Multi-file grains

A grain can be a directory with a `grain.yaml` manifest:

```
ext_grains/
  mylib/
    grain.yaml        <- specifies entry point
    main.praia        <- main file
    helpers.praia     <- internal module
```

The `grain.yaml` specifies the entry file:

```yaml
name: mylib
version: 0.1.0
main: main.praia
```

Files within a grain directory can import each other with relative paths:

```praia
// ext_grains/mylib/main.praia
use "./helpers"

func process(x) { return helpers.double(x) }
export { process }
```

## Resolution order

When you write `use "math"`, Praia looks for the grain in this order:

1. **`ext_grains/`** -- local dependencies (installed by [sand](/grains/sand/)), walks up from the current file
2. **`grains/`** -- project-bundled grains, walks up from the current file
3. **`~/.praia/ext_grains/`** -- user-global grains (`sand --global`)
4. **`<libdir>/ext_grains/`** -- system-global grains (`sudo sand --global`)

At each location, Praia checks for:
- `<name>.praia` (single-file grain)
- `<name>/` directory with `grain.yaml` (reads `main` field for entry file)
- `<name>/main.praia` (fallback if no `grain.yaml`)

## Rules

- **No duplicate imports** -- importing the same grain twice in one file is an error
- **Grains run once** -- if multiple files import the same grain, it is only executed the first time; subsequent imports get the cached exports
- **Isolated scope** -- grains cannot access the importer's variables; they only see globals and their own definitions
- **Explicit exports** -- only names listed in `export { ... }` are visible to the importer

```praia
use "math"
use "math"      // Error: Grain 'math' is already imported in this file
```

## Grains importing other grains

Grains can import other grains:

```praia
// grains/geometry.praia
use "math"

func circleArea(r) {
    return math.PI * math.square(r)
}

export { circleArea }
```

## Project structure

A typical Praia project:

```
my-project/
├── ext_grains/              <- installed by sand
│   └── router/
│       ├── grain.yaml
│       ���── main.praia
├── grains/                  <- project-bundled grains
│   ├── math.praia
��   └── geometry.praia
├── grain.yaml               <- project manifest
├── sand-lock.yaml           <- lock file (auto-generated)
└── main.praia
```
