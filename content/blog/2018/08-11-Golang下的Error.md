---
title: Golang下的Error

date: 2018-08-11

tags: [golang]

author: 付辉

---

感觉`error`确实没啥可说的，这个简单到极致的`package`总共也不超过10行有效代码。而且常用的`fmt`也提供了很方便的返回`error`的方法：

```golang
// Package errors implements functions to manipulate errors.
package errors

// New returns an error that formats as the given text.
func New(text string) error {
	return &errorString{text}
}

// errorString is a trivial implementation of error.
type errorString struct {
	s string
}

func (e *errorString) Error() string {
	return e.s
}
```


## 自定义`error`

`error`设计的如此简单，导致其判断错误类型就比较麻烦。比如我想判断`MySQL`的报错是否由主键冲突导致，我可以这样处理：

```
const PrimaryKeyDuplicateCode = "1062"
if strings.Contains(err.Error(), PrimaryKeyDuplicateCode) {
	//commands
}
```

这样的判断逻辑，如果仅是用于特殊情况，还勉强可以接收。但如果你要整个项目都使用这种形式的话，就会觉得精神崩溃，心理无法承受（反正我是这样感觉的）。所以，我们要自定义实现一个`Error`结构。当然，这样搞还有`syscall`这个`package`。

实现自定义的`Error`非常简单，我们要`Error`里面包含状态码、错误描述、上下文数据，然后实现`error`接口就可以。

```golang
type error interface {
	Error() string
}
```

下面便是我们自定义的`error`，`Data`用来存储错误的上下文信息。当然，我们其实可以为`Data`专门定义新的结构类型，由它来封装数据的操作。然后，我们实现了`Error`方法，以此来实现`error`接口。该方法返回`json`编码的字符串，如果`json`编码失败，则`fmt`输出。
```
type CustomError struct {
	Code int
	Msg  string
	Data map[string]interface{}
}

unc (e *CustomError) Error() string {
	data, err := json.Marshal(e)
	if err == nil {
		//return fmt.Sprintf("%v", e.Msg)
		return fmt.Sprintf("%v", e)
	}
	return string(data)
}
```

你有没有发现这段代码隐藏了一个大坑！`fmt.Sprintf("%v", e)`这段代码背后到底执行了怎样的操作。下面便是可能会出现的错误：

```
runtime: goroutine stack exceeds 1000000000-byte limit
fatal error: stack overflow
```

无限的递归最终导致栈溢出，当`err != nil`的时候，便会无限次的调用`Error`方法，最终导致了栈溢出。结果就是程序彻底崩溃了。下面来看`fmt.Sprintf`的方法实现：

```
// If a string is acceptable according to the format, see if
// the value satisfies one of the string-valued interfaces.
// Println etc. set verb to %v, which is "stringable".
switch verb {
case 'v', 's', 'x', 'X', 'q':
	// Is it an error or Stringer?
	// The duplication in the bodies is necessary:
	// setting handled and deferring catchPanic
	// must happen before calling the method.
	switch v := p.arg.(type) {
	case error:
		handled = true
		defer p.catchPanic(p.arg, verb)
		// 如果是error类型，调用其Error方法
		p.fmtString(v.Error(), verb)
		return

	case Stringer:
		handled = true
		defer p.catchPanic(p.arg, verb)
		p.fmtString(v.String(), verb)
		return
	}
}
```

## 判断`Error`是否为`nil`

`go`中相当常见的判断，估计就是`err != nil`了。它遵循`提前退出`的原则，当`err`不为空是，函数体就应立即中断，然后返回（当然也有特殊的了，就比如`io.EOF`）。但如果你没有好好推敲过`err != nil`这个比较逻辑的话，很可能就会吃点小亏。

通过一个简化版的例子，来说明问题。首先，声明一个函数，返回自定义的`error`。当`errSwitch`设置为`false`时，返回`nil`。

```
func returnCustomError(errSwitch bool) *CustomError {

	if errSwitch == true {
		return &CustomError{
			Data: make(map[string]interface{}, 0),
		}
	}

	return nil
}
```

之后再声明另外一个函数，返回`error`接口类型，内部调用`returnCustomError`函数：
```
func returnOfficialError() error {
	return returnCustomError(false)
}

func main() {
    //比较
	if returnOfficialError() != nil {
		fmt.Println("err is not equal to nil")
	} else {
		fmt.Println("err is equal to nil")
	}
}

//output
//err is not equal to nil
```

是不是挺奇怪的，我明明返回了一个`nil`，但最后判断的结果却`!= nil`。问题出在`interface`类型的比较上，它会比较`interface type`和`interafce value`，只有两者均为`nil`，最终结果才为`nil`。

## `interface`比较

`Go`语言中，变量均会被初始化为预定义的零值，`interface`也不例外。但`interface`的零值却由两部分组成：`dynamic type`和`dynamic value`，只有两者均为`nil`，最终结果才为`nil`。

从上面都示例也可以看出，`interface`是可以比较的。所以，`interface`类型也可以作为`map`类型的`key`值。但如果`interface`中的`dynamic type`本身是不可比较的，比如`slice`、`map`、`function`，强行比较的话，就会引起`panic`。因此，在比较`interface`之前，一定要确定`dynamic type`是可以比较的。

## 总结

在项目中，函数的`error`返回类型尽量要做到统一，要么所有的函数均返回`error interface`类型（建议），要么返回自定义的类型。这样可以避免上述的情况。在处理特殊`error`的类型时，使用断言来做特殊处理。
```golang
//使用断言来判断错误的类型
if err, ok := err.(*CustomError); ok {
    
}
```