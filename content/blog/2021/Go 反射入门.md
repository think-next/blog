---
title: "Go 反射入门"
date: "2021-04-19"
lead: ""
---

针对文章中代码的行号，我都在试图和源码保持一致，但源码也在不停地迭代，无法做到 100% 一致，主要还是看一个参考，了解一个脉络。

### Indirect

通过下面的例子，我们来深入了解 `reflect` 数据包。我们定义 `People` 的结构体类型，来开始探索。

我们先来熟悉一下 `reflect.Indirect` 方法的使用。`reflect.Indirect` 返回的是底层的值类型，所以，下面第 12 行代码中调用 `Kind` 返回的类型为 `struct`。
而第 10 行代码输出结构体本身的 `Kind` 类型为 `ptr` 。

{{< highlight go "linenos=table,hl_lines=1-3 11-12,linenostart=1,style=abap,lineanchors=neojos" >}}
type People struct {
    Age int64
}

func main() {
    p := &People{
        Age: 30,
    }

  	fmt.Println(reflect.ValueOf(p).Kind())		// ouput: ptr
    value := reflect.Indirect(reflect.ValueOf(p))
  	fmt.Println(value.Kind())		// output: struct
}
{{< / highlight >}}

`Indriect` 英文的含义形容词 "间接的"。这算的上是 `reflect` 包中比较简单的方法了。间接和直接的区别在于是否使用到指针，因为 `Indirect`
返回的是指针指向的值。如果参数本身不是指针类型，那就不需要做额外处理。

{{< highlight go "linenos=table,hl_lines=1-3 11-12,linenostart=2339,style=abap,lineanchors=neojos" >}}
// Indirect returns the value that v points to.
// If v is a nil pointer, Indirect returns a zero Value.
// If v is not a pointer, Indirect returns v.
func Indirect(v Value) Value {
	if v.Kind() != Ptr {
		return v
	}
	return v.Elem()
}
{{< / highlight >}}

在哪里会用到 `Indirect` 方法呢？主要是用来操作底层的数据结构。常见的就是结构体，如果入参是一个指针，我们只有获取到底层的结构体，才可以应用结构体的各种操作方法。
诸如，获取结构体的值、标签等。

### Kind

我认为它算 `reflect` 包的灵魂之一了，虽然本质上只是 `uint` 的别名，但它本身的信息却足够巨大。整个 Go 的基础数据类型都在这里了。工程代码中我们会声明各种类型的结构体，
比如示例代码中的 `People` 类型，它的 `Kind` 类型就是 `Struct`。

{{< highlight go "linenos=table,hl_lines=1-2,linenostart=230,style=abap,lineanchors=neojos" >}}
// A Kind represents the specific kind of type that a Type represents.
// The zero Kind is not a valid kind.
type Kind uint

const (
	Invalid Kind = iota
	Bool
	Int
	Int8
	Int16
	Int32
	Int64
	Uint
	Uint8
	Uint16
	Uint32
	Uint64
	Uintptr
	Float32
	Float64
	Complex64
	Complex128
	Array
	Chan
	Func
	Interface
	Map
	Ptr
	Slice
	String
	Struct
	UnsafePointer
)
{{< / highlight >}}

知道这些有什么用呢？关键的一点，判断入参的类型，究竟是结构体、还是指针、或者别的类型。在框架类的代码中，经常有这种类型判断。简单举例说明一下：

本质上讲，Go 语言中不外乎这两种定义类型的方式。

{{< highlight go "linenos=table,hl_lines=,linenostart=1,style=abap,lineanchors=neojos" >}}
type IString string
type YString = string
{{< / highlight >}}

`IString` 算是重新声明一个新的类型，它和 `string` 必须强制转换。`YString` 是类型的一个别名，
本身和 `string` 类型就是完全相同的。项目代码中，其实存在很多像 `IString` 这样的类型，最常见的就是结构体声明。

