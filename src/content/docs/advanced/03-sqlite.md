---
title: SQLite
sidebar:
  order: 3
---

Built-in SQLite database support. Available when built with libsqlite3.

`sqlite.open` returns an opaque connection handle that prints as `<external:sqlite.connection>`. Operations are free functions on the `sqlite` namespace that take the connection as their first argument. The handle is automatically closed when the last reference drops (during the GC sweep); for deterministic cleanup call `sqlite.close(db)` or use `defer`.

## Opening a database

```praia
let db = sqlite.open("myapp.db")       // file-based
let db = sqlite.open(":memory:")       // in-memory
```

## Queries

`sqlite.query(db, sql, params?)` executes a SELECT and returns an array of maps (one per row):

```praia
let users = sqlite.query(db, "SELECT * FROM users WHERE age > ?", [18])
for (user in users) {
    print(user.name, user.age)
}
```

INTEGER columns are returned as Praia ints, preserving the full 64-bit range; REAL as floats; TEXT as strings; NULL as `nil`. TEXT and BLOB values come back as strings of their full byte length, so binary data and text containing NUL bytes round-trip (and bound string parameters are stored whole, NUL bytes included).

## Executing statements

`sqlite.run(db, sql, params?)` executes INSERT/UPDATE/DELETE/DDL and returns `{changes, lastId}`. Like `sqlite.query`, it runs exactly one statement: SQL with another statement after the first (`"SELECT 1; DROP TABLE t"`) is an error rather than having the rest silently ignored, so make one call per statement. A trailing `;` or comment is fine.

```praia
let result = sqlite.run(db, "INSERT INTO users (name, age) VALUES (?, ?)", ["Ada", 36])
print(result.lastId)      // auto-increment id
print(result.changes)     // rows affected
```

## Parameterized queries

Always use `?` placeholders -- they prevent SQL injection:

```praia
// Safe
sqlite.query(db, "SELECT * FROM users WHERE name = ?", [name])

// Unsafe -- never do this
sqlite.query(db, "SELECT * FROM users WHERE name = '" + name + "'")
```

Parameters are bound by type: strings, ints, floats, bools, and nil are all handled automatically.

## Transactions

`sqlite.run` also accepts transaction-control statements:

```praia
sqlite.run(db, "BEGIN")
try {
    sqlite.run(db, "UPDATE accounts SET balance = balance - 100 WHERE id = ?", [from])
    sqlite.run(db, "UPDATE accounts SET balance = balance + 100 WHERE id = ?", [to])
    sqlite.run(db, "COMMIT")
} catch (e) {
    sqlite.run(db, "ROLLBACK")
    throw e
}
```

## Closing

`sqlite.close(db)` is idempotent -- calling it twice (or after the GC has already closed the handle) is a no-op, never a double-free:

```praia
sqlite.close(db)
```

## Example: REST API with SQLite

```praia
use "router"

let db = sqlite.open(":memory:")
sqlite.run(db, "CREATE TABLE todos (id INTEGER PRIMARY KEY, title TEXT, done INT)")

let server = router.create()

server.get("/todos", lam{ req, params in
    let todos = sqlite.query(db, "SELECT * FROM todos")
    return http.json(todos)
})

server.post("/todos", lam{ req, params in
    let todo = json.parse(req.body)
    sqlite.run(db, "INSERT INTO todos (title, done) VALUES (?, ?)", [todo.title, 0])
    return http.json({ok: true}, 201)
})

server.listen(8080)
```
