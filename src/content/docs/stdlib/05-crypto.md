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

### AES encryption (requires OpenSSL)

AES-256-CBC symmetric encryption. Key must be 32 bytes, IV must be 16 bytes.

```praia
let key = crypto.randomBytes(32)
let iv = crypto.randomBytes(16)

let encrypted = crypto.encrypt("secret data", key, iv)
let decrypted = crypto.decrypt(encrypted, key, iv)
print(decrypted)   // "secret data"
```

### Password hashing (requires OpenSSL)

PBKDF2-SHA256 for secure password storage:

```praia
// Hash a password
let result = crypto.hashPassword("mypassword")
print(result.hash)        // hex hash
print(result.salt)        // hex salt
print(result.iterations)  // 100000

// Verify a password
crypto.verifyPassword("mypassword", result.hash, result.salt)  // true
crypto.verifyPassword("wrong", result.hash, result.salt)        // false
```

Custom iterations: `crypto.hashPassword("pass", nil, 200000)`

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

### Character codes

```praia
"A".charCode()              // 65
"hello".charCode(1)         // 101
fromCharCode(65)            // "A"
fromCharCode(0x1F600)       // emoji
```