如果我们直接通过安全断言的方式来判断类型的话， 势必要写很多的条件语句，而通过 `Kind` 就不需要这么麻烦。 因为自定义的类型是无限的，而底层的数据类型是有限的。

### Type

反射的 `ValueOf` 和 `TypeOf` 函数是使用反射的入口，分别对应于接口类型的具体值和动态类型。下面的例子中，
第 5 行代码调用 `People` 对象 `Value` 的 `Type` 和第 6 行代码直接获取的 `Type` 做比较，输出值是相同的。

{{< highlight go "linenos=table,hl_lines=5-6,linenostart=1,style=abap,lineanchors=neojos" >}}
	p := &People{
        Age: 30,
    }

    valueType := reflect.ValueOf(p).Type()
    dynamicType := reflect.TypeOf(p)
    if valueType == dynamicType {
      	fmt.Println("equal")		// output: equal
    }
{{< / highlight >}}

一些博客文章介绍了反射类型的转换关系，`Value`、`Type`、`interface` 三种类型之间相互转换。这个例子侧面说明了 `Value` 和 `Type` 的转换，但在源码的实现上，
通过调用 `Value` 类型的 `Type` 方法和直接使用 `TypeOf` 差别其实挺大的。

如果对底层的实现细节不清楚，这个转换关系其实挺让人困惑的。这究竟是一个"恒等式"，还是只针对某些具体的类型，这样的转换才成立。我其实就特别困惑，
我不仅仅是困惑 `Value` 类型到 `Type` 类型的转换，还困惑通过直接调用 `TypeOf` 获取 `Type` 和通过调用 `ValueOf` 获取 `Type` 两者的效率差异。

#### TypeOf

`TypeOf`的逻辑比较简单，通过使用 `unsafe` 包将接口类型强转一个 `emptyInterface` 类型，然后直接返回 `emptyInterface` 类型的 `typ` 属性。

{{< highlight go "linenos=table,hl_lines=,linenostart=1366,style=abap,lineanchors=neojos" >}}
// TypeOf returns the reflection Type that represents the dynamic type of i.
// If i is a nil interface value, TypeOf returns nil.
func TypeOf(i interface{}) Type {
	eface := *(*emptyInterface)(unsafe.Pointer(&i))
	return toType(eface.typ)
}
{{< / highlight >}}

`TypeOf` 函数很简单，我们只需要查看 `emptyInterface` 的类型定义，然后查看这个类型的 `typ` 属性来确认 `Type`。另一个细节就是 `toType` 方法，
也需要进去函数看一看具体的实现。

`interface` 被大家分成两类来区分，空接口和非空接口，下面看到的就是空接口 `emptyInterface` 的类型声明。`typ` 指向具体的类型，而 `word` 指向具体值的地址。
我们也可以看出，默认将某一个具体类型转换成 `interface` 类型，系统还是做了很多转换工作的。

{{< highlight go "linenos=table,hl_lines=,linenostart=193,style=abap,lineanchors=neojos" >}}
// emptyInterface is the header for an interface{} value.
type emptyInterface struct {
	typ  *rtype
	word unsafe.Pointer
}
{{< / highlight >}}

深入 `toType` 方法看一下源码实现，注释其实挺丰富的，我却只能看懂字面意思。但从功能上讲，代码的作用很简单，当入参为 `nil` 时，直接返回 `nil`。
因为返回值类型 `Type` 是一个接口类型，针对接口类型来说，返回 `*rtype` 类型的 `nil` 和 `nil` 可完全是两码事。

{{< highlight go "linenos=table,hl_lines=,linenostart=2968,style=abap,lineanchors=neojos" >}}
// toType converts from a *rtype to a Type that can be returned
// to the client of package reflect. In gc, the only concern is that
// a nil *rtype must be replaced by a nil Type, but in gccgo this
// function takes care of ensuring that multiple *rtype for the same
// type are coalesced into a single Type.
func toType(t *rtype) Type {
	if t == nil {
		return nil
	}
	return t
}
{{< / highlight >}}

