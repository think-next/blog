---
title: Go test基础用法

date: 2018-05-02

categories: [2018-05]

tags: [golang]

author: 付辉

---

> 当直接使用`IDE`进行单元测试时，有没有好奇它时如何实现的？比如`GoLand`写的测试用例。

所有的代码都需要写测试用例。这不仅仅是对自己的代码负责，也是对别人的负责。

最近工作中使用`glog`这个库，因为它对外提供的方法都很简单，想封装处理一下。但却遇到了点麻烦：这个包需要在命令行传递`log_dir`参数，来指定日志文件的路径。

所以，正常运行的话，首先需要编译可执行文件，然后命令行指定参数执行。如下示例：
```
go build main.go
./main -log_dir="/data"    //当前目录作为日志输出目录
```

但在`go test`的时候，如何指定这个参数了？

调查发现，发现`go test`也可以生成可执行文件。需要使用`-c`来指定。示例如下：
```
go test -c param_test_dir   //最后一个参数是待测试的目录
```

执行后就会发现：这样的做法，会运行所有的`Test`用例。如何仅仅执行某一个测试用例了（编译器到底是如何做到的？）。

这里有另一个属性`-run`，用来指定执行的测试用例的匹配模式。举个例子：
```
func TestGetRootLogger(t *testing.T) {
	writeLog("测试")
}

func TestGetRootLogger2(t *testing.T) {
	writeLog("测试2")
}
```
当我在命令行明确匹配执行`Logger2`，运行的时候确实仅仅执行该测试用例
```
go test -v -run Logger2 ./util/     //-v表示verbose，输出相信信息
```

但是，我发现，在指定了`c`参数之后，`run`参数无法生效！这样的话，还真是没有好的办法来处理这种情况。

## `Benchmark`测试

关于如何运行`Benchmark`测试，默认执行`go test`并不会执行`Benchmark`，需要在命令行明确加上`-bench=标记`，它接受一个表达式作为参数，匹配基准测试的函数，.表示运行所有基准测试。
```
go test -bench=.

// 明确指定要运行那个测试，传递一个正则表达式给run属性
go test -run=XXX -bench=.
```

默认情况下，`benchmark`最小运行时长为`1s`。如果`benchmark`函数执行返回，但`1s`的时间还没有结束，`b.N`会根据某种机制依次递增。可以通过参数`-benchtime=20s`来改变这种行为。

还有一个参数：`benchmem`。可以提供每次操作分配内存的次数，以及每次操作分配的字节数。

```go
go test -bench=Fib40 -benchtime=20s
```

## 覆盖率

跟执行`go test`不同的是，需要多加一个参数`-coverprofile`,所以完整的命令：

```
go test -v -coverprofile=c.out
```

生成报告有go为我们提供的工具，使用
```
go tool cover -html=c.out -o=tag.html
```

即可生成一个名字为tag.html的HTML格式的测试覆盖率报告，这里有详细的信息告诉我们哪一行代码测试到了，哪一行代码没有测试到。

参考文章：

1. [Go 单元测试](http://www.flysnow.org/2017/05/16/go-in-action-go-unit-test.html)

