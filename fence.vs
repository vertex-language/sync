package sync

/// A full memory fence: every load and store before it is visible to
/// other threads, and to a virtual machine's vCPUs, before any after it.
/// Swift's `atomicMemoryFence(ordering: .sequentiallyConsistent)`.
///
/// A mutex orders what threads that take it see; this is for memory read
/// by someone who takes no lock, like a device writing guest memory that
/// a vCPU polls.
public func MemoryFence() {
    syncMemoryFence()
}