#### ValueOf

下面是源码中 `Value`转`Type`的方法。示例代码中，方法运行到注释为`Easy case`的逻辑里就直接返回了，后续的其他逻辑并没有执行到。

疑问的是，`flagMethod`是如何设置到`v.flag`上的呢？

查看源码，通过`ValueOf`方法设置的`flag`是无法把`flagMethod`指定的`bit`位设置成1的。`flagMethod`的常量定义:`flagMethod      flag = 1 << 9`，把1右移9位，在`reflect.ValueOf`中并没有做这样的逻辑处理。

{{< highlight go "linenos=table,hl_lines=8-9,linenostart=1904,style=abap,lineanchors=neojos" >}}
// Type returns v's type.
func (v Value) Type() Type {
	f := v.flag
	if f == 0 {
		panic(&ValueError{"reflect.Value.Type", Invalid})
	}
	if f&flagMethod == 0 {
		// Easy case
		return v.typ
	}

	// Method value.
	// v.typ describes the receiver, not the method type.
  // 获取方法的下标
	i := int(v.flag) >> flagMethodShift
	if v.typ.Kind() == Interface {
		// Method on interface.
		tt := (*interfaceType)(unsafe.Pointer(v.typ))
		if uint(i) >= uint(len(tt.methods)) {
			panic("reflect: internal error: invalid method index")
		}
		m := &tt.methods[i]
		return v.typ.typeOff(m.typ)
	}
	// Method on concrete type.
	ms := v.typ.exportedMethods()
	if uint(i) >= uint(len(ms)) {
		panic("reflect: internal error: invalid method index")
	}
	m := ms[i]
	return v.typ.typeOff(m.mtyp)
}
{{< / highlight >}}

上述`Easy case`之后的逻辑该如何触发呢？

通过方法的名称，我们还是可以隐约猜测到，它可能是一个方法的 `Value`。我们给 `People`对象追加一个方法，获取方法的`Value`对象，然后通过这个对象获取`Type`。代码的调整如下：

```go
type People struct {
    Age int64
}

func (p *People) Describe() {
    fmt.Println("people age:", p.Age)
}

func main() {
    p := &People{
        Age: 30,
    }

    methodType := reflect.ValueOf(p).MethodByName("Describe").
        Type()
    fmt.Println(methodType)
}
```

通过断点调试，这样处理后，确实触发了`Easy case`之后的逻辑。

那么，`MethodByName`具体做了什么操作呢？

```go
// MethodByName returns a function value corresponding to the method
// of v with the given name.
// The arguments to a Call on the returned function should not include
// a receiver; the returned function will always use v as the receiver.
// It returns the zero Value if no method was found.
func (v Value) MethodByName(name string) Value {
	if v.typ == nil {
		panic(&ValueError{"reflect.Value.MethodByName", Invalid})
	}
	if v.flag&flagMethod != 0 {
		return Value{}
	}
	m, ok := v.typ.MethodByName(name)
	if !ok {
		return Value{}
	}
	return v.Method(m.Index)
}
```

在 `Method`方法中，重新创建了返回的`Value`,并对 `flag`做好了标志位。

```go
// Method returns a function value corresponding to v's i'th method.
// The arguments to a Call on the returned function should not include
// a receiver; the returned function will always use v as the receiver.
// Method panics if i is out of range or if v is a nil interface value.
func (v Value) Method(i int) Value {
	if v.typ == nil {
		panic(&ValueError{"reflect.Value.Method", Invalid})
	}
	if v.flag&flagMethod != 0 || uint(i) >= uint(v.typ.NumMethod()) {
		panic("reflect: Method index out of range")
	}
	if v.typ.Kind() == Interface && v.IsNil() {
		panic("reflect: Method on nil interface value")
	}
	fl := v.flag.ro() | (v.flag & flagIndir)
	fl |= flag(Func)
	fl |= flag(i)<<flagMethodShift | flagMethod
	return Value{v.typ, v.ptr, fl}
}
```

