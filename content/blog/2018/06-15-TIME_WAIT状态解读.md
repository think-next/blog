---
title: TIME_WAIT状态解读

date: 2018-06-15

tags: [tcp/ip,net]

author: 付辉

---

***版本：0.01***

突然想梳理一下`TIME_WAIT`,毕竟自己遇到它好多次了。经常一块出现的问题：`too many open file`，当然，这个问题本身跟`TIME_WAIT`状态没啥必然的关系。

截取一下官方对`TIME_WAIT`的描述：

> `The socket connection has been closed by the local application, the remote peer has closed its half of the connection, and the system is waiting to be sure that the remote peer received the last acknowledgement.`

## `time_wait status`

`time_wait`作为`HTTP`连接关闭的一个正常状态。当系统`time_wait`过多，超过操作系统设定的文件套接字上限时，就会导致整个服务不可用。

唯一确定连接的4个组成部分，它们是客户端及服务端的`IP`和`PORT`。一般来说，处于`time_wait`状态的`port`在`2mls`内是无法被重复使用的。所以瞬间的`wait_wait`过多，直接导致整个系统无法服务。

关闭连接包含4次握手，`TCP`是全双工的，有一端需要主动提出关闭。相应的，对端来被动来关闭。对于我们常见的`CS`模式，主动和被动的角色是没有明确界限的。

<center>

![image](https://i.loli.net/2019/04/23/5cbe604d4fcab.png)

</center>

`active close`端的系统中才会出现`time_wait`的状态。拿请求`https://google.com`来举例，客户端在创建连接时，其实并不关心连接的端口号，它是系统随机创建的。`google`服务存在一个`443`端口,一直处于`listen`状态。当客户端断开连接时，客户端系统其实就会出现`time_wait`。当服务端主动断开连接时，客户端会出现`close_wait`状态。

## `2MLS`

`time_wait`也被称为`2MLS wait`。全名`maximum segment lifetime`, 表示一个数据块在被丢弃之前，在网络中能存在的最长时间。`TCP`的数据包是作为`IP`数据传输的，而`IP`数据包是否有效受限于设置的`TTL`，所以该`MSL`存在上限。

1. 在`2MLS`内，该连接不会处理那些迟到的请求，占用的端口号也无法被系统的其他程序使用。
2. 在`TCP`连接中,`ACK`消息本身是不安全，因为`peer`不需要对`ACK`回复`ACK`。所以，`2MLS`保证了当被动关闭的一端没有收到`ACK`时，重新发送一次`FIN`报文。

可以通过`tcp_tw_reuse`来重用`time_wait`状态的端口号。

## `shell`查询`time_wait`连接

查看连接的状态，主要有两个命令`netstat`和`ss`。`netstat`有的`ss`都有，而且运行非常快。

```
netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) {print a, S[a]} }'
```
匹配`tcp`连接，声明了数组`S`，`$NF`用于获取最后一列的数据，也就是`tcp status`，最后通过`for`语句输出。

```
ss -o state time-wait '( sport = :http )'    #timewait是中划线 
```
通过`ss`还可以方便的过滤出源端口是80的，状态是`time_wait`的连接

## 总结

在开发中，可以适当考虑使用长连接。而且，现在基本所有的库都自带连接池功能。
