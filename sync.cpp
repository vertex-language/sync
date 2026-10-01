// Native primitives for package sync: Mutex and OS Thread.
module;
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <pthread.h>
#if defined(__APPLE__)
#include <os/lock.h>
#endif
#endif

extern "C" void sync_thread_run(int64_t id);

export module sync;

export void* syncMutexNew() noexcept {
#if defined(_WIN32)
    CRITICAL_SECTION* cs = (CRITICAL_SECTION*)malloc(sizeof(CRITICAL_SECTION));
    if (cs) InitializeCriticalSection(cs);
    return cs;
#elif defined(__APPLE__)
    os_unfair_lock_t lock = (os_unfair_lock_t)malloc(sizeof(os_unfair_lock));
    if (lock) *lock = OS_UNFAIR_LOCK_INIT;
    return lock;
#else
    pthread_mutex_t* m = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (m) pthread_mutex_init(m, NULL);
    return m;
#endif
}

export void syncMutexFree(void* m) noexcept {
    if (!m) return;
#if defined(_WIN32)
    DeleteCriticalSection((CRITICAL_SECTION*)m);
    free(m);
#elif defined(__APPLE__)
    free(m);
#else
    pthread_mutex_destroy((pthread_mutex_t*)m);
    free(m);
#endif
}

export void syncMutexLock(void* m) noexcept {
    if (!m) return;
#if defined(_WIN32)
    EnterCriticalSection((CRITICAL_SECTION*)m);
#elif defined(__APPLE__)
    os_unfair_lock_lock((os_unfair_lock_t)m);
#else
    pthread_mutex_lock((pthread_mutex_t*)m);
#endif
}

export void syncMutexUnlock(void* m) noexcept {
    if (!m) return;
#if defined(_WIN32)
    LeaveCriticalSection((CRITICAL_SECTION*)m);
#elif defined(__APPLE__)
    os_unfair_lock_unlock((os_unfair_lock_t)m);
#else
    pthread_mutex_unlock((pthread_mutex_t*)m);
#endif
}

export bool syncMutexTryLock(void* m) noexcept {
    if (!m) return false;
#if defined(_WIN32)
    return TryEnterCriticalSection((CRITICAL_SECTION*)m) != 0;
#elif defined(__APPLE__)
    return os_unfair_lock_trylock((os_unfair_lock_t)m);
#else
    return pthread_mutex_trylock((pthread_mutex_t*)m) == 0;
#endif
}

struct ThreadWrapper {
#if defined(_WIN32)
    HANDLE h;
#else
    pthread_t t;
#endif
};

#if !defined(_WIN32)
static void* threadEntry(void* arg) {
    int64_t id = (int64_t)(intptr_t)arg;
    sync_thread_run(id);
    return NULL;
}
#else
static DWORD WINAPI threadEntryWin(LPVOID arg) {
    int64_t id = (int64_t)(intptr_t)arg;
    sync_thread_run(id);
    return 0;
}
#endif

export void* syncThreadSpawn(int64_t id) noexcept {
    ThreadWrapper* tw = (ThreadWrapper*)malloc(sizeof(ThreadWrapper));
    if (!tw) return NULL;
#if defined(_WIN32)
    tw->h = CreateThread(NULL, 0, threadEntryWin, (LPVOID)(intptr_t)id, 0, NULL);
    if (!tw->h) { free(tw); return NULL; }
#else
    if (pthread_create(&tw->t, NULL, threadEntry, (void*)(intptr_t)id) != 0) {
        free(tw);
        return NULL;
    }
#endif
    return tw;
}

export void syncThreadJoin(void* t) noexcept {
    if (!t) return;
    ThreadWrapper* tw = (ThreadWrapper*)t;
#if defined(_WIN32)
    if (tw->h) {
        WaitForSingleObject(tw->h, INFINITE);
        CloseHandle(tw->h);
    }
#else
    pthread_join(tw->t, NULL);
#endif
    free(tw);
}

export void syncThreadDetach(void* t) noexcept {
    if (!t) return;
    ThreadWrapper* tw = (ThreadWrapper*)t;
#if defined(_WIN32)
    if (tw->h) CloseHandle(tw->h);
#else
    pthread_detach(tw->t);
#endif
    free(tw);
}

// A full memory fence: loads and stores before it are visible to every
// other thread before any after it.
export void syncMemoryFence() noexcept {
    __atomic_thread_fence(__ATOMIC_SEQ_CST);
}
