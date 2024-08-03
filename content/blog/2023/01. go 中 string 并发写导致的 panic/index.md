---
title: go 中 string 并发写导致的 panic

date: 2023-01-29

author: 付辉

---

## 类型的一点变化

在Go语言的演化过程中，引入了`unsafe.String`来取代之前的`StringHeader`结构体，这是为了提供更安全和简洁的字符串操作方式。

### 旧设计 (`StringHeader` 结构体)

 `StringHeader`注释发生了一点变动，被标注了 Deprecated，通过询问 GPT 得出了下面的内容。

旧的设计中，`StringHeader` 结构体被用来手动管理字符串的底层数据。这种方式虽然灵活，但涉及大量的`unsafe`操作，容易引发潜在的安全问题和内存泄露。

```go
package runtime

// Deprecated: Use unsafe.String or unsafe.StringData instead.
type StringHeader struct {
	Data uintptr
	Len int
}
```

### 新设计 (`unsafe.String` 方法)

新的设计引入了`unsafe.String`方法，这是一个高层次的封装，减少直接操作指针的需求，同时仍然保留了灵活性和性能。这种设计主要有以下几个优点：

```go
// String returns a string value whose underlying bytes
// start at ptr and whose length is len.
//
// The len argument must be of integer type or an untyped constant.
// A constant len argument must be non-negative and representable by a value of type int;
// if it is an untyped constant it is given type int.
// At run time, if len is negative, or if ptr is nil and len is not zero,
// a run-time panic occurs.
//
// Since Go strings are immutable, the bytes passed to String
// must not be modified afterwards.
func String(ptr *byte, len IntegerType) string
```

1. **减少直接操作指针的风险**: 通过提供高层次的接口，开发者不再需要手动操作指针，这大大降低了出错的风险以及潜在的安全漏洞。
    
2. **更简洁地表达意图**: 使用方法而不是结构体，使得代码读起来更简洁，意图更清晰。
    
3. **内建更好的错误检查**: 封装在方法内部，可以内建一些基本的错误检查和约束，进一步提升代码的安全性和健壮性。

## panic 触发回放

按照旧的数据结构来构造变量，Len 的部分设置为 16，Data 所指的内存数据设置为 nil，把结构体的内存位置和字符串的内存对应起来，再通过 unsafe 进行类型强转。

main 方法中变量 name 金玉其外败絮其中，你在访问它的时候就会触发 panic。sonic 三方库属于结构体序列化的高性能库。

```go
type mock struct {  
    bytes uintptr  
    len   int  
}  
  
func BytesToString() string {  
    var ee *int  
    ptr := unsafe.Pointer(ee)  
    var s = mock{bytes: uintptr(ptr), len: 16}  
    return *(*string)(unsafe.Pointer(&s))  
}

func main() {  
    name := BytesToString()  
    if res, err := sonic.Marshal(name); err != nil {  
       fmt.Errorf("sonic marshal error: %v", err)  
    } else {  
       fmt.Println(len(res), string(res))  
    }
}
```

![panic](panic.png)