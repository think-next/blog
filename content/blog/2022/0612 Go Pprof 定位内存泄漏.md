---
title: "Go Pprof 定位内存泄漏"
date: "2022-06-12"
lead: "如何定位内存泄漏"
---
之前写过一篇 [`Go使用Pprof定位问题`](https://neojos.com/blog/2020/go%E4%BD%BF%E7%94%A8-pprof-%E5%AE%9A%E4%BD%8D%E9%97%AE%E9%A2%98/) , 内容主要是纠结 flat 和 cum 所表示的含义。重新去看了一遍，感觉还是挺特别的。虽然解释了名称的含义，但实际运用上却没有说出什么什么指导价值。

通过 pprof 可以查看CPU耗时以及内存分配情况，在结合火焰图，现在的工具确实方便了。

怎么使用 Pprof 定位内存泄漏呢？内存的结果中有申请的对象、使用中的对象两个大类，使用中的又细分成inuse_objects和inuse_space两个，结合这两个的Top详情，我们就可以观察到系统当前正在使用对象的情况。当然，通过单次的内存Pprof还是无法定位的，需要持续周期性地做系统内存观察，通过不同时间段的内存对比情况，非常容易发现有一部分方法中使用对象或者内存的指标是一直缓慢增长的。

如果发现某个方法的flat指标随着时间的推移，一直在不停地增长，那很多的可能就是这个方法导致的。总结一下：

1. 周期性分析内存Profile文件，查看Top正在使用中的对象、内存分配情况
2. 对比查看 flat 指标持续增长的函数或者方法

为什么是 flat 指标呢？flat 表示的是当前仍在调用没有被释放的空间，而cum表示累计申请的空间

为了加深大家的理解，我们主动去构造一个内存申请的用例（为了让代码看起来好看一些，我主动省略了error的处理逻辑，大家实验的时候，建议加上）。我们现在填充两种情况的代码，来主动观察 flat 和 cum 额变化情况。我们声明了一个全局变量 cacheBuf，来确保内存是在一直增长的。

```go
package main

import (
	"os"
	"runtime/pprof"
	"strings"
)

func main() {
	ff, _ := os.Create("mem.pprof")
	defer ff.Close()

	// 填充代码 
	ICaller()

	_ = pprof.WriteHeapProfile(ff)
}

var cacheBuf []string

func ICaller() {
	cacheBuf = append(cacheBuf, strings.Repeat("caller", 100))
	ISubCaller()
}

func ISubCaller() {

}

```

我们要对比的第二种情况，就是将 append 那一行的代码放到 ISubCaller方法中。通过对比两次的Top inuse_space情况，就可以直观了解到 flat 和 cum 的差别。建议大家主动试试，我就不把结果展示出来了。
