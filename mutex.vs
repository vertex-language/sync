package sync

/// Mutex is a mutual exclusion lock for short critical sections.
public final class Mutex {
    let raw: UnsafeMutableRawPointer?

    public init() {
        self.raw = syncMutexNew()
    }

    deinit {
        if let r = raw {
            syncMutexFree(r)
        }
    }

    public func lock() {
        if let r = raw {
            syncMutexLock(r)
        }
    }

    public func unlock() {
        if let r = raw {
            syncMutexUnlock(r)
        }
    }

    public func tryLock() -> bool {
        if let r = raw {
            return syncMutexTryLock(r)
        }
        return false
    }

    public func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock()
        defer { unlock() }
        return try body()
    }
}
