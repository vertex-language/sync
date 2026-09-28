// sync checked: work preferring a ThreadPoolExecutor runs there, apart from
// the main actor, which keeps running while it does.
package main

import (
    "sync"
    "time"
)

var failures = 0

func check(_ ok: bool, _ what: string) {
    if ok {
        print("ok    \(what)")
    } else {
        print("FAIL  \(what)")
        failures += 1
    }
}

/// The work, as a function isolated to no actor: where a task prefers an
/// executor, this is what runs there (a closure written in main is the
/// main actor's, as Swift has it, and runs where main does).
func heavy(_ n: int) async -> int {
    busy(n)
}

/// Work that holds its thread for a while without awaiting.
func busy(_ n: int) -> int {
    var x = 0
    var i = 0
    while i < n {
        x = (x &* 31 &+ i) & 0xFFFFFF
        i += 1
    }
    return x
}

@MainActor var ticks = 0

@MainActor
func tick() async {
    while ticks < 1000 {
        try? await Task.sleep(nanoseconds: 2_000_000)
        ticks += 1
    }
}

func main() async -> int32 {
    print("ThreadPoolExecutor")
    let pool = sync.ThreadPoolExecutor.Shared
    check(pool.Threads >= 2, "the shared pool has at least two threads (\(pool.Threads))")

    let r = await withTaskExecutorPreference(pool) { await heavy(1000) }
    check(r == busy(1000), "a closure preferring the pool gives its result back")

    // The main actor ticks while a long loop runs on the pool.
    let ticker = Task { await tick() }
    let start = time.Instant.Now()
    let before = await MainActor.run { ticks }
    let long = await withTaskExecutorPreference(pool) { await heavy(60_000_000) }
    let after = await MainActor.run { ticks }
    let seconds = start.Elapsed().AsSeconds()
    ticker.cancel()
    check(long >= 0, "the long loop finishes")
    check(after - before >= 3, "the main actor kept running meanwhile: \(after - before) ticks in \(seconds)s")

    // Children of a group each prefer the pool.
    let own = sync.ThreadPoolExecutor(threads: 3)
    let total = await withTaskGroup(of: int.self) { group in
        for i in 1...4 { group.addTask(executorPreference: own) { await heavy(i * 1000) } }
        var t = 0
        for await v in group { t += v }
        return t
    }
    check(total == busy(1000) + busy(2000) + busy(3000) + busy(4000), "a task group's children prefer a pool of their own")

    // A task on the pool can await: it sleeps there and carries on.
    let slept = await withTaskExecutorPreference(own) { () async -> int in
        try? await Task.sleep(nanoseconds: 5_000_000)
        return 7
    }
    check(slept == 7, "a task on the pool sleeps and carries on there")

    if failures == 0 {
        print("ALL SYNC CHECKS PASSED")
        return 0
    }
    print("\(failures) FAILED")
    return 1
}
