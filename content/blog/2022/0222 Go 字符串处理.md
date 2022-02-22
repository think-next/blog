---
title: "Go 字符串处理"
date: "2022-02-22"
lead: ""
index: true
---

> 当你有效花钱时，就等于有效地利用了社会资源，而利用了社会资源，就有可能获得更多的钱，这是一个良性循环，这时钱的意义才体现出来

工程中会存在很多字符串处理的场景，比如 `SQL` 语句拼接，脚手架生成代码等。经常使用到的类型也就那么多，熟练使用它们能极大帮助我们编程

## strings.Builder

我们首先还是看源码注释的说明，`Builder` 非常方便持续向 `Writer` 中写入数据，当我们将构造目标内容拆分成好几步的时候，使用它就非常方便。在第三方库 `xorm` 构造 `SQL` 语句时也有使用到。

{{< highlight go "linenos=table,hl_lines=0,linenostart=12,style=black,lineanchors=neojos" >}}
// A Builder is used to efficiently build a string using Write methods.
// It minimizes memory copying. The zero value is ready to use.
// Do not copy a non-zero Builder.
type Builder struct {
	addr *Builder // of receiver, to detect copies by value
	buf  []byte
}
{{< / highlight >}}

类型了解之后，我们需要知道该如何在工程中使用它，通过看它自身的方法其实就可以了解到。因为实在没什么特别强调的，就简单写一下示例。

第三方的项目中，我们也很难看到直接调用 `WriteString` 的情况。`Builder` 实现的 `io.Writer` 接口，而我们也多被要求面向接口编程

```go
func main() {
	b := strings.Builder{}
	b.WriteString("hello")
	b.WriteString(" ")
	b.WriteString("neojos")
	fmt.Println(b.String())
  // 输出 hello neojos
}
```

