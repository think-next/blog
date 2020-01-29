---
title: runtime中P的理解

date: 2019-11-11

tags: [golang]

author: 付辉

---

`P`是在`Go1.1`引入的概念，初始默认等于`CPU`核的数量。`P`只是一个逻辑概念，跟`CPU`也没有任何关系。

源码`go/1.13.4/libexec/src/runtime/proc.go`中对`P`的注释如下：
```go
// P - processor, a resource that is required to execute Go code.
// M must have an associated P to execute Go code, however it can be
// blocked or in a syscall w/o an associated P.
```

再通过源码`go/1.13.4/libexec/src/runtime/runtime2.go`来简要了解一下`P`在调度过程中的状态变化：

```go
const (
    // P status
    _Pidle = iota
    _Prunning
    _Psyscall
    _Pgcstop
   
    // _Pdead means a P is no longer used (GOMAXPROCS shrank). We
    // reuse Ps if GOMAXPROCS increases. A dead P is mostly
    // stripped of its resources, though a few things remain
    // (e.g., trace buffers).
    _Pdead
)
```
通过调整`GOMAXPROCS`可以控制`P`的状态，`_Pdead`专门来说明这一点。

从`P`的结构体字段中，可以进一步了解`P`中存储的资源，源码`go/1.13.4/libexec/src/runtime/runtime2.go`：

```go
type p struct {
        id          int32
        status      uint32 // one of pidle/prunning/...
        link        puintptr
        schedtick   uint32     // incremented on every scheduler call
        syscalltick uint32     // incremented on every system call
        sysmontick  sysmontick // last tick observed by sysmon
        m           muintptr   // back-link to associated m (nil if idle)
        mcache      *mcache
        raceprocctx uintptr

        deferpool    [5][]*_defer // pool of available defer structs of different sizes (see panic.go)
        deferpoolbuf [5][32]*_defer

        // Cache of goroutine ids, amortizes accesses to runtime·sched.goidgen.
        goidcache    uint64
        goidcacheend uint64

        // Queue of runnable goroutines. Accessed without lock.
        runqhead uint32
        runqtail uint32
        runq     [256]guintptr
        // runnext, if non-nil, is a runnable G that was ready'd by
        // the current G and should be run next instead of what's in
        // runq if there's time remaining in the running G's time
        // slice. It will inherit the time left in the current time
        // slice. If a set of goroutines is locked in a
        // communicate-and-wait pattern, this schedules that set as a
        // unit and eliminates the (potentially large) scheduling
        // latency that otherwise arises from adding the ready'd
        // goroutines to the end of the run queue.
        runnext guintptr

        // Available G's (status == Gdead)
        gFree struct {
                gList
                n int32
        }

        sudogcache []*sudog
        sudogbuf   [128]*sudog

        tracebuf traceBufPtr
         // traceSweep indicates the sweep events should be traced.
        // This is used to defer the sweep start event until a span
        // has actually been swept.
        traceSweep bool
        // traceSwept and traceReclaimed track the number of bytes
        // swept and reclaimed by sweeping in the current sweep loop.
        traceSwept, traceReclaimed uintptr

        palloc persistentAlloc // per-P to avoid mutex

        _ uint32 // Alignment for atomic fields below

        // Per-P GC state
        gcAssistTime         int64    // Nanoseconds in assistAlloc
        gcFractionalMarkTime int64    // Nanoseconds in fractional mark worker (atomic)
        gcBgMarkWorker       guintptr // (atomic)
        gcMarkWorkerMode     gcMarkWorkerMode

        // gcMarkWorkerStartTime is the nanotime() at which this mark
        // worker started.
        gcMarkWorkerStartTime int64

        // gcw is this P's GC work buffer cache. The work buffer is
        // filled by write barriers, drained by mutator assists, and
        // disposed on certain GC state transitions.
        gcw gcWork

        // wbBuf is this P's GC write barrier buffer.
        //
        // TODO: Consider caching this in the running G.
        wbBuf wbBuf

        runSafePointFn uint32 // if 1, run sched.safePointFn at next safe point

        pad cpu.CacheLinePad
}
```

字段中`mcache`再单独说明一下，源码`go/1.13.4/libexec/src/runtime/mcache.go`:
```go
// Per-thread (in Go, per-P) cache for small objects.
// No locking needed because it is per-thread (per-P).
//
// mcaches are allocated from non-GC'd memory, so any heap pointers
// must be specially handled.
//
//go:notinheap
```
`mcache`反映了对象的创建策略：小对象。