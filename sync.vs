// Package sync is concurrency beyond what the language gives: executors
// for work that should not run on the shared pool of workers.
//
// Code isolated to no actor runs on the runtime's workers, one per core,
// and a task gives up its worker only where it awaits. A long decode, an
// encode, a big inflate -- work that runs for a long time without
// awaiting -- holds its worker for all of it, and every task queued behind
// it there waits; on the main actor it stops the window. Swift's answer is
// a task executor preference (SE-0417), and ThreadPoolExecutor is an
// executor to prefer for such work:
//
//	let img = await withTaskExecutorPreference(ThreadPoolExecutor.shared) {
//	    png.Decode(bytes)
//	}
//
// The closure runs on the pool's threads, apart from the workers; the
// caller awaits it like any other call and carries on where it was.
package sync

/// ThreadPoolExecutor runs tasks' code on threads of its own, apart from
/// the runtime's workers and the main thread: a TaskExecutor for long,
/// CPU-heavy or blocking work to prefer (withTaskExecutorPreference,
/// Task(executorPreference:), addTask(executorPreference:)).
///
/// Each thread runs its tasks in turn, as a worker does, so a task on it
/// can await -- sleep, wait on a socket, join another task -- and the
/// others on that thread run meanwhile. Its threads last as long as the
/// program.
public final class ThreadPoolExecutor: TaskExecutor, _NativeTaskExecutor {
    /// How many threads the pool has.
    public let Threads: int
    /// The runtime's word for the pool, which a preference names.
    public let _nativeExecutor: UInt64

    /// A pool of so many threads, at least one.
    public init(threads: int) {
        let n = threads < 1 ? 1 : threads
        self.Threads = n
        self._nativeExecutor = _vertexTaskThreadPool(int32(n))
    }

    /// Runs the job on one of the pool's threads.
    public func enqueue(_ job: consuming ExecutorJob) {
        _vertexTaskEnqueueOn(_nativeExecutor, job._task)
    }

    public func asUnownedTaskExecutor() -> UnownedTaskExecutor {
        UnownedTaskExecutor(_proxy: _nativeExecutor)
    }

    /// The pool shared by whatever has long work to do: as many threads
    /// as the runtime has workers, at least two. Image and media codecs
    /// and the like send their work here.
    public static var Shared: ThreadPoolExecutor { sharedPool }
}

let sharedPool = ThreadPoolExecutor(threads: max(int(_vertexTaskWorkers()), 2))
