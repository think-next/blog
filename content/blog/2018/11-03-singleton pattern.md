---
title: singleton pattern

date: 2018-11-03

tags: [golang]

author: 付辉

---

*<u>版本 0.02</u>*

在服务运行期间，针对所有`goroutine`共用一份数据的情况，比如配置信息，都可以选择只读取一次配置文件。但还是要特别注意：

1. **单例中不要保存只属于具体的`goroutine`的数据**，否则会出现相互覆盖的情况。
2. 单例中使用的**具体业务数据**要通过参数的形式传递，避免有成员变量存在。

单例也是[`Lazy Initialization`](https://docs.microsoft.com/en-us/dotnet/framework/performance/lazy-initialization)的一种，对于经常不使用的变量，只有在使用的时候才进行实例化，整体来说，还是节约资源的。

或者类似[`net/http`](https://godoc.org/net/http)中的`client`这种类型：

> Clients and Transports are safe for concurrent use by multiple goroutines and for efficiency should only be created once and re-used.

## `sync.Once`简介

`Go`语言通过`sync`包可以方便的实现线程安全的单例模式。最叹为观止的是，`sync`包的实现如此简单。通常用来处理在服务运行期间，只需要初始化一次的变量。

```
// Once is an object that will perform exactly one action.
type Once struct {
	m    Mutex
	done uint32
}

func (o *Once) Do(f func()) {
	if atomic.LoadUint32(&o.done) == 1 {
		return
	}
	// Slow-path.
	o.m.Lock()
	defer o.m.Unlock()
	if o.done == 0 {
		defer atomic.StoreUint32(&o.done, 1)
		f()
	}
}
```

## `sync.Once`设计思路

举个例子：

下面声明统一获取配置类的函数，因为配置信息在整个服务运行期间是不会发生改变的。函数通过判断`config`是否被初始化，来达到只初始化一次的目的。例子中`config`声明为`map`的数据结构，来存储配置信息（`map`不支持并发访问，这里先忽略）。

```
package encrypt_config

//key-secret pairs
var config map[string]string

func loadConfig(name string) string {
	if config == nil {
		config = map[string]string{
			"zi-ru": "Mji9##a0LY",
			"baidu": "Kj8*0okhHH",
		}
	}
	return config[name]
}
```

代码最显而易见的问题：并发的情况下，包内变量`config`被初始化多次。因为各个`goroutine`访问`config`时可能都是`nil`。

但还存在一种可能的情况：`goroutine B`发现`config ！= nil`，但是当通过`name`去获取对应的值时，返回的却是空字符串。也就是说`goroutine A`访问到了一个没有被完全初始化的`config`

### `reason`

`Go`在执行上述方法的时候，编译器在不影响最终结果的情况下，本身可以调整代码执行的顺序。这也是现在计算机多核处理，共享内存必然要面临的情况。比如编译器做了如下调整：

```
func loadConfig(name string) string {
	if config == nil {
	
	    //goroutine B 访问的时候，config刚被初始化 
	    config = make(map[string]string)
	    config["zi-ru"] = "Mji9##a0LY"
	    config["baidu"] = "Kj8*0okhHH"
	}
	return config[name]
}
```

问题的本质在于：**`goroutine B`访问到了第一个`goroutine A`正在初始化的变量**。而`sync`通过声明`done`标识，在配合`Mutex`锁，巧妙的实现了隔离。保证在`config`在初始化过程中，别的`goroutine`是不可访问的。

下面是在 [`双重检查锁定与延迟初始化`](https://www.infoq.cn/article/double-checked-locking-with-delay-initialization) 的一段内容：

>根据《The Java Language Specification, Java SE 7 Edition》（后文简称为 java 语言规范），所有线程在执行 java 程序时必须要遵守 intra-thread semantics。intra-thread semantics 保证重排序不会改变单线程内的程序执行结果。换句话来说，intra-thread semantics 允许那些在单线程内，不会改变单线程程序执行结果的重排序。


## `lock`

`Lock`

```
// Lock locks m.
// If the lock is already in use, the calling goroutine
// blocks until the mutex is available.
func (m *Mutex) Lock() {
	// Fast path: grab unlocked mutex.
	if atomic.CompareAndSwapInt32(&m.state, 0, mutexLocked) {
		if race.Enabled {
			race.Acquire(unsafe.Pointer(m))
		}
		return
	}
    ......
```

---

参考文章：

1. [`双重检查锁定与延迟初始化`](https://www.infoq.cn/article/double-checked-locking-with-delay-initialization)