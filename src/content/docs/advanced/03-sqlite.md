---
title: SQLite
sidebar:
  order: 3
---

Built-in SQLite database support. Available when built with libsqlite3.

## Opening a database

```praia
let db = sqlite.open("myapp.db")       // file-based
let db = sqlite.open(":memory:")       // in-memory
```

## Queries

`db.query(sql, params?)` executes a SELECT and returns an array of maps (one per row):

```praia
let users = db.query("SELECT * FROM users WHERE age > ?", [18])
for (user in users) {
    print(user.name, user.age)
}
```

## Executing statements

`db.run(sql, params?)` executes INSERT/UPDATE/DELETE and returns `{changes, lastId}`:

```praia
let result = db.run("INSERT INTO users (name, age) VALUES (?, ?)", ["Ada", 36])
print(result.lastId)      // auto-increment id
print(result.changes)     // rows affected
```

## Parameterized queries

Always use `?` placeholders -- they prevent SQL injection:

```praia
// Safe
db.query("SELECT * FROM users WHERE name = ?", [name])

// Unsafe -- never do this
db.query("SELECT * FROM users WHERE name = '" + name + "'")
```

Parameters are bound by type: strings, numbers, bools, and nil are all handled automatically.

## Closing

```praia
db.close()
```

## Example: REST API with SQLite

```praia
use "router"

let db = sqlite.open(":memory:")
db.run("CREATE TABLE todos (id INTEGER PRIMARY KEY, title TEXT, done INT)")

let server = router.create()

server.get("/todos", lam{ req, params in
    let todos = db.query("SELECT * FROM todos")
    return http.json(todos)
})

server.post("/todos", lam{ req, params in
    let todo = json.parse(req.body)
    db.run("INSERT INTO todos (title, done) VALUES (?, ?)", [todo.title, 0])
    return http.json({ok: true}, 201)
})

server.listen(8080)
```
