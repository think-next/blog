---
title: Using context cancellation in Go

date: 2019-06-22

categories: 2019-06

tags: [golang]

author: 付辉
---

文章介绍最近工作中遇到的一个问题，其中50%以上的内容都是Go的源代码。剩下部分是自己的理解，如果有理解错误或探讨的地方，希望大家指正。

问题：针对同一个接口请求，绝大多数都可以正常处理，但却有零星的几请求老是处理失败，错误信息返回 `context canceled`。重放失败的请求，错误必现。

根据返回的错误信息，再结合我们工程中使用的`golang.org/x/net/context/ctxhttp`包。猜测可能是在请求处理过程中，异常调用了`context` 包的`CancelFunc`方法。同时，我们对比了失败请求和成功请求的区别，发现失败请求的`Response.Body`数据量非常大。

之后在Google上找到了问题的原因，还真是很容易被忽略，这里是文章的链接：[Context cancellation flake](https://groups.google.com/forum/#!topic/golang-nuts/2FKwG6oEvos)。为了解决未来点进去404的悲剧，本文截取了其中的代码...

## Code

代码核心逻辑：向某个地址发送`Get`请求，并打印响应内容。其中函数`fetch`用于发送请求，`readBody`用于读取响应。例子中处理请求的逻辑结构，跟我们项目中的完全一致。

`fetch`方法中使用了默认的`http.DefaultClient`作为`http Client`，而它自身是一个“零值”，并没有指定请求的超时时间。所以，例子中又通过`context.WithTimeout`对超时时间进行了设置。

代码中使用`context.WithTimeout`来取消请求，存在两种可能情况。第一种，处理的时间超过了指定的超时时间，程序返回`deadlineExceededError`错误，错误描述`context deadline exceeded`。另一种是手动调用`CancelFunc`方法取消执行，返回`Canceled`错误，描述信息`context canceled`。

在`fetch`代码的处理逻辑中，当程序返回`http.Response`时，会执行`cancel()`方法，用于标记请求被取消。如果在`readBody`没读取完返回的数据之前，`context`被cancel掉了，就会返回`context canceled`错误。侧面也反映了，关闭`Context.Done()`与读取`http.Response`是一个时间赛跑的过程…..

```go
package main

import (
    "context"
    "io/ioutil"
    "log"
    "net/http"
    "time"

    "golang.org/x/net/context/ctxhttp"
)

func main() {
    req, err := http.NewRequest("GET", "https://swapi.co/api/people/1", nil)
    if err != nil {
        log.Fatal(err)
    }
    resp, err := fetch(req)
    if err != nil {
        log.Fatal(err)
    }
    log.Print(readBody(resp))
}

func fetch(req *http.Request) (*http.Response, error) {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    return ctxhttp.Do(ctx, http.DefaultClient, req)
}

func readBody(resp *http.Response) (string, error) {
    b, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return "", err
    }
    return string(b), err
}
```

问题的解决办法如下，作者也附带了[Test Case](https://play.golang.org/p/trMP7Q-maT)。 请求包括发送请求和读取响应两部分，`CancelFunc`应该在请求被处理完成后调用。不然，就会发生上面遇到的问题。

> In case it's still unclear, you need to wrap both the "do request" + "read body" inside the same cancellation context. The "defer cancel" should encompass both of them, sort of atomically, so the idea is to take it out of your fetch, one level up.

## 重现Bug

我们准备通过控制请求返回的内容，来验证我们的结论。我们在本地启动一个新服务，并对外提供一个接口，来替代上述代码中的请求地址。

代码如下，其中`info`接口实现了下载resource文件的功能。我们通过控制resource文件的大小，来控制返回response大小的目的。

```go
package main

import (
	"github.com/gin-gonic/gin"
	"io/ioutil"
	"log"
)

func main() {
	router := gin.Default()
	router.GET("/info", func(c *gin.Context) {
		data, err := ioutil.ReadFile("./resource")
		if err != nil {
			log.Println("read file err:", err.Error())
			return
		}

		log.Println("send file resource")
		c.Writer.Write(data)
	})
  
	router.Run(":8000")
}
```

首先，我们向resource文件中写入大量的内容，重新执行上述代码。错误日志输出：`2019/06/13 21:12:37 context canceled`。确实重现了！

然后，将resource文件内容删除到只剩一行数据，请求又可以正常处理了。

```go
req, err := http.NewRequest("GET", "http://127.0.0.1:8000/info", nil)
```

总结：上述错误代码的执行结果，依赖请求返回的数据量大小。

## 修正`Bug`

根据上述分析，我们对代码进行调整：将`defer cancel()`调整到程序读取完`http.Response.Body`之后执行。具体修改如下：

1. 在`fetch`函数中，将`cancel`函数作为返回值，返回给调用方。

```go
func fetch(req *http.Request) (context.CancelFunc, *http.Response, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	resp, err := ctxhttp.Do(ctx, http.DefaultClient, req)
	return cancel, resp, err
}
```

2. 当`readBody`读取完数据之后，再调用`cancel`方法。

```go
	cancel, resp, err := fetch(req)
	if err != nil {
		log.Fatal(err)
	}
	defer cancel()
	log.Print(readBody(resp))
```

跟预期的一样，再接口返回的数据量很大的情况下，请求也可以被正常处理。

##  三种错误类型

### `context deadline exceeded`

我们将代码中`context.WithTimeout`的超时时间由`5*time.Second`调整为`1*time.Millisecond`。执行代码，输出错误日志：`2019/06/13 21:29:11 context deadline exceeded`。

### `context canceled`

参考上述代码。

### `net/http: request canceled`

工作中常见的错误之一：`net/http: request canceled (Client.Timeout exceeded while awaiting headers)`，这是由`http Client`设置的超时时间决定的。接下来我们重现一下这个error。

`fetch`方法中，我们声明一个自定义的`client`，并指定`Timeout`属性为`time.Millisecond`，来替换代码中默认的`client`。

```go
func fetch(req *http.Request) (context.CancelFunc, *http.Response, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	customClient := &http.Client{
		Timeout: time.Millisecond,
	}
	resp, err := ctxhttp.Do(ctx, customClient, req)
	return cancel, resp, err
}
```

程序执行输出：

```
2019/06/18 09:20:53 Get http://127.0.0.1:8000/info: net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)
```

如下是`http.Client`结构体中对`Timeout`的注释，它包括创建连接、请求跳转、读取响应的全部时间。

```go
// Timeout specifies a time limit for requests made by this
// Client. The timeout includes connection time, any
// redirects, and reading the response body. The timer remains
// running after Get, Head, Post, or Do return and will
// interrupt reading of the Response.Body.
//
// A Timeout of zero means no timeout.
//
// The Client cancels requests to the underlying Transport
// as if the Request's Context ended.
//
// For compatibility, the Client will also use the deprecated
// CancelRequest method on Transport if found. New
// RoundTripper implementations should use the Request's Context
// for cancelation instead of implementing CancelRequest.
```


## `context`原理

下面是`context`的接口类型，因为`Done()`的注解很好的解释了`context`最本质的用法，所以，特意只将这部分贴出来。在`for`循环体内，执行每次循环时，使用`select`方法来监听`Done()`是否被关闭了。如果关闭了，就退出循环。在`ctxhttp`包内，也是通过这种用法来实现对请求的控制的。


```go
type Context interface {
	Deadline() (deadline time.Time, ok bool)

	// Done returns a channel that's closed when work done on behalf of this
	// context should be canceled. Done may return nil if this context can
	// never be canceled. Successive calls to Done return the same value.
	//
	// WithCancel arranges for Done to be closed when cancel is called;
	// WithDeadline arranges for Done to be closed when the deadline
	// expires; WithTimeout arranges for Done to be closed when the timeout
	// elapses.
	//
	// Done is provided for use in select statements:
	//
	//  // Stream generates values with DoSomething and sends them to out
	//  // until DoSomething returns an error or ctx.Done is closed.
	//  func Stream(ctx context.Context, out chan<- Value) error {
	//  	for {
	//  		v, err := DoSomething(ctx)
	//  		if err != nil {
	//  			return err
	//  		}
	//  		select {
	//  		case <-ctx.Done():
	//  			return ctx.Err()
	//  		case out <- v:
	//  		}
	//  	}
	//  }
	//
	// See https://blog.golang.org/pipelines for more examples of how to use
	// a Done channel for cancelation.
	Done() <-chan struct{}
	Err() error
	Value(key interface{}) interface{}
}
```

因为有业务逻辑在监听`context.Done()`，所以，必然需要有逻辑来`Close`调这个`Channel`。而整个`context`包也围绕者两个方面提供了一些方法，包括启动定时器来关闭`context.Done()`。参考注释中提到的`WithCancel`、`WithDeadline`以及`WithTimeout`。

## 源代码

下面是用来获取`cancelCtx`的方法，我们可以了解到`context`内部被封装的三种类型，分别是`cancelCtx`、`timerCtx`以及`valueCtx`。

```go
// parentCancelCtx follows a chain of parent references until it finds a
// *cancelCtx. This function understands how each of the concrete types in this
// package represents its parent.
func parentCancelCtx(parent Context) (*cancelCtx, bool) {
	for {
		switch c := parent.(type) {
		case *cancelCtx:
			return c, true
		case *timerCtx:
			return &c.cancelCtx, true
		case *valueCtx:
			parent = c.Context
		default:
			return nil, false
		}
	}
}
```

查看这三种类型的声明，内部都封装了一个`Context`值，用来存储父`Context`。恰恰也是通过这个字段，将整个`Context`串了起来。其中`timerCtx`是基于`cancelCtx`做的扩展，在其基础上添加了计时的功能。另外，`cancelCtx`节点中的`children`用于保存它所有的子节点。

```go
// A cancelCtx can be canceled. When canceled, it also cancels any children
// that implement canceler.
type cancelCtx struct {
	Context

	mu       sync.Mutex            // protects following fields
	done     chan struct{}         // created lazily, closed by first cancel call
	children map[canceler]struct{} // set to nil by the first cancel call
	err      error                 // set to non-nil by the first cancel call
}

// A timerCtx carries a timer and a deadline. It embeds a cancelCtx to
// implement Done and Err. It implements cancel by stopping its timer then
// delegating to cancelCtx.cancel.
type timerCtx struct {
	cancelCtx
	timer *time.Timer // Under cancelCtx.mu.

	deadline time.Time
}

// A valueCtx carries a key-value pair. It implements Value for that key and
// delegates all other calls to the embedded Context.
type valueCtx struct {
	Context
	key, val interface{}
}
```

接下来，我们了解一下，将一个新的`child context`节点挂到`parent context`的过程。

首先，程序判断`parent`的数据类型，如果是上述三种类型之一，且没有错误信息，直接将`child`存储到`parnet.children`的`map`结构中。

如果`parnet`不是上述类型之一，程序会启动一个`Goroutine`异步监听`parent.Done()`和`child.Done()`是否被关闭。我的理解是，因为此时`parent`其实是`background`和`todo`中的一种（我称它为顶级`parnet`），而它们内部都没有字段用于存储和`child`的关系。所以，在程序`select`中绑定了它们的对应关系。另外，一个顶级`parent`也只能有一个`child`，而这个`child`应该是上述三种类型中的一种。只有这种一对一的情况，当`child.Done()`被关闭的时候，整个`select`退出才是合理的。

```go
// propagateCancel arranges for child to be canceled when parent is.
func propagateCancel(parent Context, child canceler) {
	if parent.Done() == nil {
		return // parent is never canceled
	}
	if p, ok := parentCancelCtx(parent); ok {
		p.mu.Lock()
		if p.err != nil {
			// parent has already been canceled
			child.cancel(false, p.err)
		} else {
			if p.children == nil {
				p.children = make(map[canceler]struct{})
			}
			p.children[child] = struct{}{}
		}
		p.mu.Unlock()
	} else {
		go func() {
			select {
			case <-parent.Done():
				child.cancel(false, parent.Err())
			case <-child.Done():
			}
		}()
	}
}
```

我们接着看一下`WithCancel`和`WithDeadline`这两个方法。前者通过调用`CancelFunc`来取消。后者在此基础上，加了一个`timer`的定时触发取消机制。如果`WithDeadline`参数`d`本身就是一个过去的时间点，那么`WithDeadline`和`WithCancel`效果相同。

```go
// WithCancel returns a copy of parent with a new Done channel. The returned
// context's Done channel is closed when the returned cancel function is called
// or when the parent context's Done channel is closed, whichever happens first.
//
// Canceling this context releases resources associated with it, so code should
// call cancel as soon as the operations running in this Context complete.
func WithCancel(parent Context) (ctx Context, cancel CancelFunc) {
	c := newCancelCtx(parent)
	propagateCancel(parent, &c)
	return &c, func() { c.cancel(true, Canceled) }
}

// WithDeadline returns a copy of the parent context with the deadline adjusted
// to be no later than d. If the parent's deadline is already earlier than d,
// WithDeadline(parent, d) is semantically equivalent to parent. The returned
// context's Done channel is closed when the deadline expires, when the returned
// cancel function is called, or when the parent context's Done channel is
// closed, whichever happens first.
//
// Canceling this context releases resources associated with it, so code should
// call cancel as soon as the operations running in this Context complete.
func WithDeadline(parent Context, d time.Time) (Context, CancelFunc) {
	if cur, ok := parent.Deadline(); ok && cur.Before(d) {
		// The current deadline is already sooner than the new one.
		return WithCancel(parent)
	}
	c := &timerCtx{
		cancelCtx: newCancelCtx(parent),
		deadline:  d,
	}
	propagateCancel(parent, c)
	dur := time.Until(d)
	if dur <= 0 {
		c.cancel(true, DeadlineExceeded) // deadline has already passed
		return c, func() { c.cancel(false, Canceled) }
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.err == nil {
		c.timer = time.AfterFunc(dur, func() {
			c.cancel(true, DeadlineExceeded)
		})
	}
	return c, func() { c.cancel(true, Canceled) }
}

```

最后，我们以`timerCtx`类型为例，来看看`cancel`函数的具体实现。方法的调用过程是递归执行的，内部调用的是`cancelCtx`的`cancel`方法。参数`removeFromParent`用来判断是否要从父节点中移除该节点。同时，如果计时器存在的话，要关闭计时器。

```go
func (c *timerCtx) cancel(removeFromParent bool, err error) {
	c.cancelCtx.cancel(false, err)
	if removeFromParent {
		// Remove this timerCtx from its parent cancelCtx's children.
		removeChild(c.cancelCtx.Context, c)
	}
	c.mu.Lock()
	if c.timer != nil {
		c.timer.Stop()
		c.timer = nil
	}
	c.mu.Unlock()
}

```

具体到`cancelCtx`中的`cancel`方法，函数依次`cancel`掉`children`中存储的子节点。但我们发现，在`for`循环移除子节点的时候，`removeFromParent`参数值为`false`。我的理解是，子节点依赖的父节点都已经被移除了，子节点是否移除就不重要了。

```go
// cancel closes c.done, cancels each of c's children, and, if
// removeFromParent is true, removes c from its parent's children.
func (c *cancelCtx) cancel(removeFromParent bool, err error) {
	if err == nil {
		panic("context: internal error: missing cancel error")
	}
	c.mu.Lock()
	if c.err != nil {
		c.mu.Unlock()
		return // already canceled
	}
	c.err = err
	if c.done == nil {
		c.done = closedchan
	} else {
		close(c.done)
	}
	for child := range c.children {
		// NOTE: acquiring the child's lock while holding parent's lock.
		child.cancel(false, err)
	}
	c.children = nil
	c.mu.Unlock()

	if removeFromParent {
		removeChild(c.Context, c)
	}
}
```

## 在`ctxhttp`中的应用

### 发送`request`

上面的例子中，我们创建了一个顶级`context.Background`。在调用`WithTimeout`时，`parent`会创建一个异步的`Goroutine`用来进行监听`Done`是否已经被关闭。同时还会为新创建的`context`设置一个计时器`timer`，来计算到期时间。

```go
ctx, cancel := context.WithTimeout(context.Background(), time.Second)
```

下面是发送请求的代码，可以看到这是一个for循环的过程，所以非常适合`context`的处理模型。另外，该方法中有我们上面描述的错误情况：`net/http: request canceled`。对于这种超时错误，我们可以通过判断`error`类型，以及`timeout`是否为`true`来判断。

一直到这里，我们还没有看到`context`的核心逻辑…...

```go
func (c *Client) do(req *Request) (retres *Response, reterr error) {
  // 删除简化代码......
	for {
		reqs = append(reqs, req)
		var err error
		var didTimeout func() bool
		if resp, didTimeout, err = c.send(req, deadline); err != nil {
			// c.send() always closes req.Body
			reqBodyClosed = true
			if !deadline.IsZero() && didTimeout() {
				err = &httpError{
					// TODO: early in cycle: s/Client.Timeout exceeded/timeout or context cancelation/
					err:     err.Error() + " (Client.Timeout exceeded while awaiting headers)",
					timeout: true,
				}
			}
			return nil, uerr(err)
		}

		var shouldRedirect bool
		redirectMethod, shouldRedirect, includeBody = redirectBehavior(req.Method, resp, reqs[0])
		if !shouldRedirect {
			return resp, nil
		}
	}
}
```

所有对`context`的处理，都是在`Transport.roundTrip`中实现的

```go
// roundTrip implements a RoundTripper over HTTP.
func (t *Transport) roundTrip(req *Request) (*Response, error) {
	t.nextProtoOnce.Do(t.onceSetNextProtoDefaults)
	ctx := req.Context()
	trace := httptrace.ContextClientTrace(ctx)

	for {
		select {
		case <-ctx.Done():
			req.closeBody()
			return nil, ctx.Err()
		default:
		}

		// treq gets modified by roundTrip, so we need to recreate for each retry.
		treq := &transportRequest{Request: req, trace: trace}
		cm, err := t.connectMethodForRequest(treq)
	}
}
```

### 读取`response`

在从`conn`读取数据的时候，依旧对`req`的`context`做了判断。同时也可以看出，读取`Response.Body`的过程，就是不断从`resc`中读取数据的过程。

```go
func (pc *persistConn) roundTrip(req *transportRequest) (resp *Response, err error) {
	// Write the request concurrently with waiting for a response,
	// in case the server decides to reply before reading our full
	// request body.
	startBytesWritten := pc.nwrite
	writeErrCh := make(chan error, 1)
	pc.writech <- writeRequest{req, writeErrCh, continueCh}

	resc := make(chan responseAndError)
	pc.reqch <- requestAndChan{
		req:        req.Request,
		ch:         resc,
		addedGzip:  requestedGzip,
		continueCh: continueCh,
		callerGone: gone,
	}

	var respHeaderTimer <-chan time.Time
	cancelChan := req.Request.Cancel
	ctxDoneChan := req.Context().Done()
	for {
		testHookWaitResLoop()
		select {
		case <-ctxDoneChan:
			pc.t.cancelRequest(req.Request, req.Context().Err())
			cancelChan = nil
			ctxDoneChan = nil
		}
	}
}
```

参考文章：

1. [Using context cancellation in Go](https://www.sohamkamani.com/blog/golang/2018-06-17-golang-using-context-cancellation/)



