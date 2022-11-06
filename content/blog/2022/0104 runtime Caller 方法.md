---
title: "runtime Caller 方法"
date: "2022-01-04"
lead: ""
index: true
---

在 [Go单元测试——资源初始化](https://juejin.cn/post/7121103084532531214) 里获取配置文件的绝对路径时，提到了 Caller 方法。这个方法在日志打印的包中特别常见。
日志文件中记录的文件路径和行号，就是这个函数的返回值。

```go
pc, file, line, ok := runtime.Caller(0)
```

翻看一些日志的开源包，可能就会看到这个方法的调用。如果全局没有搜索到的话，很可能是它组合调用了类似下面的自定义方法，想要获取更多的调用栈信息。对比 runtime.Caller
源码和我们自定义的 GetCallerFrame 方法，它们内部实现逻辑是完全一致的，只是返回值上做了处理。

```go
func GetCallerFrame(skip int) runtime.Frame {
	rpc := make([]uintptr, 1)

	n := runtime.Callers(skip, rpc[:])
	if n < 1 {
		return runtime.Frame{}
	}

	frame, _ := runtime.CallersFrames(rpc).Next()
	return frame
}
```

通过 runtime.Frame 可以获取到调用栈的方法体信息，通过 frame.Function 我们可以获取很多有用的信息，比如当前调用的函数名、文件的路径、结构体的名称。如果你看过 panic
输出的调用栈信息的话，调用栈信息中显示的函数就是 frame.Function 。