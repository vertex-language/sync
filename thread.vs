package sync

var threadTableLock = Mutex()
var nextThreadId: int64 = 1
var threadTable: [int64: () -> Void] = [:]

@_cdecl("sync_thread_run")
func syncThreadRun(id: int64) {
    var fn: (() -> Void)? = nil
    threadTableLock.withLock {
        fn = threadTable[id]
        threadTable[id] = nil
    }
    if let run = fn {
        run()
    }
}

/// A dedicated operating system thread.
public final class Thread {
    var raw: UnsafeMutableRawPointer?
    let lock = Mutex()

    init(raw: UnsafeMutableRawPointer?) {
        self.raw = raw
    }

    /// Spawns a dedicated OS thread running `body`.
    public static func spawn(_ body: @escaping () -> Void) -> Thread {
        var id: int64 = 0
        threadTableLock.withLock {
            id = nextThreadId
            nextThreadId += 1
            threadTable[id] = body
        }
        let t = syncThreadSpawn(id)
        return Thread(raw: t)
    }

    public func join() {
        var r: UnsafeMutableRawPointer? = nil
        lock.withLock {
            r = raw
            raw = nil
        }
        if let ptr = r {
            syncThreadJoin(ptr)
        }
    }

    public func detach() {
        var r: UnsafeMutableRawPointer? = nil
        lock.withLock {
            r = raw
            raw = nil
        }
        if let ptr = r {
            syncThreadDetach(ptr)
        }
    }
}
