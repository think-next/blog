---
title: Go net 超时处理

date: 2022-01-02

tags: [golang,translate]

author: 付辉

---

## `序`

这篇文章详细介绍了，`net/http`包中对应`HTTP`的各个阶段，如何使用`timeout`来进行读/写超时控制以及服务端和客户端支持设置的`timeout`类型。本质上，这些`timeout`都是代码层面对各个函数设置的处理时间。比如，读取客户端读取请求头、读取响应体的时间，本质上都是响应函数的超时时间。

作者强烈不建议，在工作中使用`net/http`包上层封装的默认方法（没有明确设置`timeout`），很容易出现系统文件套接字被耗尽等令人悲伤的情况。比如：

```
// 相信工作中也不会出现这样的代码
func main() {
	http.ListenAndServe("127.0.0.1:3900", nil)
}
```

## 正文

在使用`Go`开发`HTTP Server`或`client`的过程中，指定`timeout`很常见，但也很容易犯错。`timeout`错误一般还不容易被发现，可能只有当系统出现请求超时、服务挂起时，错误才被严肃暴露出来。

`HTTP`是一个复杂的多阶段协议，所以也不存在一个`timeout`值适用于所有场景。想一下[`StreamingEndpoint`](https://docs.microsoft.com/en-us/rest/api/media/operations/streamingendpoint)、`JSON API`、 [`Comet`](https://en.wikipedia.org/wiki/Comet_%28programming%29)， 很多情况下，默认值根本不是我们所需要的值。

这篇博客中，我会对`HTTP`请求的各个阶段进行拆分，列举可能需要设置的`timeout`值。然后从客户端和服务端的角度，分析它们设置`timeout`的不同方式。

## `SetDeadline`

首先，你需要知道`Go`所暴露出来的，用于实现`timeout`的方法：`Deadline`。

`timeout`本身通过 [`net.Conn`](https://golang.org/pkg/net/#Conn)包中的`Set[Read|Write]Deadline(time.Time)`方法来控制。`Deadline`是一个绝对的时间点，当连接的`I/O`操作超过这个时间点而没有完成时，便会因为超时失败。

**`Deadlines`不同于`timeouts`**. 对一个连接而言，设置`Deadline`之后，除非你重新调用`SetDeadline`，否则这个`Deadline`不会变化。前面也提了，`Deadline`是一个绝对的时间点。因此，如果要通过`SetDeadline`来设置`timeout`，就不得不在每次执行`Read`/`Write`前重新调用它。

你可能并不想直接调用`SetDeadline`方法，而是选择 `net/http`提供的更上层的方法。但你要时刻记住：所有`timeout`操作都是通过设置`Deadline`实现的。每次调用，它们并不会去重置的`deadline`。

## `Server Timeouts`

关于服务端超时，这篇帖子[`So you want to expose Go on the Internet`](https://blog.cloudflare.com/exposing-go-on-the-internet/)也介绍了很多信息，特别是关于`HTTP/2`和`Go 1.7 bugs`的部分.

![HTTP server phases](https://blog.cloudflare.com/content/images/2016/06/Timeouts-001.png)

对于服务端而言，指定`timeout`至关重要。否则，一些请求很慢或消失的客户端很可能导致系统`文件描述符`泄漏，最终服务端报错：

```
http: Accept error: accept tcp [::]:80: accept4: too many open files; retrying in 5ms
```

在创建`http.Server`的时候，可以通过`ReadTimeout`和`WriteTimeout`来设置超时。你需要明确的声明它们：

```go
srv := &http.Server{
    ReadTimeout: 5 * time.Second,
    WriteTimeout: 10 * time.Second,
}
log.Println(srv.ListenAndServe())
```

`ReadTimeout`指从连接被`Accept`开始，到`request body`被完全读取结束（如果读取`body`的话，否则是读取完`header`头的时间）。内部是`net/http`通过在[`Accept`后](https://github.com/golang/go/blob/3ba31558d1bca8ae6d2f03209b4cae55381175b3/src/net/http/server.go#L750)调用`SetReadDeadline`实现的。

`WriteTimeout`一般指从读取完`header`头之后到写完`response`的时间（又称`ServerHTTP`的处理时间），内部通过在 [`readRequest`之后](https://github.com/golang/go/blob/3ba31558d1bca8ae6d2f03209b4cae55381175b3/src/net/http/server.go#L753-L755)调用`SetWriteDeadline`实现。

然而，如果是`HTTPS`的话，`SetWriteDeadline`方法在[`Accept`后就被](https://github.com/golang/go/blob/3ba31558d1bca8ae6d2f03209b4cae55381175b3/src/net/http/server.go#L750)调用，所以`TLS handshake`也是`WriteTimeout`的一部分。同时，这也意味着（仅仅`HTTPS`）`WriteTimeout`包括了读`header`头以及握手的时间。

为了避免不信任的`client`端或者网络连接的影响，你应该同时设置这两个值，来保证连接不被`client`长时间占用。

最后，介绍一下[`http.TimeoutHandler`](https://golang.org/pkg/net/http/#TimeoutHandler)，它并不是一个`Server`属性，它被用来`Wrap http.Handler `，限制`Handler`处理请求的时长。它主要依赖缓存的`response`来工作，当超时发生时，响应`503 Service Unavailable`的错误。[它在1.6存在问题，在1.6.2进行了修复](https://github.com/golang/go/issues/15327)。

## `http.ListenAndServe` is doing it wrong

顺带说一句，这也意味：使用一些内部封装`http.Server`的包函数，比如`http.ListenAndServe`, `http.ListenAndServeTLS`以及`http.Serve`是不正规的，尤其是直接面向外网提供服务的场合。

这种方法默认缺省配置`timeout`值，也没有提供配置`timeout`的功能。如果你使用它们，可能就会面临连接泄漏和文件描述符耗尽的风险。我也好几次犯过这样的错误。

相反的，创建一个`http.Server`应该像文章开头例子中那样，明确设置`ReadTimeout`和`WriteTimeout`，并使用相应的方法来使`server`更完善。

## `About streaming`

Very annoyingly, there is no way of accessing the underlying `net.Conn` from `ServeHTTP`so a server that intends to stream a response is forced to unset the `WriteTimeout` (which is also possibly why they are 0 by default). This is because without `net.Conn` access, there is no way of calling `SetWriteDeadline` before each `Write` to implement a proper idle (not absolute) timeout.

Also, there's no way to cancel a blocked `ResponseWriter.Write` since `ResponseWriter.Close` (which you can access via an interface upgrade) is not documented to unblock a concurrent Write. So there's no way to build a timeout manually with a Timer, either.

Sadly, this means that streaming servers can't really defend themselves from a slow-reading client.

I submitted [an issue with some proposals](https://github.com/golang/go/issues/16100), and I welcome feedback there.

## `Client Timeouts`

![HTTP Client phases](https://blog.cloudflare.com/content/images/2016/06/Timeouts-002.png)

`client`端的`timeout`可以很简单，也可以很复杂，这完全取决于你如何使用。但对于阻止内存泄漏或长时间连接占用的问题上，相对于`Server`端来说，它同样特别重要。

下面是使用[`http.Client`](https://golang.org/pkg/net/http/#Client)指定`timeout`的最简单例子。`timeout`覆盖了整个请求的时间：从`Dial`（如果非连接重用）到读取`response body`。

```go
c := &http.Client{
    Timeout: 15 * time.Second,
}
resp, err := c.Get("https://blog.filippo.io/")
```

像上面列举的那些`server`端方法一样，`client`端也封装了类似的方法，比如`http.Get`。他内部用的就是一个没有设置超时时间的[Client](https://golang.org/pkg/net/http/#DefaultClient)。

下面提供了很多类型的`timeout`，可以让你更精细的控制超时：

- `net.Dialer.Timeout`用于限制建立`TCP`连接的时间，包括域名解析的时间在内（如果需要创建的话）
- `http.Transport.TLSHandshakeTimeout`用于限制`TLS`握手的时间
- `http.Transport.ResponseHeaderTimeout`用于限制读取响应头的时间（不包括读取`response body`的时间）
- `http.Transport.ExpectContinueTimeout`用于限制从客户端在发送包含*Expect: 100-continue*请求头开始，到接收到响应去继续发送`post data`的间隔时间。注意：在`1.6`中[ HTTP/2](https://github.com/golang/go/issues/14391) 不支持这个设置(`DefaultTransport`从1.6.2起是[一个例外 1.6.2](https://github.com/golang/go/commit/406752b640fcc56a9287b8454564cffe2f0021c1#diff-6951e7593bfb1e773c9121df44df1c36R179)).

```
c := &http.Client{
    Transport: &http.Transport{
        Dial: (&net.Dialer{
                Timeout:   30 * time.Second,
                KeepAlive: 30 * time.Second,
        }).Dial,
        TLSHandshakeTimeout:   10 * time.Second,
        ResponseHeaderTimeout: 10 * time.Second,
        ExpectContinueTimeout: 1 * time.Second,
    }
}
```

到目前为止，还没有一种方式来限制发送请求的时间。读响应体的时间可以手动的通过设置`time.Timer`来实现，因为这个过程是在`client`方法返回之后发生的（后面介绍如何取消一个请求）。

最后，在1.7的版本中增加了`http.Transport.IdleConnTimeout`，用于限制连接池中空闲连持的存活时间。它不能用于控制阻塞阶段的客户端请求，

注：客户端默认执行请求重定向（302等）。可以为每个请求指定细粒度的超时时间，其中`http.Client.Timeout`包括了重定向在内的请求花费的全部时间。而`http.Transport`是一个底层对象，没有跳转的概念。

## `Cancel and Context`

`net/http` 提供了两种取消客户端请求的方法： `Request.Cancel`以及在`1.7`版本中引入的`Context`.

`Request.Cancel`是一个可选的`channel`，如果设置了它，便可以通过关闭该`channel`来终止请求,就跟请求超时了一样（它们的实现机制是相同的。在写这篇博客的时候，我还发现了一个 1.7的 [`bug`](https://github.com/golang/go/issues/16094) ：所有被取消请求，返回的都是`timeout`超时错误）。

```
type Request struct {

    // Cancel is an optional channel whose closure indicates that the client
	// request should be regarded as canceled. Not all implementations of
	// RoundTripper may support Cancel.
	//
	// For server requests, this field is not applicable.
	//
	// Deprecated: Use the Context and WithContext methods
	// instead. If a Request's Cancel field and context are both
	// set, it is undefined whether Cancel is respected.
	Cancel <-chan struct{}
}
```

我们可结合`Request.Cancel`和`time.Timer`对`timeout`进行更细的控制。比如，在我们每次从`response body`中读取数据后，延长`timeout`的时间。

```go
package main

import (
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

func main() {
    
    //定义一个timer：5s后取消该请求，即关闭该channel
	c := make(chan struct{})
	timer := time.AfterFunc(5*time.Second, func() {
		close(c)
	})

    // Serve 256 bytes every second.
	req, err := http.NewRequest("GET", "http://httpbin.org/range/2048?duration=8&chunk_size=256", nil)
	if err != nil {
		log.Fatal(err)
	}
	req.Cancel = c

    //执行请求,请求的时间不应该超过5s
	log.Println("Sending request...")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	log.Println("Reading body...")
	for {
		timer.Reset(2 * time.Second)
        // Try instead: timer.Reset(50 * time.Millisecond)
		_, err = io.CopyN(ioutil.Discard, resp.Body, 256)
		if err == io.EOF {
			break
		} else if err != nil {
			log.Fatal(err)
		}
	}
}
```

上述例子中，我们给`Do`设置了`5s`的超时，通过后续8个循环来读取`response body`的内容，这个操作至少花费了`8s`的时间。每次`read`的操作均设置了`2s`的超时。我们可以持续这样读，不需要考虑任何阻塞的风险。如果在`2s`内没有接受到数据，`io.CopyN`将会返回`net/http: request canceled`。

在`1.7`的版本中`context`被引入到了标注库，此处是[一些介绍](https://blog.golang.org/context)。接下来我们用它来替换 `Request.Cancel`，实现相同的功能。

使用`context`来取消一个请求，我们需要获取一个`Context`类型，以及调用`context.WithCancel`返回的`cancel()`方法，并通过`Request.WithContext`将`context`绑定到一个请求上。当我们想取消这个请求时，只需要调用`cancel()`方法(代替上述关闭`channel`的做法)

```go
//ctx是context.TODO()的子节点
ctx, cancel := context.WithCancel(context.TODO())
timer := time.AfterFunc(5*time.Second, func() {
	cancel()
})

req, err := http.NewRequest("GET", "http://httpbin.org/range/2048?duration=8&chunk_size=256", nil)
if err != nil {
	log.Fatal(err)
}
req = req.WithContext(ctx)
```

`Contexts`有很多优，比如一个`parent`（传递给`context.WithCancel`的对象）被取消，那么命令会沿着传递的路径一直向下传递，直到关闭所有子`context`。

阅读原文：[`The complete guide to Go net/http timeouts`](https://blog.cloudflare.com/the-complete-guide-to-golang-net-http-timeouts/)