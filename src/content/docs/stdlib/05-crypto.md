---
title: Crypto & Bytes
sidebar:
  order: 5
---

## Crypto

The `crypto` namespace provides hashing, HMAC, encryption, password hashing, and secure random bytes.

### Hashing

| Function | Description |
|----------|-------------|
| `crypto.md5(string)` | MD5 hash (32-char hex) |
| `crypto.sha1(string)` | SHA-1 hash (40-char hex) |
| `crypto.sha256(string)` | SHA-256 hash (64-char hex) |
| `crypto.sha512(string)` | SHA-512 hash (128-char hex) |

```praia
crypto.md5("hello")     // "5d41402abc4b2a76b9719d911017c592"
crypto.sha1("hello")    // "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d"
crypto.sha256("hello")  // "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
```

### HMAC

`crypto.hmac(key, message, algorithm)` computes a keyed hash. Supported: `"sha256"`, `"sha1"`, `"sha512"`, `"md5"`.

```praia
crypto.hmac("secret-key", "message", "sha256")
```

### Random bytes

`crypto.randomBytes(count)` returns cryptographically secure random bytes as a raw string:

```praia
let key = crypto.randomBytes(32)     // 32 random bytes (256-bit key)
let iv = crypto.randomBytes(16)      // 16 random bytes (128-bit IV)
let token = bytes.hex(crypto.randomBytes(16))  // hex string token
```

