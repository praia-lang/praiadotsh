---
title: Time
sidebar:
  order: 7
---

The `time` namespace provides timestamps, formatting, and sleep.

## Functions

| Function | Description |
|----------|-------------|
| `time.now()` | Current time as Unix milliseconds |
| `time.epoch()` | Current time as Unix seconds |
| `time.sleep(ms)` | Pause execution for ms milliseconds |
| `time.format(fmt?, timestamp?)` | Format time as string (default: `"%Y-%m-%d %H:%M:%S"`) |

## Examples

```praia
let start = time.now()
time.sleep(100)
print(time.now() - start)          // ~100

print(time.format())               // "2026-04-25 13:00:00"
print(time.format("%H:%M"))        // "13:00"
print(time.epoch())                // 1776510000
```

## Benchmarking

```praia
let start = time.now()
// ... code to measure ...
print("took", time.now() - start, "ms")
```
