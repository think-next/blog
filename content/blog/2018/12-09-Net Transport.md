---
title: Net Transport

date: 2018-12-08

tags: [golang]

author: 付辉

---

在调用第三方请求时，正确使用[`Client`](https://godoc.org/net/http#Client)也不是一件非常容易的事。

下面是截取的一段描述，建议`Client`或`Transport`在整个服务期间最好是全局单例的，`Transport`本身会维护连接的状态，而且线程安全。强烈建议，不要使用系统提供的任何默认值。

> The Client's Transport typically has internal state (cached TCP connections), so Clients should be reused instead of created as needed. Clients are safe for concurrent use by multiple goroutines.

## `Dial`

关于`net`包的[Dial](https://golang.org/src/net/dial.go?s=9799:9847#L306)方法，下面是文档是的例子：

```go
func TestDial(t *testing.T) {
	conn, err := net.Dial("tcp", "baidu.com:80")
	if err != nil {
		// handle error
	}
	fmt.Fprintf(conn, "GET /ping HTTP/1.0\r\n\r\n")
	status, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil {
		t.Fatal(err)
	}
	t.Log(status)
}
```

与`Dial`相关的是类型[Dialer](https://golang.org/src/net/dial.go?s=652:3413#L16) ，用来配置`Dial`的属性，包括`Timeout`、`KeepAlive`等。当`Dialer`的每个`field`都是零值时，等同于直接调用`Dial`方法。

## `Transport`

类型[Transport](https://golang.org/src/net/http/transport.go?s=3397:10477#L85)中包含`DialContext`，对它的注释如下：函数用来创建非加密的`TCP`连接，如果字段为`nil`，则使用`net`包的`Dial`方法。

通过封装`dial`方法，我们可以手动`Debug`连接的创建过层。

```go
func PrintLocalDial(ctx context.Context, network, addr string) (net.Conn, error) {
	dial := net.Dialer{
		Timeout:   30 * time.Second,
		KeepAlive: 5 * time.Second,
	}
	conn, err := dial.Dial(network, addr)
	if err != nil {
		return conn, err
	}

	fmt.Println("connect done.", conn.LocalAddr().String(), conn.RemoteAddr().String())
	return conn, err
}
```

## RoundTripper

如下是官方的简要描述。`Transport`字段在`Client`中被声明为接口类型，而实现这个接口的是`Transport`类型（略显绕）。在`net`包内部也提供了默认的实现变量：`DefaultTransport`。

```go
// Transport specifies the mechanism by which individual
// HTTP requests are made.
// If nil, DefaultTransport is used.
Transport RoundTripper
```

看一下`RoundTripper`这个接口，官方描述：

> RoundTripper is an interface representing the ability to execute a single HTTP transaction, obtaining the Response for a given Request.

既然是一个接口类型，我们就有理由自己去实现它，我们可以自定义自己的`Transport`。比如客户端发起一个请求，我们可以先去查询缓存中是否存在。如果存在，则将缓存中的数据写回`response`。如果不存在，请求远端服务获取数据，并缓存。

实现这样的功能，完全没有必要自定义一个`Transport`，我们也可以使用先请求缓存服务器，在请求远端服务器的方案来实现。但其实`Transport`就可以实现封装这些功能。

```
func cacheResponse(b []byte, r *http.Request) (*http.Response, error) {
	//NewBuffer is intended to prepare a Buffer to read existing data.
	buf := bytes.NewBuffer(b)
	return http.ReadResponse(bufio.NewReader(buf), r)
}
```

官方提供了默认的`Transport`。如果不明确指定，那么底层就使用默认值。所以，可能连你也没有意识到，你在使用长链接。

另外：**一定要记得当请求返回的`error`为空时，读取连接返回的数据，并明确调用`Close`关闭连接。否则连接会没法继续复用。**

```
func (c *Client) transport() RoundTripper {
	if c.Transport != nil {
		return c.Transport
	}
	return DefaultTransport
}
```

## 缓存`Idle`连接

首先了解缓存长链接的`Key`是什么，即用来唯一确定连接的`Key`。我们选来看看它如何从缓存池获取的空闲连接：

```go
//1. 获取的方法，截取其中一部分代码
func (t *Transport) getIdleConn(cm connectMethod) (pconn *persistConn, idleSince time.Time) {
	key := cm.key()
	t.idleMu.Lock()
	defer t.idleMu.Unlock()
	for {
		pconns, ok := t.idleConn[key]
		if !ok {
			return nil, time.Time{}
		}
		if len(pconns) == 1 {
			pconn = pconns[0]
			delete(t.idleConn, key)
		} else {
			// 2 or more cached connections; use the most
			// recently used one at the end.
			pconn = pconns[len(pconns)-1]
			t.idleConn[key] = pconns[:len(pconns)-1]
		}
		t.idleLRU.remove(pconn)
		//省略之后的代码......
```

通过如下代码，可以确定`net`包通过当前请求的`proxy URL`、`Scheme`、`Addr`来缓存建立的连接。缓存的连接存储在一个`MAP`结构中：` map[connectMethodKey][]*persistConn`。`map`中的每一个`Key`对应了连接的`slice`数组，最新创建的连接会追加到`slice`的末尾。

```
func (cm *connectMethod) key() connectMethodKey {
	proxyStr := ""
	targetAddr := cm.targetAddr
	if cm.proxyURL != nil {
		proxyStr = cm.proxyURL.String()
		if (cm.proxyURL.Scheme == "http" || cm.proxyURL.Scheme == "https") && cm.targetScheme == "http" {
			targetAddr = ""
		}
	}
	return connectMethodKey{
		proxy:  proxyStr,
		scheme: cm.targetScheme,
		addr:   targetAddr,
	}
}
```

因为`Key`中存在了`Host`地址，所以`MaxIdleConnsPerHost`这个值就显得格外重要。当准备缓存连接时，如果检测到当前的空闲连接数大于`MaxIdleConnsPerHost`，系统便会主动将这个连接关闭。**这可能会是一个坑，特别要注意这一点。**

如果不指定`MaxIdleConnsPerHost`，那么程序使用默认的值：`DefaultMaxIdleConnsPerHost`，这个默认值好比`DefaultClient`，都是问题所在。前者的默认值是2，可能直接导致在并发的时候，长链接的效率还不如短链接。后者的默认超时时间是0，这可能导致一个连接永远的挂在了那里。

使用`net`包提供的默认值，很多时候都不会是一件明智的事情。

```
func (t *Transport) tryPutIdleConn(pconn *persistConn) error {
    //省略之前的代码......
	if t.idleConn == nil {
		t.idleConn = make(map[connectMethodKey][]*persistConn)
	}
	idles := t.idleConn[key]
	if len(idles) >= t.maxIdleConnsPerHost() {
		return errTooManyIdleHost
	}
	//省略之后的代码......

//主动关闭连接的代码
func (t *Transport) putOrCloseIdleConn(pconn *persistConn) {
	if err := t.tryPutIdleConn(pconn); err != nil {
		pconn.close(err)
	}
}
```

客户端对每个主机最多可以保持`Transport.MaxIdleConnsPerHost`个长链接。对于长链接而言，一般是由服务端主动关闭的，而连接维持的时间也由服务端来决定。如果对于请求的域名，对应的`Host`足够多，在服务端关闭这些连接之前，可能会存在大量的空闲连接，造成资源浪费。

## `Test Case`

下面是测试使用的例子，首先判断客户端和服务器之间是否支持长链接，然后通过抓包可以分析服务端长链接的持续时间。上文也阐述了，长链接一般是服务端主动断开连接，而这个时间的长短需要服务端自己决定。

首先我们声明一个`Dialer`用于创建连接。这里特别注意`Dialer`下的`KeepAlive`字段，这是`Client`为了维持长连接，主动发送`TCP keep-alive segment`的时间间隔，类比`ping-pong`模式。官方的解释是：`KeepAlive specifies the keep-alive period for an active network connection. If zero, keep-alives are not enabled. Network protocols that do not support keep-alives ignore this field.`。

我们在每次创建连接的时候，都将本地`socket`地址和服务端`socket`地址打印出来。如果没有新的地址生成，说明当前连接复用了前面创建的连接。这也侧面证明了是否服务端支持`Keep-Alive`。但需要强调的是，默认情况下只存在`DefaultMaxIdleConnsPerHost`个长连接。

```go
func PrintLocalDial(ctx context.Context, network, addr string) (net.Conn, error) {
	dial := net.Dialer{
		Timeout:   30 * time.Second,
		//指定的这个时间并没有生效，即使在请求完成后Sleep 30s连接仍然有效
		KeepAlive: 5 * time.Second,
	}
	conn, err := dial.Dial(network, addr)
	if err != nil {
		return conn, err
	}

	fmt.Println("connect done, use ", conn.LocalAddr().String(), conn.RemoteAddr().String())
	return conn, err
}
```

紧接着我们声明`Client`用于发送请求，`Transport`中使用上面声明的方法创建连接。并写测试用例用于测试。同时打开抓包工具，分析整个网络请求。
```
var client = &http.Client{
	Transport: &http.Transport{
		DialContext: PrintLocalDial,
	},
}

func TestRequestBaiDu(t *testing.T) {
	for i := 0; i < 3; i ++ {
		resp, err := client.Get("http://xxxx.com")
		if err != nil {
			fmt.Println(err)
			return
		}

		_, err = ioutil.ReadAll(resp.Body)
		if err := resp.Body.Close(); err != nil {
			fmt.Println(err)
		}

		time.Sleep(time.Second * 20)
	}
}

```

通过截取到的请求可以得出：首先，`client`端每间隔`5s`发送`keep-alive segment`，其次，如果连接在`15s`内不活跃，服务端会关闭连接。通过分析图中的时间轴就可以得出。

![image](https://note.youdao.com/yws/public/resource/3d6862c45f647283a5312d81e986f0d2/xmlnote/WEBRESOURCE4fb32d413b7a1ecec3af0e45c07d4add/67978)

## `TCP KeepAlive Timer`

上图`Wireshark`抓取的数据报文中，那些红字体黑背景的报文给人一种貌似出错的感觉。而他本身就是`TCP`保活机制。在创建连接后，`TCP`两端都会启动一个`Timer`计时器，用于检测连接是否有效。

保活探测报文为一个空报文段（或只含有一个字节）它的序列号等于对方主机发送的ACK报文的最大的序列号减1，因为这一序列号的数据段已经被成功接受，所以不会对到达的报文段产生影响。

如图所示，第一个`keep-alive segment`的`Seq=302`，而它最近一次的`Seq=303`。这样整个保活过程都不会对`data transfer`产生影响。

下面便是设置`keep-alive`时间间隔的代码：

```
if tc, ok := c.(*TCPConn); ok && d.KeepAlive > 0 {
	setKeepAlive(tc.fd, true)
	setKeepAlivePeriod(tc.fd, d.KeepAlive)
	testHookSetKeepAlive()
}
```

参考文章：

1. [`Go HTTP Client 持久连接`](https://serholiu.com/go-http-client-keepalive)
2. [`Don’t use Go’s default HTTP client (in production)`](https://medium.com/@nate510/don-t-use-go-s-default-http-client-4804cb19f779)
3. [`Are TCP Keep Alive Messages Bad? (By Chris Greer)`](https://www.lovemytool.com/blog/2014/11/are-tcp-keep-alive-messages-bad-by-chris-greer.html#comment-6a00e008d957708834022ad3808ea0200c)