For user-facing token generation, prefer the higher-level [`secrets` namespace](#secrets) -- it ships pre-encoded variants plus a constant-time comparator.

### Key derivation — `crypto.hkdf` (requires OpenSSL 3+)

`crypto.hkdf(key, salt, info, length, hash?)` implements RFC 5869 HKDF. Use it to derive multiple independent keys from one master secret, or to bind a key to a context label so a leak of one derived key doesn't compromise siblings.

| Arg | Description |
|-----|-------------|
| `key` | Input keying material (IKM); the master secret |
| `salt` | Salt bytes; empty string is allowed |
| `info` | Context label (e.g. `"encryption-key-v1"`); empty is allowed |
| `length` | Output bytes; capped at `255 × hash_output_size` (8160 for SHA-256) |
| `hash` (optional) | One of `"sha256"` (default), `"sha384"`, `"sha512"`, `"sha1"` |

```praia
let master = secrets.token(32)
let salt   = secrets.token(16)

let encKey    = crypto.hkdf(master, salt, "encryption-key-v1", 32)
let macKey    = crypto.hkdf(master, salt, "mac-key-v1",        32)
let cookieKey = crypto.hkdf(master, salt, "cookie-key-v1",     32)
```

Same master + same context → same key (deterministic). Different context → unrelated key.

## Secrets

`secrets` is the canonical namespace for generating tokens and comparing them safely. It exists for the same reason Python's `secrets` module does: when callers reach for `random.*` to build a session ID they get a Mersenne Twister output and ship a vulnerability. Every function here pulls from the OS CSPRNG.

| Function | Description |
|----------|-------------|
| `secrets.token(n)` | `n` raw bytes, as a Praia bytes-string |
| `secrets.tokenHex(n)` | `n` random bytes as 2n-character lower-case hex; database-friendly |
| `secrets.tokenUrlSafe(n)` | `n` random bytes as URL-safe base64, no padding (RFC 4648 §5); use for password-reset URLs, unsubscribe links |
| `secrets.compare(a, b)` | Constant-time string equality; use this to compare HMAC tags / session IDs / API keys |
| `secrets.choice(seq)` | Uniformly random element from a non-empty array or string; rejection-sampled to avoid modulo bias |

```praia
let sessionId = secrets.tokenHex(32)             // 64-char hex, ~256 bits
let resetLink = "/reset/" + secrets.tokenUrlSafe(24)

// Constant-time tag verification
let expected = crypto.hmac(serverKey, body, "sha256")
if (!secrets.compare(expected, request.tag)) {
    throw "tag mismatch"
}
```

`secrets.compare` exists because comparing two secrets with `==` short-circuits on the first byte that differs -- the time the comparison takes leaks how many leading bytes were correct, and an attacker can recover the secret one byte at a time by measuring response timing. The constant-time version walks the full buffer regardless of where the mismatch is.

### Authenticated encryption — `seal` / `open` (requires OpenSSL)

`crypto.seal` and `crypto.open` are the recommended symmetric encryption API. They use AES-256-GCM, an authenticated (AEAD) cipher: a successful `open` proves both that the ciphertext was produced by someone holding the key AND that no bit of it has been altered. Use this for anything new — cookies, file encryption, request payloads, transport over an untrusted channel.

```praia
let key = crypto.randomBytes(32)          // 32-byte (256-bit) key

let sealed = crypto.seal("secret data", key)
let plain  = crypto.open(sealed, key)     // throws if tampered or wrong key
print(plain)                              // "secret data"
```

The sealed blob is a single binary string laid out as `nonce(12) ‖ ciphertext ‖ tag(16)`. The nonce is generated freshly per call from the CSPRNG and bundled in; the caller never manages it.

#### Additional Authenticated Data (AAD)

An optional third argument binds context to the tag without encrypting it. The same value must be passed to `open`, or authentication fails. Useful for context that must match but doesn't need to be secret:

```praia
let token = crypto.seal(user_data, key, "user-id:42|v=1")
let data  = crypto.open(token, key, "user-id:42|v=1")   // ok
crypto.open(token, key, "user-id:43|v=1")               // throws
```

#### Errors

`open` throws on any authentication failure — tampered ciphertext, wrong key, or AAD mismatch all surface as the same `authentication failed` error. By design: distinguishing them would give an attacker an oracle.

### AES-256-CBC — low-level, unauthenticated (requires OpenSSL)

> **⚠ Read `seal` / `open` above first.** These provide **confidentiality only**. An attacker who can modify the ciphertext causes controlled changes to the decrypted plaintext that `decrypt()` cannot detect. Use CBC only for interop with legacy systems that demand it.

AES-256-CBC. Key must be 32 bytes, IV must be 16 bytes and must never be reused with the same key.

```praia
let key = crypto.randomBytes(32)
let iv  = crypto.randomBytes(16)

let encrypted = crypto.encrypt("secret data", key, iv)
let decrypted = crypto.decrypt(encrypted, key, iv)
print(decrypted)   // "secret data"
```

If you must use CBC, also HMAC over `iv ‖ ciphertext` with a separate key and verify before decrypting (encrypt-then-MAC). Or just use `seal` / `open`.

### Password hashing (requires OpenSSL)

Three schemes are available, in order of preference for new code:

1. **`crypto.argon2id`** -- memory-hard; OWASP first-choice as of 2024. Requires OpenSSL 3.2+.
2. **`crypto.scrypt`** -- also memory-hard; available in all OpenSSL 3.x.
3. **`crypto.hashPassword`** -- legacy PBKDF2-SHA256; kept for back-compat. Not recommended for new applications.

Both `argon2id` and `scrypt` return self-describing **PHC strings** carrying algorithm + cost parameters in the hash itself, so a stored hash can be verified without any side-table metadata. The format is interoperable with Python's `passlib`, libsodium, and the argon2 reference CLI.

#### `crypto.argon2id` -- recommended

```praia
let h = crypto.argon2id("hunter2")
// "$argon2id$v=19$m=65536,t=3,p=4$<salt>$<hash>"

crypto.verifyArgon2id("hunter2", h)   // true
crypto.verifyArgon2id("wrong", h)     // false

// Custom cost
let h2 = crypto.argon2id("pw", {t: 4, m: 131072, p: 2, length: 32})
```

| Param | Default | Description |
|-------|---------|-------------|
| `t` | `3` | Iterations (time cost, ≥1) |
| `m` | `65536` | Memory in KiB (≥ `8 * p`) |
| `p` | `4` | Parallelism / lanes (≥1) |
| `salt` | random 16 bytes | Salt bytes (≥ 8) |
| `length` | `32` | Output bytes |

Defaults match RFC 9106 §4's "second recommended option" -- roughly 250 ms on a modest server. Throws on OpenSSL < 3.2.

#### `crypto.scrypt` -- RFC 7914

```praia
let h = crypto.scrypt("hunter2")
// "$scrypt$ln=15,r=8,p=1$<salt>$<hash>"

crypto.verifyScrypt("hunter2", h)
```

| Param | Default | Description |
|-------|---------|-------------|
| `ln` | `15` | `log2(N)`; CPU/memory cost. `ln=15` → N=32768 (~32 MiB) |
| `r` | `8` | Block size |
| `p` | `1` | Parallelism |
| `salt` | random 16 bytes | Salt bytes (≥ 8) |
| `length` | `32` | Output bytes |

#### `crypto.hashPassword` -- legacy PBKDF2

Map-style return; kept for back-compat with code that already stores `{hash, salt, iterations}`.

```praia
let result = crypto.hashPassword("mypassword")
crypto.verifyPassword("mypassword", result.hash, result.salt)  // true
```

### Digital signatures (requires OpenSSL)

Sign and verify data with RSA or EC keys.

| Function | Description |
|----------|-------------|
| `crypto.sign(data, privateKeyPEM, algorithm?)` | Sign data, returns base64 signature |
| `crypto.verify(data, signature, publicKeyPEM, algorithm?)` | Verify signature, returns boolean |
| `crypto.generateKeyPair(type?, bits?)` | Generate `{privateKey, publicKey}` PEM pair |

```praia
let keys = crypto.generateKeyPair("rsa", 2048)
let sig = crypto.sign("hello", keys.privateKey)
crypto.verify("hello", sig, keys.publicKey)  // true

// EC keys (P-256)
let ecKeys = crypto.generateKeyPair("ec")
let ecSig = crypto.sign("data", ecKeys.privateKey)
crypto.verify("data", ecSig, ecKeys.publicKey)  // true
```

Supported algorithms: `"sha256"` (default), `"sha384"`, `"sha512"`, `"sha1"`.

### X.509 certificate parsing (requires OpenSSL)

| Function | Description |
|----------|-------------|
| `crypto.parseCertificate(pemOrDer)` | Parse a single certificate; accepts PEM text or DER bytes |
| `crypto.parseCertificateChain(pem)` | Parse all PEM certificates in a bundle (server + intermediates), returns array |

`parseCertificate` returns:

| Field | Type | Meaning |
|-------|------|---------|
| `version` | int | X.509 version (typically 3) |
| `serial` | string | Lowercase hex; real serials are 128+ bits and don't fit in int64 |
| `subject` / `issuer` | map | DN keyed by short name: `CN`, `O`, `OU`, `C`, `ST`, `L`, ... |
| `subjectString` / `issuerString` | string | OpenSSL `/CN=foo/O=bar` one-liner |
| `notBefore` / `notAfter` | string | ISO 8601 (`"2026-05-12T12:27:46Z"`) |
| `sigAlg` | string | Signature algorithm long name (e.g. `"sha256WithRSAEncryption"`) |
| `sans` | array | `[{type: "DNS"\|"IP"\|"email"\|"URI", value: ...}, ...]` |
| `fingerprintSha256` | string | 64-char lowercase hex of the DER form |
| `isCA` | bool | basicConstraints flag |
| `publicKey` | string | PEM SubjectPublicKeyInfo block |
| `publicKeyInfo` | map | `{type, bits}` — algorithm short name + key size |

```praia
let c = crypto.parseCertificate(fs.read("server.crt"))

print(c.subject.CN)             // "example.com"
print(c.notAfter)               // "2026-08-15T00:00:00Z"
for (s in c.sans) {
    if (s.type == "DNS") { print("hostname:", s.value) }
}

// Bundle parsing
let chain = crypto.parseCertificateChain(fs.read("fullchain.pem"))
print("chain depth:", len(chain))
```

Out of scope for v1: full extension table, AuthorityInfoAccess, CRL distribution points, Certificate Transparency SCTs.

## Base64

| Function | Description |
|----------|-------------|
| `base64.encode(str)` | Encode string to standard base64 |
| `base64.decode(str)` | Decode standard base64 to string |
| `base64.encodeURL(str)` | URL-safe base64 (RFC 4648): `-_` instead of `+/`, no padding |
| `base64.decodeURL(str)` | Decode URL-safe base64 |

```praia
base64.encode("hello")         // "aGVsbG8="
base64.decode("aGVsbG8=")     // "hello"

base64.encodeURL("hello")     // "aGVsbG8" (no padding)
base64.decodeURL("aGVsbG8")   // "hello"
```

## Bytes

The `bytes` namespace provides binary data packing and unpacking.

### Struct format strings

`bytes.pack` and `bytes.unpack` accept Python-style struct format strings.

**Endian prefix** (required):

| Prefix | Byte order |
|--------|------------|
| `>` or `!` | Big-endian (network) |
| `<` or `=` | Little-endian |

**Type characters:**

| Char | Size | Description |
|------|------|-------------|
| `B` | 1 | Unsigned 8-bit |
| `b` | 1 | Signed 8-bit |
| `H` | 2 | Unsigned 16-bit |
| `h` | 2 | Signed 16-bit |
| `I` | 4 | Unsigned 32-bit |
| `i` | 4 | Signed 32-bit |
| `Q` | 8 | Unsigned 64-bit |
| `q` | 8 | Signed 64-bit |
| `f` | 4 | 32-bit float |
| `d` | 8 | 64-bit double |
| `x` | 1 | Pad byte (no value consumed) |

Repeat counts: `3B` means three unsigned bytes, `4x` means four pad bytes.

### bytes.pack / bytes.unpack

```praia
// Pack big-endian u8 + u16 + u32
let data = bytes.pack(">BHI", [255, 1234, 100000])
let vals = bytes.unpack(">BHI", data)     // [255, 1234, 100000]
```

### bytes.calcsize

```praia
bytes.calcsize(">BHI")    // 7
bytes.calcsize(">3B2Hd")  // 15
```

### Byte conversion

```praia
let raw = bytes.from([72, 101, 108, 108, 111])    // "Hello"
let arr = bytes.toArray("Hello")                    // [72, 101, 108, 108, 111]

// Hex encoding
bytes.hex("ABC")                // "414243"
bytes.fromHex("414243")         // "ABC"

// Byte length
bytes.len(data)
```

### Byte-indexed search and slice

The string method versions of `slice`/`indexOf` are grapheme-indexed and corrupt arbitrary binary data. The `bytes.*` versions operate on raw bytes — use these when a string holds non-text content (file uploads, network frames, etc.):

```praia
bytes.slice(data, start, end?)         // byte-indexed substring
bytes.indexOf(data, sub, startByte?)   // byte offset of first match (-1 if none)
```

```praia
let body = req.body                    // raw HTTP body, may be binary
let boundary = "--" + b
let pos = bytes.indexOf(body, boundary)
let part = bytes.slice(body, pos + bytes.len(boundary))
```

Negative indices count from the end. `bytes.slice` clamps out-of-range indices to the string boundary.

### Character codes

```praia
"A".charCode()              // 65
"hello".charCode(1)         // 101
fromCharCode(65)            // "A"
fromCharCode(0x1F600)       // emoji
```
