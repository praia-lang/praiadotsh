---
title: Compression (zlib)
sidebar:
  order: 12
---

`zlib` is one-shot gzip and raw-deflate. Two pairs of inverses:

| Function | Format | Use when |
|----------|--------|----------|
| `zlib.gzip(bytes, level?)` / `zlib.gunzip(bytes, maxOutput?)` | RFC 1952 (10-byte header + crc32 + isize) | `.gz` files, HTTP `Content-Encoding: gzip`, log rotation -- any payload that needs to be self-framing |
| `zlib.deflate(bytes, level?)` / `zlib.inflate(bytes, maxOutput?)` | RFC 1951 raw deflate (no header, no checksum) | Inner layer of a protocol that already frames the compressed body |

`level` is an integer 0..9: 0 = stored (no compression), 1 = fastest, 9 = best. Omit it to use zlib's default (currently 6) -- a good ratio/CPU balance for typical text.

`maxOutput` (on `gunzip` / `inflate`) caps the decompressed size in bytes. A few hundred bytes of gzip can decompress to gigabytes -- a "zip bomb" -- so the inverse direction has a default ceiling of **64 MiB**. Pass an explicit value to raise (or lower) the cap; pass `nil` to use the default. Exceeding the cap throws.

```praia
// Trusted .gz that we know is bigger than the default — raise the cap.
let body = zlib.gunzip(fs.read("trusted-big.gz"), 512 * 1024 * 1024)

// Untrusted HTTP body — keep the safe default.
if (resp.headers["content-encoding"] == "gzip") {
    resp.body = zlib.gunzip(resp.body)
}
```

```praia
// Round-trip a log file through gzip
let body = fs.read("server.log")
let gz = zlib.gzip(body)
fs.write("server.log.gz", gz)
testing.expectEqual(zlib.gunzip(fs.read("server.log.gz")), body, nil)

// HTTP body inflate when the server sets Content-Encoding: gzip
let resp = http.get(url)
if (resp.headers["content-encoding"] == "gzip") {
    resp.body = zlib.gunzip(resp.body)
}
```

## Errors

Invalid input throws `zlib: inflate failed: <detail>`. Common failure modes:

- Truncated stream (file copy interrupted, CRC mismatch).
- Wrong format for the inverse -- `zlib.gunzip(rawDeflateOutput)` fails because gzip expects the framing header; `zlib.inflate(gzipOutput)` fails because raw inflate doesn't understand the 10-byte gzip prefix.
- Plain garbage that doesn't decode as either format.
- Output past `maxOutput` -- throws "inflate output exceeded maxOutput (...) — possible zip bomb; pass a higher maxOutput if intentional".

Mixing formats is an immediate failure rather than silent corruption.

## Out of scope

Streaming compression (process a multi-gigabyte file without holding it all in memory) is intentionally not included. The one-shot API covers nearly all practical use cases. If you have a real workload that needs incremental compression, pair `fs.open` chunked reads with manual chunking, or open an issue for a stateful `zlib.deflater()` builder.

For `.tar` and `.zip` archives, see the [`archive` grain](https://github.com/praia-lang/praia-tar) -- it's a sand-installable plugin rather than a built-in to keep the core binary's dependency surface small.

## Build dependency

`zlib` requires libz at link time. It's universally available on macOS and Linux distributions; the Makefile auto-detects it. If libz is somehow absent, every `zlib.*` call throws "requires zlib (rebuild with HAVE_ZLIB)".
