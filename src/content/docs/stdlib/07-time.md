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
| `time.parse(str, fmt?)` | Parse date string to millisecond timestamp |
| `time.year(ts)`, `month`, `day` | Extract date components from ms timestamp |
| `time.hour(ts)`, `minute`, `second` | Extract time components |
| `time.weekday(ts)` | Day of week (0=Sunday, 6=Saturday) |
| `time.addDays(ts, n)` | Add/subtract days |
| `time.addHours(ts, n)`, `addMinutes`, `addSeconds` | Add/subtract time |

## Examples

```praia
let start = time.now()
time.sleep(100)
print(time.now() - start)          // ~100

print(time.format())               // "2026-04-25 13:00:00"
print(time.format("%H:%M"))        // "13:00"
print(time.epoch())                // 1776510000
```

## Parsing dates

`time.parse` auto-detects `YYYY-MM-DD` and `YYYY-MM-DD HH:MM:SS` formats, or accepts a custom strftime format string.

```praia
let ts = time.parse("2024-06-15")
print(time.format("%Y-%m-%d", ts))  // "2024-06-15"

let ts2 = time.parse("15/06/2024", "%d/%m/%Y")
```

## Benchmarking

```praia
let start = time.now()
// ... code to measure ...
print("took", time.now() - start, "ms")
```
