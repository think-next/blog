---
title: Go Interface 类型

date: 2018-10-12

tags: [golang]

author: 付辉

---

## `introduction`

[`duck typing`](https://en.wikipedia.org/wiki/Duck_typing) 很形象的解释了`interface`的本意。它是一种特别的数据类型，内部声明了一组要实现的方法集合，任何实现了这些方法的数据类型都可以认为实现了这个`interface`。这跟其他语言中的`抽象类`有异曲同工之处，但却不需要去明确声明实现这个`interface`。

空的`interface`类型没有声明任何方法，所以`GO`中所有数据类型都实现了`interface{}`。这也为我们实现`泛型编程`提供了可能，虽然使用起来并不舒服。

## `protocol`

`interface`可以做为一组不相关的对象进行交流的一种规范或约束，类比[`protobuf`](https://developers.google.com/protocol-buffers/)，数据字段必须严格按照声明进行传递。只不过`interface`约束的是待实现的方法。

比如`error`接口，所有实现了`Error()`方法的类型都可以赋值给`error`类型变量，无需明确声明继承关系，就实现了`多态`。

```golang
// The error built-in interface type is the conventional interface for
// representing an error condition, with the nil value representing no error.
type error interface {
	Error() string
}
```

## `interface`

### `generic algorithm`

`interface`类型接受任意类型的参数，结合`reflect`或者`断言`可以确定参数的实际类型。比如`fmt`包就有这样用（具体需要深入方法内部）：

```golang
// Println formats using the default formats for its operands and writes to standard output.
// Spaces are always added between operands and a newline is appended.
// It returns the number of bytes written and any write error encountered.
func Println(a ...interface{}) (n int, err error) {
	return Fprintln(os.Stdout, a...)
}
```

通过`interface`约束一套行为，也可以实现泛型编程。比如`sort`包，只要实现了接口对应的方法，就可以使用`sort`包来进行排序。具体如何排序，操作什么数据类型，都由你自己来实现。要实现的方式依次是：获取集合的长度，两个元素比较大小以及如何交换两个元素。

```
// A type, typically a collection, that satisfies sort.Interface can be
// sorted by the routines in this package. The methods require that the
// elements of the collection be enumerated by an integer index.
type Interface interface {
	// Len is the number of elements in the collection.
	Len() int
	// Less reports whether the element with
	// index i should sort before the element with index j.
	Less(i, j int) bool
	// Swap swaps the elements with indexes i and j.
	Swap(i, j int)
}
```

### `hiding implement detail`

当函数返回一个具体类型的`interface`，那么你就能调用`interface`实现的方法，而内部的具体实现可以一无所知。尤其是提供一个默认的接口实现时，就显得更加方便了。


### `providing interception points`

#### `Unmarshal`

当使用`Unmarshal`解析`json`时，为具体的类型实现[`Unmarshaler`](https://golang.org/pkg/encoding/json/#Marshaler)接口，就实现了自定义解析。

>`To unmarshal JSON into a value implementing the Unmarshaler interface, Unmarshal calls that value's UnmarshalJSON method, including when the input is a JSON null.`

```
// Unmarshaler is the interface implemented by types
// that can unmarshal a JSON description of themselves.
// The input can be assumed to be a valid encoding of
// a JSON value. UnmarshalJSON must copy the JSON data
// if it wishes to retain the data after returning.
//
// By convention, to approximate the behavior of Unmarshal itself,
// Unmarshalers implement UnmarshalJSON([]byte("null")) as a no-op.
type Unmarshaler interface {
	UnmarshalJSON([]byte) error
}
```

当然还有`Marshaler`接口，按照自己的想法去解析`json`
```
 type Marshaler interface {
    MarshalJSON() ([]byte, error)
}
```

#### `Handler`

通过实现`Handler`接口，来处理不同的请求。

```
// A Handler responds to an HTTP request.
//
// ServeHTTP should write reply headers and data to the ResponseWriter
// and then return. Returning signals that the request is finished; it
// is not valid to use the ResponseWriter or read from the
// Request.Body after or concurrently with the completion of the
// ServeHTTP call.

type Handler interface {
	ServeHTTP(ResponseWriter, *Request)
}
```

`ServeMux`也实现了`handler`接口，但它基于`request`实现了一个路由表。

```
// ServeHTTP dispatches the request to the handler whose
// pattern most closely matches the request URL.
func (mux *ServeMux) ServeHTTP(w ResponseWriter, r *Request) {
	if r.RequestURI == "*" {
		if r.ProtoAtLeast(1, 1) {
			w.Header().Set("Connection", "close")
		}
		w.WriteHeader(StatusBadRequest)
		return
	}
	h, _ := mux.Handler(r)
	h.ServeHTTP(w, r)
}

```

## Stream IO interface

工作中最常见的两个接口，io.Reader和io.Writer。

```
type Reader interface {
    Read(p []byte) (n int, err error)
}
```

Read方法通过for循，结合io.EOF的方式，将读取到的数据写入到参数p中。Write方法将p中的数据写入到实现的对象里。

```
type Writer interface {
    Write(p []byte) (n int, err error)
}
```

实现了Reader和Writer接口类型包括但不限于：
- os.File
- os.Stdout
- os.Stdin
- os.Stderr

---

参考文章：

1. [`Go Data Structures: Interfaces`](https://research.swtch.com/interfaces)
2. [`https://zhuanlan.zhihu.com/p/32926119`](https://zhuanlan.zhihu.com/p/32926119)