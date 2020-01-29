---
title: Tcp Server Design

date: 2018-07-28

tags: [tcp/ip,net]

author: 付辉

---

绝大多数的`TCP`服务都是支持并发的。当一个连接请求到达时，服务端接收这个连接，然后创建一个新的线程(或进程)来处理这个连接。

## `listen`状态

在本地启动`Go`的服务，使用`netstat`查看：
```
netstat -an -f inet
```
可以看到`listen`状态的请求连接。其中`Local Address`的`*`表示请求会被本地的任意地址处理(如果有多重地址的话)。`Foreign Address`中`*.*`表示客户端的`ip`和`port`都是未知的。
```
Active Internet connections (including servers)
Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
tcp46      0      0  *.3900                 *.*                    LISTEN
```
当新的请求到达，并被接收时，服务器内核中会创建一个`ESTABLISHED`状态的连接。而`listen`继续去接收新的连接。
```
Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
tcp4       0      0  127.0.0.1.3900         127.0.0.1.51133        ESTABLISHED
tcp46      0      0  *.3900                 *.*                    LISTEN
```

## `request queue`

当`listening`状态的应用正在忙于处理新的连接，同时有其他的请求进来时，服务器是如何处理的呢？引入另一个概念：请求队列。

1. 每一个监听状态的终端都有一个固定长度的队列，用来存放`TCP`三次握手完成，但还没有被应用接收的连接。`client`会认为该连接已经创建成功，所以它此时发送的数据也会被缓存起来。如果`queue`中的连接长时间不被应用读取，便会导致`client`超时。
2. 当队列满了后，`TCP`会直接忽略进来的`SYN`，而非回复`RST`报文头。这样做便是要`client`稍后重新发送`SYN`。因为服务器比较繁忙的状况，可能马上就会恢复。
3. 如果`TCP`三次握手完成，连接也就被创建成功了。如果此时服务端不想为该`ip`提供服务，服务端要么发送`FIN`关闭这个连接，或者发送`RST`中断这个连接。整个过程中，`TCP`没有权限去限制`client`端。