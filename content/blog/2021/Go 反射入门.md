---
title: "Go 反射入门"
date: "2021-04-19"
lead: ""
---

通过下面的例子，我们来深入了解 `reflect` 数据包。我们定义`People`的结构体类型，来开始探索。


{{< highlight go "linenos=table,hl_lines=2 4-7,linenostart=1,style=abap,lineanchors=neojos" >}}
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

上面这个例子，`reflect.Indirect` 返回的是底层的值类型，所以，调用`Kind`返回的类型为 `struct`。而它本身的 `Kind` 类型为`ptr`。查看源码中  `Kind` 的数据类型定义。通过这些常量的声明，可以帮助我们理解 Go 的基础类型。

```go
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
```

反射的 `ValueOf` 和 `TypeOf`是应用反射的入口，对应于接口类型的具体值和它的动态类型。下面这个例子中，我们拿`People`对象`Value`的`Type`和直接获取的`Type`做比较，输出值是相同的。

```go
 		p := &People{
        Age: 30,
    }

    valueType := reflect.ValueOf(p).Type()
    dynamicType := reflect.TypeOf(p)
    if valueType == dynamicType {
      	fmt.Println("equal")		// output: equal
    }
```

仅仅通过这个例子，我们还无法确定：Go 中其他数据类型 `Value`结果的`Type`和类型的`Type`一定是相等的。我们深入到源码层面上，发现两者的实现是有很大差异的。

`TypeOf`的逻辑相对简单些，强转一个 `emptyInterface`类型，返回`emptyInterface`类型的`typ`属性。而 `ValueOf().Type()`就显得比较复杂。

```go
// TypeOf returns the reflection Type that represents the dynamic type of i.
// If i is a nil interface value, TypeOf returns nil.
func TypeOf(i interface{}) Type {
	eface := *(*emptyInterface)(unsafe.Pointer(&i))
	return toType(eface.typ)
}
```

下面是源码中 `Value`转`Type`的方法。示例代码中，方法运行到注释为`Easy case`的逻辑里就直接返回了，后续的其他逻辑并没有执行到。

疑问的是，`flagMethod`是如何设置到`v.flag`上的呢？

查看源码，通过`ValueOf`方法设置的`flag`是无法把`flagMethod`指定的`bit`位设置成1的。`flagMethod`的常量定义:`flagMethod      flag = 1 << 9`，把1右移9位，在`reflect.ValueOf`中并没有做这样的逻辑处理。

```go
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
```

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

