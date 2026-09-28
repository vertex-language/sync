# sync

[![package: vs-package](https://img.shields.io/badge/package-vs--package-f4f4f5?style=flat-square&labelColor=e4e4e7&color=18181b)](https://github.com/vertex-language)

Concurrency beyond what the language gives: executors for work that shouldn't run on the shared pool.

---

## Packages

| Package | What it is | Native code |
| :--- | :--- | :--- |
| **`sync`** | `ThreadPoolExecutor`: a `TaskExecutor` with threads of its own, for long, CPU-heavy or blocking work to prefer; `ThreadPoolExecutor.Shared` for everyone's. | none (the runtime's thread pools) |

---

## Long work, off the workers and the main thread

A task gives up its thread only where it awaits. So a decode, an encode or a big inflate holds its worker for the whole time it runs, and every task queued behind it waits; on the main actor it stops the window. Swift's answer is a task executor preference (SE-0417):

```swift
import "sync"

nonisolated func decode(_ bytes: [uint8]) async throws -> image.RGBA {
    try png.Decode(bytes)
}

let img = try await withTaskExecutorPreference(sync.ThreadPoolExecutor.Shared) {
    try await decode(bytes)
}
```

The preference moves code that is isolated to no actor, as Swift's does: here, `decode`. A closure written in `@MainActor` code is the main actor's, and runs there. `Task(executorPreference:)` and `group.addTask(executorPreference:)` take one too.

The pool's threads each run their tasks in turn, the way a worker does. So work there can await (sleep, read a socket, join another task), and the others on that thread run meanwhile.

---

## Checks

```bash
vsc run ./cmd/check-sync
```
